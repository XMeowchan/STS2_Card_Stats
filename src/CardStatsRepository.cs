using System.Globalization;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using GodotFileAccess = Godot.FileAccess;
using MegaCrit.Sts2.Core.Logging;
using MegaCrit.Sts2.Core.Models;

namespace HeyboxCardStatsOverlay;

internal sealed class CardStatsRepository
{
    private readonly string _modDirectory;

    private readonly ModConfig _config;

    private readonly object _sync = new();

    private CardStatsSnapshot? _snapshot;

    private string? _lastLoadErrorKey;

    private DateTime _nextRemoteRefreshUtc = DateTime.MinValue;

    private bool _remoteRefreshInProgress;

    public CardStatsRepository(string modDirectory, ModConfig config)
    {
        _modDirectory = modDirectory;
        _config = config;
    }

    public CardStatsLookupResult Resolve(string requestedId, CardModel? cardModel)
    {
        CardStatsSnapshot? snapshot = GetSnapshot();
        if (snapshot == null)
        {
            return new CardStatsLookupResult(null, null, NormalizeId(requestedId), null);
        }

        List<string> candidates = new();
        AddCandidate(candidates, requestedId);
        AddCandidate(candidates, cardModel?.Id?.ToString());
        AddCandidate(candidates, cardModel?.CanonicalInstance?.Id?.ToString());
        AddCandidate(candidates, cardModel?.GetType().Name);
        AddCandidate(candidates, cardModel?.CanonicalInstance?.GetType().Name);
        AddCandidate(candidates, ToPascalCandidate(requestedId));
        AddCandidate(candidates, ToPascalCandidate(cardModel?.Id?.ToString()));
        AddCandidate(candidates, ToPascalCandidate(cardModel?.CanonicalInstance?.Id?.ToString()));

        foreach (string candidate in candidates)
        {
            if (snapshot.ById.TryGetValue(candidate, out CardStatsCard? card))
            {
                snapshot.RelativeStatsById.TryGetValue(NormalizeId(card.Id), out CategoryRelativeStats? relativeStats);
                return new CardStatsLookupResult(snapshot, card, candidate, relativeStats);
            }
        }

        return new CardStatsLookupResult(snapshot, null, NormalizeId(requestedId), null);
    }

    private static void AddCandidate(List<string> candidates, string? value)
    {
        string normalized = NormalizeId(value);
        if (normalized.Length > 0 && !candidates.Contains(normalized, StringComparer.OrdinalIgnoreCase))
        {
            candidates.Add(normalized);
        }
    }

    private CardStatsSnapshot? GetSnapshot()
    {
        lock (_sync)
        {
            QueueRemoteRefreshIfNeeded();

            (string path, string cacheKind) = ResolveDataPath();
            if (string.IsNullOrEmpty(path))
            {
                MaybeLog("missing", $"HeyboxCardStatsOverlay: no '{_config.DataFile}', legacy json caches, bundled fallback, or sample cache found.");
                _snapshot = null;
                return null;
            }

            bool isBundledPath = IsBundledPath(path);
            DateTime writeTimeUtc;
            try
            {
                writeTimeUtc = isBundledPath ? DateTime.UnixEpoch : File.GetLastWriteTimeUtc(path);
            }
            catch (Exception ex)
            {
                MaybeLog($"file-error:{path}", $"HeyboxCardStatsOverlay: failed to access data file '{path}': {ex.Message}");
                _snapshot = null;
                return null;
            }

            if (_snapshot != null &&
                string.Equals(_snapshot.Path, path, StringComparison.OrdinalIgnoreCase) &&
                _snapshot.FileWriteTimeUtc == writeTimeUtc)
            {
                return _snapshot;
            }

            try
            {
                string json = ReadDataText(path);
                CardStatsFile? file = JsonSerializer.Deserialize<CardStatsFile>(json, JsonOptions);
                Dictionary<string, CardStatsCard> byId = new(StringComparer.OrdinalIgnoreCase);
                foreach (CardStatsCard card in file?.Cards ?? Enumerable.Empty<CardStatsCard>())
                {
                    IndexCard(byId, card, card.Id);
                    if (card.AltIds != null)
                    {
                        foreach (string altId in card.AltIds)
                        {
                            IndexCard(byId, card, altId);
                        }
                    }

                    IndexCard(byId, card, card.NameEn);
                    IndexCard(byId, card, card.NameCn);
                }

                _snapshot = new CardStatsSnapshot
                {
                    Source = file?.Source?.Trim() ?? "local",
                    Path = path,
                    CacheKind = cacheKind,
                    FileWriteTimeUtc = writeTimeUtc,
                    UpdatedAt = TryParseDate(file?.UpdatedAt),
                    ById = byId,
                    RelativeStatsById = BuildRelativeStats(file?.Cards ?? Enumerable.Empty<CardStatsCard>())
                };
                _lastLoadErrorKey = null;
                Log.Info($"HeyboxCardStatsOverlay: loaded {byId.Count} card ids from '{path}' ({cacheKind}).", 2);
                return _snapshot;
            }
            catch (Exception ex)
            {
                MaybeLog($"parse-error:{path}", $"HeyboxCardStatsOverlay: failed to parse '{path}': {ex.Message}");
                _snapshot = null;
                return null;
            }
        }
    }

    private void QueueRemoteRefreshIfNeeded()
    {
        if (!_config.RemoteDataEnabled || string.IsNullOrWhiteSpace(_config.RemoteDataUrl))
        {
            return;
        }

        DateTime now = DateTime.UtcNow;
        if (_remoteRefreshInProgress || now < _nextRemoteRefreshUtc)
        {
            return;
        }

        _remoteRefreshInProgress = true;
        _nextRemoteRefreshUtc = now.AddMinutes(_config.RemoteRefreshMinutes);
            string cachePath = ModLayout.GetDataPath(_modDirectory, _config.DataFile);
            _ = Task.Run(() => RefreshRemoteDataAsync(cachePath));
    }

    private async Task RefreshRemoteDataAsync(string cachePath)
    {
        try
        {
            using CancellationTokenSource timeout = new(TimeSpan.FromSeconds(_config.RemoteTimeoutSeconds));
            using HttpRequestMessage request = new(HttpMethod.Get, _config.RemoteDataUrl);
            request.Headers.UserAgent.ParseAdd("HeyboxCardStatsOverlay/0.2.3");

            using HttpResponseMessage response = await SharedHttpClient.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                timeout.Token).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();

            string json = await response.Content.ReadAsStringAsync(timeout.Token).ConfigureAwait(false);
            CardStatsFile? file = JsonSerializer.Deserialize<CardStatsFile>(json, JsonOptions);
            if (file?.Cards == null || file.Cards.Count == 0)
            {
                throw new InvalidDataException("Remote data payload does not contain any cards.");
            }

            await WriteTextAtomicAsync(cachePath, json, timeout.Token).ConfigureAwait(false);

            lock (_sync)
            {
                _snapshot = null;
                _lastLoadErrorKey = null;
                _remoteRefreshInProgress = false;
                _nextRemoteRefreshUtc = DateTime.UtcNow.AddMinutes(_config.RemoteRefreshMinutes);
            }

            Log.Info($"HeyboxCardStatsOverlay: refreshed remote data from '{_config.RemoteDataUrl}' to '{cachePath}'.", 2);
        }
        catch (Exception ex)
        {
            lock (_sync)
            {
                _remoteRefreshInProgress = false;
                _nextRemoteRefreshUtc = DateTime.UtcNow.AddMinutes(Math.Min(15, _config.RemoteRefreshMinutes));
                MaybeLog($"remote-error:{ex.Message}", $"HeyboxCardStatsOverlay: failed to refresh remote data '{_config.RemoteDataUrl}': {ex.Message}");
            }
        }
    }

    private static void IndexCard(Dictionary<string, CardStatsCard> byId, CardStatsCard card, string? rawId)
    {
        string normalized = NormalizeId(rawId);
        if (normalized.Length == 0)
        {
            return;
        }

        byId[normalized] = card;
    }

    private void MaybeLog(string key, string message)
    {
        if (_lastLoadErrorKey == key)
        {
            return;
        }

        _lastLoadErrorKey = key;
        Log.Warn(message, 2);
    }

    private (string path, string cacheKind) ResolveDataPath()
    {
        string livePath = ModLayout.GetDataPath(_modDirectory, _config.DataFile);
        if (File.Exists(livePath))
        {
            return (livePath, "live");
        }

        string legacyLivePath = Path.Combine(_modDirectory, ModLayout.LegacyDataFileName);
        if (!string.Equals(livePath, legacyLivePath, StringComparison.OrdinalIgnoreCase) && File.Exists(legacyLivePath))
        {
            return (legacyLivePath, "live-legacy");
        }

        string fallbackPath = Path.Combine(_modDirectory, ModLayout.LegacyFallbackDataFileName);
        if (File.Exists(fallbackPath))
        {
            return (fallbackPath, "fallback-legacy");
        }

        string bundledFallbackPath = $"res://{ModEntry.ModId}/data/cards.fallback.json";
        if (GodotFileAccess.FileExists(bundledFallbackPath))
        {
            return (bundledFallbackPath, "fallback");
        }

        string samplePath = Path.Combine(_modDirectory, ModLayout.LegacySampleDataFileName);
        if (File.Exists(samplePath))
        {
            return (samplePath, "sample-legacy");
        }

        return (string.Empty, string.Empty);
    }

    private static string ReadDataText(string path)
    {
        if (!IsBundledPath(path))
        {
            return File.ReadAllText(path);
        }

        using var file = GodotFileAccess.Open(path, GodotFileAccess.ModeFlags.Read);
        if (file == null)
        {
            throw new IOException($"Failed to open bundled data file '{path}'.");
        }

        return file.GetAsText();
    }

    private static bool IsBundledPath(string path)
    {
        return path.StartsWith("res://", StringComparison.OrdinalIgnoreCase);
    }

    private static async Task WriteTextAtomicAsync(string path, string content, CancellationToken cancellationToken)
    {
        string? directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        string tempPath = $"{path}.tmp";
        try
        {
            await File.WriteAllTextAsync(tempPath, content, Utf8NoBom, cancellationToken).ConfigureAwait(false);
            File.Move(tempPath, path, overwrite: true);
        }
        finally
        {
            if (File.Exists(tempPath))
            {
                File.Delete(tempPath);
            }
        }
    }

    private static Dictionary<string, CategoryRelativeStats> BuildRelativeStats(IEnumerable<CardStatsCard> cards)
    {
        Dictionary<string, CategoryRelativeStats> result = new(StringComparer.OrdinalIgnoreCase);
        List<CardStatsCard> uniqueCards = cards
            .Where(static card => !string.IsNullOrWhiteSpace(card.Id))
            .GroupBy(card => NormalizeId(card.Id), StringComparer.OrdinalIgnoreCase)
            .Select(static group => group.First())
            .ToList();

        foreach (IGrouping<string, CardStatsCard> categoryGroup in uniqueCards.GroupBy(card => (card.Category ?? string.Empty).Trim(), StringComparer.OrdinalIgnoreCase))
        {
            ApplyMetric(categoryGroup, result, static card => card.Stats?.WinRate, static (stats, percent, rank, count) =>
            {
                stats.WinRatePercent = percent;
                stats.WinRateRank = rank;
                stats.WinRateCount = count;
            });

            ApplyMetric(categoryGroup, result, static card => card.Stats?.PickRate, static (stats, percent, rank, count) =>
            {
                stats.PickRatePercent = percent;
                stats.PickRateRank = rank;
                stats.PickRateCount = count;
            });
        }

        return result;
    }

    private static void ApplyMetric(
        IEnumerable<CardStatsCard> cards,
        Dictionary<string, CategoryRelativeStats> result,
        Func<CardStatsCard, double?> selector,
        Action<CategoryRelativeStats, double?, int?, int?> apply)
    {
        List<CardStatsCard> rankedCards = cards
            .Where(card => selector(card).HasValue)
            .OrderByDescending(card => selector(card) ?? double.MinValue)
            .ThenBy(card => NormalizeId(card.Id), StringComparer.OrdinalIgnoreCase)
            .ToList();

        int count = rankedCards.Count;
        if (count == 0)
        {
            return;
        }

        for (int index = 0; index < rankedCards.Count; index += 1)
        {
            CardStatsCard card = rankedCards[index];
            string key = NormalizeId(card.Id);
            if (!result.TryGetValue(key, out CategoryRelativeStats? stats))
            {
                stats = new CategoryRelativeStats();
                result[key] = stats;
            }

            int rank = index + 1;
            double percent = count <= 1 ? 100.0 : (count - rank) * 100.0 / (count - 1);
            apply(stats, percent, rank, count);
        }
    }

    private static DateTimeOffset? TryParseDate(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out DateTimeOffset parsed))
        {
            return parsed;
        }

        return null;
    }

    private static string NormalizeId(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        string normalized = value.Trim();
        while (normalized.EndsWith("+", StringComparison.Ordinal))
        {
            normalized = normalized[..^1];
        }

        return normalized;
    }

    private static string ToPascalCandidate(string? value)
    {
        string normalized = NormalizeId(value);
        if (normalized.Length == 0)
        {
            return string.Empty;
        }

        int lastDot = normalized.LastIndexOf('.');
        if (lastDot >= 0 && lastDot + 1 < normalized.Length)
        {
            normalized = normalized[(lastDot + 1)..];
        }

        string[] parts = normalized.Split(new[] { '_', ' ' }, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0)
        {
            return normalized;
        }

        return string.Concat(parts.Select(static part =>
        {
            string lower = part.ToLowerInvariant();
            return char.ToUpperInvariant(lower[0]) + lower[1..];
        }));
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
        NumberHandling = JsonNumberHandling.AllowReadingFromString
    };

    private static readonly HttpClient SharedHttpClient = new();

    private static readonly UTF8Encoding Utf8NoBom = new(encoderShouldEmitUTF8Identifier: false);
}
