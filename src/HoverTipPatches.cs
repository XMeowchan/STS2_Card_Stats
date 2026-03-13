using System.Reflection;
using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Logging;
using MegaCrit.Sts2.Core.Nodes.Combat;
using MegaCrit.Sts2.Core.Nodes.Cards;
using MegaCrit.Sts2.Core.Nodes.Cards.Holders;
using MegaCrit.Sts2.Core.Nodes.HoverTips;
using MegaCrit.Sts2.Core.Nodes.Rooms;
using MegaCrit.Sts2.Core.Nodes.Screens;
using MegaCrit.Sts2.Core.Nodes.Screens.Shops;
using MegaCrit.Sts2.Core.Models;
using Godot;
using HarmonyLib;

namespace HeyboxCardStatsOverlay;

[HarmonyPatch(typeof(NHoverTipSet), nameof(NHoverTipSet.CreateAndShow), new[] { typeof(Control), typeof(IEnumerable<IHoverTip>), typeof(HoverTipAlignment) })]
internal static class HoverTipSetCreateAndShowPatch
{
    private const string TipIdPrefix = "heybox-card-data:";

    private static readonly FieldInfo? MerchantCardNodeField = typeof(NMerchantCard).GetField("_cardNode", BindingFlags.Instance | BindingFlags.NonPublic);

    private static readonly FieldInfo? InspectCardScreenCardField = typeof(NInspectCardScreen).GetField("_card", BindingFlags.Instance | BindingFlags.NonPublic);

    private static bool _loggedInjection;

    private static void Prefix(Control owner, ref IEnumerable<IHoverTip> hoverTips)
    {
        if (!ModEntry.Config.Enabled)
        {
            return;
        }

        if (!TryResolveCardContext(owner, out CardModel cardModel, out NCardHolder? holder))
        {
            return;
        }

        if (!ShouldShowStatsTip(owner, holder)
            || hoverTips.Any(static tip => tip.Id.StartsWith(TipIdPrefix, StringComparison.OrdinalIgnoreCase)))
        {
            return;
        }

        HoverStatsBuiltTip builtTip = HoverStatsTipBuilder.BuildTip(cardModel);
        hoverTips = hoverTips.Append(builtTip.Tip);
        if (!_loggedInjection)
        {
            _loggedInjection = true;
            Log.Info($"HeyboxCardStatsOverlay: native hover tip hook active for '{cardModel.Id}'.", 2);
        }
    }

    private static bool ShouldShowStatsTip(Control owner, NCardHolder? holder)
    {
        if (owner is NInspectCardScreen || HasAncestor<NInspectCardScreen>(owner))
        {
            return false;
        }

        if (HasAncestor<NMerchantCard>(owner)
            || HasAncestor<NMerchantInventory>(owner)
            || HasAncestor<NMerchantRoom>(owner))
        {
            return true;
        }

        if (CombatManager.Instance?.IsInProgress != true)
        {
            return true;
        }

        if (holder is NHandCardHolder or NSelectedHandCardHolder
            || HasAncestor<NPlayerHand>(owner))
        {
            return false;
        }

        if (TryGetAncestor(owner, out NCardPileScreen? pileScreen)
            && pileScreen?.Pile is { IsCombatPile: true } pile
            && pile.Type is PileType.Draw or PileType.Discard or PileType.Exhaust)
        {
            return false;
        }

        if (HasAncestor<NCombatRoom>(owner)
            && holder is NPreviewCardHolder
            && !HasAncestor<NMerchantRoom>(owner))
        {
            return false;
        }

        return true;
    }

    private static bool TryResolveCardContext(Control owner, out CardModel cardModel, out NCardHolder? holder)
    {
        holder = null;
        cardModel = null!;

        if (owner is NCardHolder directHolder && directHolder.CardNode?.Model != null)
        {
            holder = directHolder;
            cardModel = directHolder.CardNode.Model;
            return true;
        }

        if (TryGetAncestor(owner, out NCardHolder? ancestorHolder) && ancestorHolder?.CardNode?.Model != null)
        {
            holder = ancestorHolder;
            cardModel = ancestorHolder.CardNode.Model;
            return true;
        }

        NMerchantCard? merchantCard = owner as NMerchantCard;
        if (merchantCard == null)
        {
            TryGetAncestor(owner, out merchantCard);
        }

        if (merchantCard != null
            && MerchantCardNodeField?.GetValue(merchantCard) is NCard merchantCardNode
            && merchantCardNode.Model != null)
        {
            cardModel = merchantCardNode.Model;
            return true;
        }

        NInspectCardScreen? inspectCardScreen = owner as NInspectCardScreen;
        if (inspectCardScreen == null)
        {
            TryGetAncestor(owner, out inspectCardScreen);
        }

        if (inspectCardScreen != null
            && InspectCardScreenCardField?.GetValue(inspectCardScreen) is NCard inspectCardNode
            && inspectCardNode.Model != null)
        {
            cardModel = inspectCardNode.Model;
            return true;
        }

        return false;
    }

    private static bool HasAncestor<TNode>(Node node)
        where TNode : Node
    {
        for (Node? current = node; current != null; current = current.GetParent())
        {
            if (current is TNode)
            {
                return true;
            }
        }

        return false;
    }

    private static bool TryGetAncestor<TNode>(Node node, out TNode? ancestor)
        where TNode : Node
    {
        for (Node? current = node; current != null; current = current.GetParent())
        {
            if (current is TNode typedNode)
            {
                ancestor = typedNode;
                return true;
            }
        }

        ancestor = null;
        return false;
    }
}
