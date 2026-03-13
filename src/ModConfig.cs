using System.Text.Json;
using System.Text.Json.Serialization;

namespace HeyboxCardStatsOverlay;

internal sealed class ModConfig
{
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
    public string TelemetryEndpoint { get; set; } = "https://sts2-card-stats-telemetry.xmeowchan0415.workers.dev/v1/heartbeat";

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
                    parsed.Normalize();
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

    private void Normalize()
    {
        if (string.IsNullOrWhiteSpace(DataFile))
        {
            DataFile = "cards.json";
        }

        if (string.IsNullOrWhiteSpace(LabelLanguage))
        {
            LabelLanguage = "auto";
        }

        PanelWidth = Math.Clamp(PanelWidth, 240, 420);
        RemoteDataUrl = (RemoteDataUrl ?? string.Empty).Trim();
        RemoteRefreshMinutes = Math.Clamp(RemoteRefreshMinutes, 5, 1440);
        RemoteTimeoutSeconds = Math.Clamp(RemoteTimeoutSeconds, 2, 30);
        ModUpdateGithubRepo = (ModUpdateGithubRepo ?? string.Empty).Trim().Trim('/');
        ModUpdateTimeoutSeconds = Math.Clamp(ModUpdateTimeoutSeconds, 5, 60);
        TelemetryEndpoint = (TelemetryEndpoint ?? string.Empty).Trim();
        TelemetryTimeoutSeconds = Math.Clamp(TelemetryTimeoutSeconds, 2, 30);
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
