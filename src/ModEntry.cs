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

    public static void Initialize()
    {
        lock (InitLock)
        {
            if (_initialized)
            {
                return;
            }

            ModDirectory = ResolveModDirectory();
            string configPath = Path.Combine(ModDirectory, "config.json");
            Config = ModConfig.Load(configPath);
            Repository = new CardStatsRepository(ModDirectory, Config);
            AutoUpdater = new ModAutoUpdater(ModDirectory, Config);
            _harmony = new Harmony("cn.codex.sts2.heybox.cardstats");
            _harmony.PatchAll(Assembly.GetExecutingAssembly());
            AutoUpdater.QueueCheck();
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
}
