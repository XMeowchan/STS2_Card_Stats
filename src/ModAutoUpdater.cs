using System.Diagnostics;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using MegaCrit.Sts2.Core.Logging;

namespace HeyboxCardStatsOverlay;

internal sealed class ModAutoUpdater
{
    private const string RuntimeDirectoryName = "_update_runtime";

    private const string ApplyScriptName = "apply-mod-update.ps1";

    private readonly string _modDirectory;

    private readonly ModConfig _config;

    private readonly string _runtimeDirectory;

    private int _checkQueued;

    public ModAutoUpdater(string modDirectory, ModConfig config)
    {
        _modDirectory = modDirectory ?? string.Empty;
        _config = config;
        _runtimeDirectory = ResolveRuntimeDirectory(_modDirectory);
        CleanupLegacyRuntimeDirectory();
    }

    public void QueueCheck()
    {
        if (!_config.ModUpdateEnabled
            || string.IsNullOrWhiteSpace(_config.ModUpdateGithubRepo)
            || string.IsNullOrWhiteSpace(_modDirectory))
        {
            return;
        }

        if (Interlocked.Exchange(ref _checkQueued, 1) == 1)
        {
            return;
        }

        _ = Task.Run(CheckForUpdateAsync);
    }

    private async Task CheckForUpdateAsync()
    {
        try
        {
            LocalModManifest? localManifest = ReadLocalManifest();
            if (!TryParseVersion(localManifest?.Version, out Version localVersion))
            {
                localVersion = new Version(0, 0, 0);
            }

            GitHubRelease? release = await FetchLatestReleaseAsync().ConfigureAwait(false);
            if (release == null)
            {
                return;
            }

            string remoteVersionText = NormalizeVersionString(release.TagName);
            if (remoteVersionText.Length == 0)
            {
                remoteVersionText = NormalizeVersionString(release.Name);
            }
            if (!TryParseVersion(remoteVersionText, out Version remoteVersion))
            {
                Log.Warn($"HeyboxCardStatsOverlay: could not parse GitHub release version '{release.TagName}'.", 2);
                return;
            }

            if (remoteVersion <= localVersion)
            {
                return;
            }

            GitHubReleaseAsset? asset = PickPortableAsset(release.Assets);
            if (asset == null)
            {
                Log.Warn($"HeyboxCardStatsOverlay: release '{release.TagName}' has no portable zip asset to auto-update from.", 2);
                return;
            }

            Directory.CreateDirectory(_runtimeDirectory);
            string downloadsDirectory = Path.Combine(_runtimeDirectory, "downloads");
            string stagingDirectory = Path.Combine(_runtimeDirectory, "staging", remoteVersion.ToString());
            Directory.CreateDirectory(downloadsDirectory);
            if (Directory.Exists(stagingDirectory))
            {
                Directory.Delete(stagingDirectory, recursive: true);
            }

            string zipPath = Path.Combine(downloadsDirectory, asset.Name ?? $"update-{remoteVersion}.zip");
            await DownloadAssetAsync(asset.BrowserDownloadUrl ?? string.Empty, zipPath).ConfigureAwait(false);
            ZipFile.ExtractToDirectory(zipPath, stagingDirectory);

            string stagedModDirectory = ResolveStagedModDirectory(stagingDirectory);
            string applyScriptPath = EnsureApplyScript();
            LaunchApplyProcess(applyScriptPath, stagedModDirectory, remoteVersionText);
            Log.Info($"HeyboxCardStatsOverlay: downloaded update {remoteVersionText}; it will be applied after Slay the Spire 2 exits.", 2);
        }
        catch (Exception ex)
        {
            Log.Warn($"HeyboxCardStatsOverlay: automatic mod update check failed: {ex.Message}", 2);
        }
    }

    private LocalModManifest? ReadLocalManifest()
    {
        string manifestPath = Path.Combine(_modDirectory, "mod_manifest.json");
        if (!File.Exists(manifestPath))
        {
            return null;
        }

        string json = File.ReadAllText(manifestPath);
        return JsonSerializer.Deserialize<LocalModManifest>(json, JsonOptions);
    }

    private async Task<GitHubRelease?> FetchLatestReleaseAsync()
    {
        string requestUrl = $"https://api.github.com/repos/{_config.ModUpdateGithubRepo}/releases/latest";
        using CancellationTokenSource timeout = new(TimeSpan.FromSeconds(_config.ModUpdateTimeoutSeconds));
        using HttpRequestMessage request = new(HttpMethod.Get, requestUrl);
        request.Headers.UserAgent.ParseAdd("HeyboxCardStatsOverlay-Updater");
        request.Headers.Accept.ParseAdd("application/vnd.github+json");

        using HttpResponseMessage response = await SharedHttpClient.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead,
            timeout.Token).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();

        string json = await response.Content.ReadAsStringAsync(timeout.Token).ConfigureAwait(false);
        return JsonSerializer.Deserialize<GitHubRelease>(json, JsonOptions);
    }

    private async Task DownloadAssetAsync(string url, string destinationPath)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            throw new InvalidDataException("GitHub release asset is missing a download URL.");
        }

        using CancellationTokenSource timeout = new(TimeSpan.FromSeconds(_config.ModUpdateTimeoutSeconds));
        using HttpRequestMessage request = new(HttpMethod.Get, url);
        request.Headers.UserAgent.ParseAdd("HeyboxCardStatsOverlay-Updater");
        using HttpResponseMessage response = await SharedHttpClient.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead,
            timeout.Token).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();

        await using Stream source = await response.Content.ReadAsStreamAsync(timeout.Token).ConfigureAwait(false);
        await using FileStream destination = new(destinationPath, FileMode.Create, FileAccess.Write, FileShare.None);
        await source.CopyToAsync(destination, timeout.Token).ConfigureAwait(false);
    }

    private static GitHubReleaseAsset? PickPortableAsset(IReadOnlyList<GitHubReleaseAsset>? assets)
    {
        return assets?
            .Where(static asset => !string.IsNullOrWhiteSpace(asset.Name)
                && asset.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
            .OrderByDescending(GetAssetScore)
            .FirstOrDefault();
    }

    private static int GetAssetScore(GitHubReleaseAsset asset)
    {
        int score = 0;
        string name = asset.Name ?? string.Empty;
        if (name.Contains("portable", StringComparison.OrdinalIgnoreCase))
        {
            score += 100;
        }

        if (name.Contains(ModEntry.ModId, StringComparison.OrdinalIgnoreCase))
        {
            score += 50;
        }

        if (string.Equals(asset.ContentType, "application/zip", StringComparison.OrdinalIgnoreCase))
        {
            score += 20;
        }

        return score;
    }

    private static string ResolveStagedModDirectory(string stagingDirectory)
    {
        string[] manifestPaths = Directory.GetFiles(stagingDirectory, "mod_manifest.json", SearchOption.AllDirectories);
        foreach (string manifestPath in manifestPaths)
        {
            string candidateDirectory = Path.GetDirectoryName(manifestPath) ?? string.Empty;
            if (candidateDirectory.Length == 0)
            {
                continue;
            }

            string dllPath = Path.Combine(candidateDirectory, $"{ModEntry.ModId}.dll");
            string pckPath = Path.Combine(candidateDirectory, $"{ModEntry.ModId}.pck");
            if (File.Exists(dllPath) && File.Exists(pckPath))
            {
                return candidateDirectory;
            }
        }

        throw new DirectoryNotFoundException("Downloaded update package does not contain a valid mod payload.");
    }

    private static string ResolveRuntimeDirectory(string modDirectory)
    {
        string baseDirectory = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        if (string.IsNullOrWhiteSpace(baseDirectory))
        {
            baseDirectory = Path.GetTempPath();
        }

        return Path.Combine(baseDirectory, ModEntry.ModId, RuntimeDirectoryName, CreateRuntimeInstanceId(modDirectory));
    }

    private static string CreateRuntimeInstanceId(string modDirectory)
    {
        string normalizedPath = NormalizeDirectoryPath(modDirectory);
        if (normalizedPath.Length == 0)
        {
            return "default";
        }

        byte[] hash = SHA256.HashData(Utf8NoBom.GetBytes(normalizedPath));
        return Convert.ToHexString(hash.AsSpan(0, 8)).ToLowerInvariant();
    }

    private static string NormalizeDirectoryPath(string directoryPath)
    {
        if (string.IsNullOrWhiteSpace(directoryPath))
        {
            return string.Empty;
        }

        try
        {
            return Path.GetFullPath(directoryPath)
                .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        }
        catch
        {
            return directoryPath.Trim()
                .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        }
    }

    private void CleanupLegacyRuntimeDirectory()
    {
        if (string.IsNullOrWhiteSpace(_modDirectory))
        {
            return;
        }

        string legacyRuntimeDirectory = Path.Combine(_modDirectory, RuntimeDirectoryName);
        if (string.Equals(
                NormalizeDirectoryPath(legacyRuntimeDirectory),
                NormalizeDirectoryPath(_runtimeDirectory),
                StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        TryDeleteDirectory(legacyRuntimeDirectory, "legacy in-mod update runtime");
    }

    private static void TryDeleteDirectory(string directoryPath, string label)
    {
        if (!Directory.Exists(directoryPath))
        {
            return;
        }

        try
        {
            Directory.Delete(directoryPath, recursive: true);
            Log.Info($"HeyboxCardStatsOverlay: removed {label} at '{directoryPath}'.", 2);
        }
        catch (Exception ex)
        {
            Log.Warn($"HeyboxCardStatsOverlay: failed to remove {label} at '{directoryPath}': {ex.Message}", 2);
        }
    }

    private string EnsureApplyScript()
    {
        Directory.CreateDirectory(_runtimeDirectory);
        string scriptPath = Path.Combine(_runtimeDirectory, ApplyScriptName);
        File.WriteAllText(scriptPath, ApplyScriptContents, Utf8NoBom);
        return scriptPath;
    }

    private void LaunchApplyProcess(string scriptPath, string stagedModDirectory, string remoteVersionText)
    {
        ProcessStartInfo startInfo = new()
        {
            FileName = "powershell.exe",
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden,
            WorkingDirectory = _modDirectory
        };
        startInfo.ArgumentList.Add("-NoProfile");
        startInfo.ArgumentList.Add("-ExecutionPolicy");
        startInfo.ArgumentList.Add("Bypass");
        startInfo.ArgumentList.Add("-File");
        startInfo.ArgumentList.Add(scriptPath);
        startInfo.ArgumentList.Add("-SourceDir");
        startInfo.ArgumentList.Add(stagedModDirectory);
        startInfo.ArgumentList.Add("-TargetDir");
        startInfo.ArgumentList.Add(_modDirectory);
        startInfo.ArgumentList.Add("-RuntimeDir");
        startInfo.ArgumentList.Add(_runtimeDirectory);
        startInfo.ArgumentList.Add("-ParentPid");
        startInfo.ArgumentList.Add(Environment.ProcessId.ToString());
        startInfo.ArgumentList.Add("-ExpectedVersion");
        startInfo.ArgumentList.Add(remoteVersionText);

        Process? process = Process.Start(startInfo);
        if (process == null)
        {
            throw new InvalidOperationException("Failed to start the external updater process.");
        }
    }

    private static bool TryParseVersion(string? value, out Version version)
    {
        version = new Version(0, 0, 0);
        string normalized = NormalizeVersionString(value);
        if (normalized.Length == 0)
        {
            return false;
        }

        if (!Version.TryParse(normalized, out Version? parsed) || parsed == null)
        {
            return false;
        }

        version = parsed;
        return true;
    }

    private static string NormalizeVersionString(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        string trimmed = value.Trim();
        if (trimmed.StartsWith("v", StringComparison.OrdinalIgnoreCase))
        {
            trimmed = trimmed[1..];
        }

        int start = -1;
        int end = -1;
        for (int index = 0; index < trimmed.Length; index += 1)
        {
            char ch = trimmed[index];
            if (char.IsDigit(ch))
            {
                if (start < 0)
                {
                    start = index;
                }

                end = index + 1;
                continue;
            }

            if (ch == '.' && start >= 0)
            {
                end = index + 1;
                continue;
            }

            if (start >= 0)
            {
                break;
            }
        }

        if (start < 0 || end <= start)
        {
            return string.Empty;
        }

        return trimmed[start..end].Trim('.');
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true
    };

    private static readonly HttpClient SharedHttpClient = new();

    private static readonly UTF8Encoding Utf8NoBom = new(encoderShouldEmitUTF8Identifier: false);

    private const string ApplyScriptContents = """
param(
    [Parameter(Mandatory)]
    [string]$SourceDir,
    [Parameter(Mandatory)]
    [string]$TargetDir,
    [Parameter(Mandatory)]
    [string]$RuntimeDir,
    [int]$ParentPid = 0,
    [string]$ExpectedVersion = ""
)

$ErrorActionPreference = "Stop"

function Wait-ForParentExit {
    param(
        [int]$PidToWait
    )

    if ($PidToWait -le 0) {
        return
    }

    while ($true) {
        $process = Get-Process -Id $PidToWait -ErrorAction SilentlyContinue
        if (-not $process) {
            break
        }

        Start-Sleep -Milliseconds 750
    }

    Start-Sleep -Seconds 1
}

function Copy-UpdateFiles {
    param(
        [Parameter(Mandatory)]
        [string]$FromDir,
        [Parameter(Mandatory)]
        [string]$ToDir
    )

    $preserveIfPresent = @(
        "config.json"
    )

    New-Item -ItemType Directory -Force -Path $ToDir | Out-Null
    foreach ($item in (Get-ChildItem -LiteralPath $FromDir -Force -ErrorAction Stop)) {
        $targetPath = Join-Path $ToDir $item.Name
        if (-not $item.PSIsContainer -and $preserveIfPresent -contains $item.Name -and (Test-Path -LiteralPath $targetPath)) {
            continue
        }

        Copy-Item -LiteralPath $item.FullName -Destination $ToDir -Recurse -Force
    }
}

function Write-UpdateMarker {
    param(
        [Parameter(Mandatory)]
        [string]$DirectoryPath,
        [string]$VersionText
    )

    New-Item -ItemType Directory -Force -Path $DirectoryPath | Out-Null
    $marker = [ordered]@{
        applied_version = $VersionText
        applied_at = [DateTimeOffset]::UtcNow.ToString("o")
    } | ConvertTo-Json -Depth 4
    Set-Content -LiteralPath (Join-Path $DirectoryPath "last-applied-update.json") -Value $marker -Encoding UTF8
}

function Remove-TransientUpdateFiles {
    param(
        [Parameter(Mandatory)]
        [string]$DirectoryPath
    )

    foreach ($childName in @("downloads", "staging")) {
        $childPath = Join-Path $DirectoryPath $childName
        if (Test-Path -LiteralPath $childPath) {
            Remove-Item -LiteralPath $childPath -Recurse -Force
        }
    }
}

try {
    Wait-ForParentExit -PidToWait $ParentPid
    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Update payload not found: $SourceDir"
    }

    Copy-UpdateFiles -FromDir $SourceDir -ToDir $TargetDir
    Write-UpdateMarker -DirectoryPath $RuntimeDir -VersionText $ExpectedVersion
    Remove-TransientUpdateFiles -DirectoryPath $RuntimeDir

    $errorLogPath = Join-Path $RuntimeDir "update-error.log"
    if (Test-Path -LiteralPath $errorLogPath) {
        Remove-Item -LiteralPath $errorLogPath -Force
    }
}
catch {
    New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $RuntimeDir "update-error.log") -Encoding UTF8
    exit 1
}
""";

    private sealed class LocalModManifest
    {
        [JsonPropertyName("version")]
        public string? Version { get; set; }
    }

    private sealed class GitHubRelease
    {
        [JsonPropertyName("tag_name")]
        public string? TagName { get; set; }

        [JsonPropertyName("name")]
        public string? Name { get; set; }

        [JsonPropertyName("assets")]
        public List<GitHubReleaseAsset>? Assets { get; set; }
    }

    private sealed class GitHubReleaseAsset
    {
        [JsonPropertyName("name")]
        public string? Name { get; set; }

        [JsonPropertyName("browser_download_url")]
        public string? BrowserDownloadUrl { get; set; }

        [JsonPropertyName("content_type")]
        public string? ContentType { get; set; }
    }
}
