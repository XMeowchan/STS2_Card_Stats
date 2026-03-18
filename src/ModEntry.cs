using System.Reflection;
using HarmonyLib;
using MegaCrit.Sts2.Core.Logging;
using MegaCrit.Sts2.Core.Modding;

namespace HeyboxCardStatsOverlay;

[ModInitializer("Initialize")]
public static class ModEntry
{
    public const string ModId = "HeyboxCardStatsOverlay";

    private static readonly object InitLock = new();

    private static bool _initialized;

    private static Harmony? _harmony;

    internal static string ModDirectory { get; private set; } = string.Empty;

    internal static ModConfig Config { get; private set; } = new();

    internal static CardStatsRepository Repository { get; private set; } = new(string.Empty, new ModConfig());

    internal static ModAutoUpdater AutoUpdater { get; private set; } = new(string.Empty, new ModConfig());

    internal static TelemetryClient Telemetry { get; private set; } = new(string.Empty, new ModConfig());

    public static void Initialize()
    {
        lock (InitLock)
        {
            if (_initialized)
            {
                return;
            }

            ModDirectory = ResolveModDirectory();
            MigrateLegacyFiles(ModDirectory);
            string configPath = ModLayout.GetConfigPath(ModDirectory);
            Config = ModConfig.Load(configPath);
            Repository = new CardStatsRepository(ModDirectory, Config);
            AutoUpdater = new ModAutoUpdater(ModDirectory, Config);
            Telemetry = new TelemetryClient(ModDirectory, Config);
            _harmony = new Harmony("cn.codex.sts2.heybox.cardstats");
            _harmony.PatchAll(Assembly.GetExecutingAssembly());
            AutoUpdater.QueueCheck();
            Telemetry.QueueDailyHeartbeat();
            _initialized = true;
            Log.Info($"HeyboxCardStatsOverlay loaded from '{ModDirectory}'.", 2);
        }
    }

    private static string ResolveModDirectory()
    {
        string? assemblyLocation = Assembly.GetExecutingAssembly().Location;
        if (!string.IsNullOrWhiteSpace(assemblyLocation))
        {
            string? directory = Path.GetDirectoryName(assemblyLocation);
            if (!string.IsNullOrWhiteSpace(directory))
            {
                return directory;
            }
        }

        return AppContext.BaseDirectory;
    }

    private static void MigrateLegacyFiles(string modDirectory)
    {
        TryMigrateFile(
            Path.Combine(modDirectory, ModLayout.LegacyConfigFileName),
            ModLayout.GetConfigPath(modDirectory),
            "config",
            overwriteExistingTarget: true);

        string dataPath = ModLayout.GetDataPath(modDirectory);
        TryMigrateFile(
            Path.Combine(modDirectory, ModLayout.LegacyDataFileName),
            dataPath,
            "card cache",
            overwriteExistingTarget: true);

        if (!File.Exists(dataPath))
        {
            TryMigrateFile(
                Path.Combine(modDirectory, ModLayout.LegacyFallbackDataFileName),
                dataPath,
                "fallback card cache");
        }

        TryDeleteLegacyFile(Path.Combine(modDirectory, ModLayout.LegacyFallbackDataFileName), "legacy fallback cache");
        TryDeleteLegacyFile(Path.Combine(modDirectory, ModLayout.LegacySampleDataFileName), "legacy sample cache");
        TryDeleteLegacyFile(Path.Combine(modDirectory, ModLayout.LegacySyncStateFileName), "legacy sync state");

        if (File.Exists(ModLayout.GetManifestPath(modDirectory)))
        {
            TryDeleteLegacyFile(Path.Combine(modDirectory, ModLayout.LegacyManifestFileName), "legacy manifest");
        }
    }

    private static void TryMigrateFile(string sourcePath, string targetPath, string label, bool overwriteExistingTarget = false)
    {
        try
        {
            if (!File.Exists(sourcePath))
            {
                return;
            }

            if (File.Exists(targetPath))
            {
                if (overwriteExistingTarget)
                {
                    File.Copy(sourcePath, targetPath, overwrite: true);
                }

                File.Delete(sourcePath);
                if (overwriteExistingTarget)
                {
                    Log.Info($"HeyboxCardStatsOverlay: migrated legacy {label} to '{targetPath}'.", 2);
                }
                return;
            }

            string? directory = Path.GetDirectoryName(targetPath);
            if (!string.IsNullOrWhiteSpace(directory))
            {
                Directory.CreateDirectory(directory);
            }

            File.Move(sourcePath, targetPath);
            Log.Info($"HeyboxCardStatsOverlay: migrated legacy {label} to '{targetPath}'.", 2);
        }
        catch (Exception ex)
        {
            Log.Warn($"HeyboxCardStatsOverlay: failed to migrate legacy {label} '{sourcePath}': {ex.Message}", 2);
        }
    }

    private static void TryDeleteLegacyFile(string path, string label)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
                Log.Info($"HeyboxCardStatsOverlay: removed {label} at '{path}'.", 2);
            }
        }
        catch (Exception ex)
        {
            Log.Warn($"HeyboxCardStatsOverlay: failed to remove {label} at '{path}': {ex.Message}", 2);
        }
    }
}
