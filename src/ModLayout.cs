namespace HeyboxCardStatsOverlay;

internal static class ModLayout
{
    public const string ManifestFileName = ModEntry.ModId + ".json";

    public const string LegacyManifestFileName = "mod_manifest.json";

    public const string ConfigFileName = "config.cfg";

    public const string LegacyConfigFileName = "config.json";

    public const string DefaultDataFileName = "cards.cache";

    public const string LegacyDataFileName = "cards.json";

    public const string LegacyFallbackDataFileName = "cards.fallback.json";

    public const string LegacySampleDataFileName = "cards.sample.json";

    public const string LegacySyncStateFileName = "sync_state.json";

    public static string GetManifestPath(string modDirectory)
    {
        return Path.Combine(modDirectory, ManifestFileName);
    }

    public static string GetConfigPath(string modDirectory)
    {
        return Path.Combine(modDirectory, ConfigFileName);
    }

    public static string GetDataPath(string modDirectory, string? dataFile = null)
    {
        string fileName = string.IsNullOrWhiteSpace(dataFile) ? DefaultDataFileName : dataFile.Trim();
        return Path.Combine(modDirectory, fileName);
    }

    public static string? FindManifestPath(string modDirectory)
    {
        foreach (string path in GetManifestCandidatePaths(modDirectory))
        {
            if (File.Exists(path))
            {
                return path;
            }
        }

        return null;
    }

    public static IEnumerable<string> GetManifestCandidatePaths(string modDirectory)
    {
        yield return GetManifestPath(modDirectory);
        yield return Path.Combine(modDirectory, LegacyManifestFileName);
    }
}
