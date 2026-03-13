using HarmonyLib;
using MegaCrit.Sts2.Core.Logging;
using MegaCrit.Sts2.Core.Modding;

namespace HeyboxCardStatsOverlay;

[HarmonyPatch(typeof(ModManager), nameof(ModManager.GetModNameList))]
internal static class MultiplayerModListPatch
{
    private static bool _loggedHide;

    private static void Postfix(ref List<string>? __result)
    {
        if (!ModEntry.Config.HideFromMultiplayerModList || __result == null || __result.Count == 0)
        {
            return;
        }

        int removedCount = __result.RemoveAll(static entry =>
            !string.IsNullOrWhiteSpace(entry)
            && entry.StartsWith(ModEntry.ModId, StringComparison.OrdinalIgnoreCase));
        if (removedCount <= 0)
        {
            return;
        }

        if (__result.Count == 0)
        {
            __result = null;
        }

        if (_loggedHide)
        {
            return;
        }

        _loggedHide = true;
        Log.Info("HeyboxCardStatsOverlay: hiding this mod from multiplayer mod-list checks.", 2);
    }
}
