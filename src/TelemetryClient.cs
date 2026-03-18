using System.Net.Http;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using MegaCrit.Sts2.Core.Logging;

namespace HeyboxCardStatsOverlay;

internal sealed class TelemetryClient
{
    private const string StateFileName = "telemetry_state.json";

    private readonly string _modDirectory;

    private readonly ModConfig _config;

    private readonly string _statePath;

    private readonly string _legacyStatePath;

    private readonly object _stateSync = new();

    private int _heartbeatQueued;

    private string? _lastLogKey;

    public TelemetryClient(string modDirectory, ModConfig config)
    {
        _modDirectory = modDirectory ?? string.Empty;
        _config = config;
        _legacyStatePath = Path.Combine(_modDirectory, StateFileName);
        _statePath = ResolveStatePath(_legacyStatePath);
    }

    public void QueueDailyHeartbeat()
    {
        if (!_config.TelemetryEnabled
            || _config.TelemetryEndpoints.Length == 0
            || string.IsNullOrWhiteSpace(_modDirectory))
        {
            return;
        }

        if (Interlocked.Exchange(ref _heartbeatQueued, 1) == 1)
        {
            return;
        }

        _ = Task.Run(SendDailyHeartbeatAsync);
    }

    private async Task SendDailyHeartbeatAsync()
    {
        try
        {
            TelemetryState state = LoadOrCreateState();
            string today = DateTime.UtcNow.ToString("yyyy-MM-dd");
            if (string.Equals(state.LastHeartbeatDay, today, StringComparison.Ordinal))
            {
                return;
            }

            HeartbeatRequest payload = new()
            {
                ClientId = state.ClientId,
                ModId = ModEntry.ModId,
                ModVersion = ReadLocalVersion(),
                Game = "Slay the Spire 2",
                Platform = GetPlatformTag(),
                PlatformVersion = RuntimeInformation.OSDescription.Trim(),
                SentAt = DateTimeOffset.UtcNow.ToString("o")
            };

            string payloadJson = JsonSerializer.Serialize(payload, JsonOptions);
            foreach (string endpointText in _config.TelemetryEndpoints)
            {
                string attemptedAt = DateTimeOffset.UtcNow.ToString("o");
                if (!Uri.TryCreate(endpointText, UriKind.Absolute, out Uri? endpoint))
                {
                    UpdateState(state, attemptedAt, endpointText, null, "Invalid telemetry endpoint.");
                    MaybeLog("bad-endpoint", $"HeyboxCardStatsOverlay: telemetry endpoint is invalid: '{endpointText}'.");
                    continue;
                }

                try
                {
                    using CancellationTokenSource timeout = new(TimeSpan.FromSeconds(_config.TelemetryTimeoutSeconds));
                    using HttpRequestMessage request = new(HttpMethod.Post, endpoint);
                    request.Headers.UserAgent.ParseAdd($"HeyboxCardStatsOverlay/{payload.ModVersion}");
                    request.Content = new StringContent(payloadJson, Utf8NoBom, "application/json");

                    using HttpResponseMessage response = await SharedHttpClient.SendAsync(
                        request,
                        HttpCompletionOption.ResponseHeadersRead,
                        timeout.Token).ConfigureAwait(false);
                    response.EnsureSuccessStatusCode();

                    string succeededAt = DateTimeOffset.UtcNow.ToString("o");
                    UpdateState(state, succeededAt, endpointText, today, string.Empty);
                    _lastLogKey = null;
                    return;
                }
                catch (Exception ex)
                {
                    string error = DescribeTelemetryFailure(ex);
                    UpdateState(state, attemptedAt, endpointText, null, error);
                    MaybeLog(
                        $"heartbeat:{endpointText}:{error}",
                        $"HeyboxCardStatsOverlay: telemetry heartbeat via '{endpointText}' failed: {error}");
                }
            }
        }
        catch (Exception ex)
        {
            MaybeLog($"heartbeat:{ex.Message}", $"HeyboxCardStatsOverlay: telemetry heartbeat failed: {ex.Message}");
        }
    }

    private TelemetryState LoadOrCreateState()
    {
        lock (_stateSync)
        {
            TelemetryState? existing = TryReadState(_statePath);
            if (existing != null)
            {
                DeleteLegacyStateFileIfNeeded();
                return existing;
            }

            TelemetryState? migrated = TryMigrateLegacyState();
            if (migrated != null)
            {
                return migrated;
            }

            TelemetryState created = TelemetryState.CreateNew();
            WriteState(created);
            Log.Info("HeyboxCardStatsOverlay: generated a new anonymous telemetry installation id.", 2);
            return created;
        }
    }

    private TelemetryState? TryReadState(string path)
    {
        try
        {
            if (!File.Exists(path))
            {
                return null;
            }

            string json = File.ReadAllText(path);
            TelemetryState? parsed = JsonSerializer.Deserialize<TelemetryState>(json, JsonOptions);
            if (parsed != null && parsed.Normalize())
            {
                return parsed;
            }
        }
        catch
        {
        }

        return null;
    }

    private TelemetryState? TryMigrateLegacyState()
    {
        if (string.Equals(_statePath, _legacyStatePath, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        TelemetryState? legacy = TryReadState(_legacyStatePath);
        if (legacy == null)
        {
            return null;
        }

        WriteState(legacy);
        DeleteLegacyStateFileIfNeeded();
        Log.Info($"HeyboxCardStatsOverlay: migrated anonymous telemetry state to '{_statePath}'.", 2);
        return legacy;
    }

    private void WriteState(TelemetryState state)
    {
        string? directory = Path.GetDirectoryName(_statePath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        string json = JsonSerializer.Serialize(state, JsonOptionsIndented);
        File.WriteAllText(_statePath, json, Utf8NoBom);
    }

    private void DeleteLegacyStateFileIfNeeded()
    {
        if (string.Equals(_statePath, _legacyStatePath, StringComparison.OrdinalIgnoreCase)
            || !File.Exists(_legacyStatePath))
        {
            return;
        }

        try
        {
            File.Delete(_legacyStatePath);
        }
        catch
        {
        }
    }

    private string ReadLocalVersion()
    {
        try
        {
            string? manifestPath = ModLayout.FindManifestPath(_modDirectory);
            if (!string.IsNullOrWhiteSpace(manifestPath) && File.Exists(manifestPath))
            {
                string json = File.ReadAllText(manifestPath);
                LocalManifest? manifest = JsonSerializer.Deserialize<LocalManifest>(json, JsonOptions);
                if (!string.IsNullOrWhiteSpace(manifest?.Version))
                {
                    return manifest.Version.Trim();
                }
            }
        }
        catch
        {
        }

        return "0.0.0";
    }

    private void UpdateState(TelemetryState state, string attemptedAt, string endpoint, string? heartbeatDay, string error)
    {
        lock (_stateSync)
        {
            state.LastAttemptAt = attemptedAt;
            state.LastEndpoint = endpoint;
            state.LastError = error;
            if (!string.IsNullOrWhiteSpace(heartbeatDay))
            {
                state.LastHeartbeatDay = heartbeatDay;
                state.LastSuccessAt = attemptedAt;
            }

            WriteState(state);
        }
    }

    private string DescribeTelemetryFailure(Exception ex)
    {
        if (ex is OperationCanceledException)
        {
            return $"Timed out after {_config.TelemetryTimeoutSeconds} seconds.";
        }

        if (ex is HttpRequestException httpRequestException
            && httpRequestException.StatusCode is not null)
        {
            return $"HTTP {(int)httpRequestException.StatusCode} {httpRequestException.StatusCode}.";
        }

        return ex.Message;
    }

    private void MaybeLog(string key, string message)
    {
        if (_lastLogKey == key)
        {
            return;
        }

        _lastLogKey = key;
        Log.Warn(message, 2);
    }

    private static string GetPlatformTag()
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            return "windows";
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            return "macos";
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
        {
            return "linux";
        }

        return "unknown";
    }

    private static string ResolveStatePath(string legacyStatePath)
    {
        string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        if (string.IsNullOrWhiteSpace(localAppData))
        {
            return legacyStatePath;
        }

        return Path.Combine(localAppData, ModEntry.ModId, StateFileName);
    }

    private static readonly HttpClient SharedHttpClient = new();

    private static readonly UTF8Encoding Utf8NoBom = new(encoderShouldEmitUTF8Identifier: false);

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true
    };

    private static readonly JsonSerializerOptions JsonOptionsIndented = new()
    {
        WriteIndented = true
    };

    private sealed class LocalManifest
    {
        [JsonPropertyName("version")]
        public string? Version { get; set; }
    }

    private sealed class HeartbeatRequest
    {
        [JsonPropertyName("client_id")]
        public string ClientId { get; set; } = string.Empty;

        [JsonPropertyName("mod_id")]
        public string ModId { get; set; } = string.Empty;

        [JsonPropertyName("mod_version")]
        public string ModVersion { get; set; } = "0.0.0";

        [JsonPropertyName("game")]
        public string Game { get; set; } = string.Empty;

        [JsonPropertyName("platform")]
        public string Platform { get; set; } = string.Empty;

        [JsonPropertyName("platform_version")]
        public string PlatformVersion { get; set; } = string.Empty;

        [JsonPropertyName("sent_at")]
        public string SentAt { get; set; } = string.Empty;
    }

    private sealed class TelemetryState
    {
        [JsonPropertyName("client_id")]
        public string ClientId { get; set; } = string.Empty;

        [JsonPropertyName("created_at")]
        public string CreatedAt { get; set; } = string.Empty;

        [JsonPropertyName("last_heartbeat_day")]
        public string LastHeartbeatDay { get; set; } = string.Empty;

        [JsonPropertyName("last_attempt_at")]
        public string LastAttemptAt { get; set; } = string.Empty;

        [JsonPropertyName("last_endpoint")]
        public string LastEndpoint { get; set; } = string.Empty;

        [JsonPropertyName("last_error")]
        public string LastError { get; set; } = string.Empty;

        [JsonPropertyName("last_success_at")]
        public string LastSuccessAt { get; set; } = string.Empty;

        public static TelemetryState CreateNew()
        {
            return new TelemetryState
            {
                ClientId = Guid.NewGuid().ToString("N"),
                CreatedAt = DateTimeOffset.UtcNow.ToString("o")
            };
        }

        public bool Normalize()
        {
            ClientId = (ClientId ?? string.Empty).Trim();
            CreatedAt = (CreatedAt ?? string.Empty).Trim();
            LastHeartbeatDay = (LastHeartbeatDay ?? string.Empty).Trim();
            LastAttemptAt = (LastAttemptAt ?? string.Empty).Trim();
            LastEndpoint = (LastEndpoint ?? string.Empty).Trim();
            LastError = (LastError ?? string.Empty).Trim();
            LastSuccessAt = (LastSuccessAt ?? string.Empty).Trim();
            if (ClientId.Length < 16
                || ClientId.Length > 80
                || ClientId.Any(static ch => !(char.IsLetterOrDigit(ch) || ch == '_' || ch == '-')))
            {
                return false;
            }

            if (CreatedAt.Length == 0)
            {
                CreatedAt = DateTimeOffset.UtcNow.ToString("o");
            }

            return true;
        }
    }
}
