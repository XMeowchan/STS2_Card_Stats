using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Logging;
using MegaCrit.Sts2.Core.Nodes.Cards.Holders;
using MegaCrit.Sts2.Core.Nodes.HoverTips;
using Godot;
using HarmonyLib;

namespace HeyboxCardStatsOverlay;

[HarmonyPatch(typeof(NHoverTipSet), nameof(NHoverTipSet.CreateAndShow), new[] { typeof(Control), typeof(IEnumerable<IHoverTip>), typeof(HoverTipAlignment) })]
internal static class HoverTipSetCreateAndShowPatch
{
    private const string TipIdPrefix = "heybox-card-data:";

    private static bool _loggedInjection;

    private static void Prefix(Control owner, ref IEnumerable<IHoverTip> hoverTips)
    {
        if (!ModEntry.Config.Enabled)
        {
            return;
        }

        if (owner is not NCardHolder holder || holder.CardNode?.Model == null)
        {
            return;
        }

        if (hoverTips.Any(static tip => tip.Id.StartsWith(TipIdPrefix, StringComparison.OrdinalIgnoreCase)))
        {
            return;
        }

        HoverStatsBuiltTip builtTip = HoverStatsTipBuilder.BuildTip(holder.CardNode.Model);
        hoverTips = hoverTips.Append(builtTip.Tip);
        if (!_loggedInjection)
        {
            _loggedInjection = true;
            Log.Info($"HeyboxCardStatsOverlay: native hover tip hook active for '{holder.CardNode.Model.Id}'.", 2);
        }
    }
}
