using System.Text.Json;
using System.Text.Json.Serialization;

namespace HeyboxCardStatsOverlay;

internal sealed class ModConfig
{
    private const string LegacyCloudflareTelemetryEndpoint = "https://sts2-card-stats-telemetry.xmeowchan0415.workers.dev/v1/heartbeat";

    private const string PrimaryTelemetryEndpoint = "https://telemetry.xmeow.cn/v1/heartbeat";

    private static readonly string[] DefaultTelemetryEndpoints =
    {
        PrimaryTelemetryEndpoint,
        LegacyCloudflareTelemetryEndpoint
    };

    [JsonPropertyName("enabled")]
    public bool Enabled { get; set; } = true;

    [JsonPropertyName("hide_from_multiplayer_mod_list")]
    public bool HideFromMultiplayerModList { get; set; } = true;

    [JsonPropertyName("data_file")]
    public string DataFile { get; set; } = "cards.json";

    [JsonPropertyName("label_language")]
    public string LabelLanguage { get; set; } = "auto";

    [JsonPropertyName("panel_width")]
    public int PanelWidth { get; set; } = 300;

    [JsonPropertyName("show_counts")]
    public bool ShowCounts { get; set; } = true;

    [JsonPropertyName("show_ranks")]
    public bool ShowRanks { get; set; } = true;

    [JsonPropertyName("show_skip_rate")]
    public bool ShowSkipRate { get; set; } = true;

    [JsonPropertyName("remote_data_enabled")]
    public bool RemoteDataEnabled { get; set; } = false;

    [JsonPropertyName("remote_data_url")]
    public string RemoteDataUrl { get; set; } = string.Empty;

    [JsonPropertyName("remote_refresh_minutes")]
    public int RemoteRefreshMinutes { get; set; } = 180;

    [JsonPropertyName("remote_timeout_seconds")]
    public int RemoteTimeoutSeconds { get; set; } = 5;

    [JsonPropertyName("mod_update_enabled")]
    public bool ModUpdateEnabled { get; set; } = false;

    [JsonPropertyName("mod_update_github_repo")]
    public string ModUpdateGithubRepo { get; set; } = "XMeowchan/STS2_Card_Stats";

    [JsonPropertyName("mod_update_timeout_seconds")]
    public int ModUpdateTimeoutSeconds { get; set; } = 15;

    [JsonPropertyName("telemetry_enabled")]
    public bool TelemetryEnabled { get; set; } = true;

    [JsonPropertyName("telemetry_endpoint")]
    public string TelemetryEndpoint { get; set; } = PrimaryTelemetryEndpoint;

    [JsonPropertyName("telemetry_endpoints")]
    public string[] TelemetryEndpoints { get; set; } = DefaultTelemetryEndpoints.ToArray();

    [JsonPropertyName("telemetry_timeout_seconds")]
    public int TelemetryTimeoutSeconds { get; set; } = 5;

    public static ModConfig Load(string path)
    {
        ModConfig defaults = new ModConfig();
        try
        {
            if (File.Exists(path))
            {
                string json = File.ReadAllText(path);
                ModConfig? parsed = JsonSerializer.Deserialize<ModConfig>(json, JsonOptions);
                if (parsed != null)
                {
                    if (parsed.Normalize())
                    {
                        parsed.TryWrite(path);
                    }

                    return parsed;
                }
            }
        }
        catch
        {
        }

        defaults.Normalize();
        defaults.Write(path);
        return defaults;
    }

    public void Write(string path)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        string json = JsonSerializer.Serialize(this, JsonOptionsIndented);
        File.WriteAllText(path, json);
    }

    private bool Normalize()
    {
        bool changed = false;

        if (string.IsNullOrWhiteSpace(DataFile))
        {
            DataFile = "cards.json";
            changed = true;
        }

        if (string.IsNullOrWhiteSpace(LabelLanguage))
        {
            LabelLanguage = "auto";
            changed = true;
        }

        if (PanelWidth != Math.Clamp(PanelWidth, 240, 420))
        {
            changed = true;
        }
        PanelWidth = Math.Clamp(PanelWidth, 240, 420);

        string remoteDataUrl = (RemoteDataUrl ?? string.Empty).Trim();
        if (!string.Equals(RemoteDataUrl, remoteDataUrl, StringComparison.Ordinal))
        {
            RemoteDataUrl = remoteDataUrl;
            changed = true;
        }

        int remoteRefreshMinutes = Math.Clamp(RemoteRefreshMinutes, 5, 1440);
        if (RemoteRefreshMinutes != remoteRefreshMinutes)
        {
            RemoteRefreshMinutes = remoteRefreshMinutes;
            changed = true;
        }

        int remoteTimeoutSeconds = Math.Clamp(RemoteTimeoutSeconds, 2, 30);
        if (RemoteTimeoutSeconds != remoteTimeoutSeconds)
        {
            RemoteTimeoutSeconds = remoteTimeoutSeconds;
            changed = true;
        }

        string modUpdateGithubRepo = (ModUpdateGithubRepo ?? string.Empty).Trim().Trim('/');
        if (!string.Equals(ModUpdateGithubRepo, modUpdateGithubRepo, StringComparison.Ordinal))
        {
            ModUpdateGithubRepo = modUpdateGithubRepo;
            changed = true;
        }

        int modUpdateTimeoutSeconds = Math.Clamp(ModUpdateTimeoutSeconds, 5, 60);
        if (ModUpdateTimeoutSeconds != modUpdateTimeoutSeconds)
        {
            ModUpdateTimeoutSeconds = modUpdateTimeoutSeconds;
            changed = true;
        }

        string telemetryEndpoint = (TelemetryEndpoint ?? string.Empty).Trim();
        if (!string.Equals(TelemetryEndpoint, telemetryEndpoint, StringComparison.Ordinal))
        {
            TelemetryEndpoint = telemetryEndpoint;
            changed = true;
        }

        string[] currentTelemetryEndpoints = TelemetryEndpoints ?? Array.Empty<string>();
        string[] telemetryEndpoints = currentTelemetryEndpoints
            .Select(static endpoint => (endpoint ?? string.Empty).Trim())
            .Where(static endpoint => endpoint.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (TelemetryEndpoints is null
            || !currentTelemetryEndpoints.SequenceEqual(telemetryEndpoints, StringComparer.Ordinal))
        {
            TelemetryEndpoints = telemetryEndpoints;
            changed = true;
        }

        string[] effectiveTelemetryEndpoints = TelemetryEndpoints ?? telemetryEndpoints;
        string effectiveTelemetryEndpoint = TelemetryEndpoint ?? telemetryEndpoint;

        if (effectiveTelemetryEndpoints.Length == 0 && effectiveTelemetryEndpoint.Length > 0)
        {
            effectiveTelemetryEndpoints = new[] { effectiveTelemetryEndpoint };
            changed = true;
        }

        if (ShouldPromoteDomesticPrimary(effectiveTelemetryEndpoints))
        {
            if (!effectiveTelemetryEndpoints.SequenceEqual(DefaultTelemetryEndpoints, StringComparer.OrdinalIgnoreCase))
            {
                effectiveTelemetryEndpoints = DefaultTelemetryEndpoints.ToArray();
                changed = true;
            }
        }
        else if (effectiveTelemetryEndpoints.Length == 0)
        {
            effectiveTelemetryEndpoints = DefaultTelemetryEndpoints.ToArray();
            changed = true;
        }

        if (effectiveTelemetryEndpoints.Length > 0
            && !string.Equals(effectiveTelemetryEndpoint, effectiveTelemetryEndpoints[0], StringComparison.Ordinal))
        {
            effectiveTelemetryEndpoint = effectiveTelemetryEndpoints[0];
            changed = true;
        }

        TelemetryEndpoints = effectiveTelemetryEndpoints;
        TelemetryEndpoint = effectiveTelemetryEndpoint;

        int telemetryTimeoutSeconds = Math.Clamp(TelemetryTimeoutSeconds, 2, 30);
        if (TelemetryTimeoutSeconds != telemetryTimeoutSeconds)
        {
            TelemetryTimeoutSeconds = telemetryTimeoutSeconds;
            changed = true;
        }

        return changed;
    }

    private void TryWrite(string path)
    {
        try
        {
            Write(path);
        }
        catch
        {
        }
    }

    private static bool ShouldPromoteDomesticPrimary(string[] endpoints)
    {
        if (endpoints.Length == 1
            && string.Equals(endpoints[0], LegacyCloudflareTelemetryEndpoint, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        if (endpoints.Length != 2)
        {
            return false;
        }

        return endpoints.Contains(LegacyCloudflareTelemetryEndpoint, StringComparer.OrdinalIgnoreCase)
            && endpoints.Contains(PrimaryTelemetryEndpoint, StringComparer.OrdinalIgnoreCase);
    }

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
}
