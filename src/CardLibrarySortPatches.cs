using System.Globalization;
using System.Reflection;
using System.Runtime.CompilerServices;
using Godot;
using HarmonyLib;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Helpers;
using MegaCrit.Sts2.Core.Localization;
using MegaCrit.Sts2.Core.Logging;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Nodes.Cards;
using MegaCrit.Sts2.Core.Nodes.CommonUi;
using MegaCrit.Sts2.Core.Nodes.GodotExtensions;
using MegaCrit.Sts2.Core.Nodes.Screens.CardLibrary;

namespace HeyboxCardStatsOverlay;

[HarmonyPatch(typeof(NCardLibrary), "_Ready")]
internal static class CardLibraryReadyPatch
{
    private const string PickRateButtonName = "HeyboxPickRateSorter";

    private const string WinRateButtonName = "HeyboxWinRateSorter";

    private const float SidebarLayoutGap = 8f;

    private static readonly FieldInfo? LastHoveredControlField = typeof(NCardLibrary).GetField("_lastHoveredControl", BindingFlags.Instance | BindingFlags.NonPublic);

    private static readonly FieldInfo? BackButtonShowPosField = typeof(NBackButton).GetField("_showPos", BindingFlags.Instance | BindingFlags.NonPublic);

    private static readonly FieldInfo? BackButtonHidePosField = typeof(NBackButton).GetField("_hidePos", BindingFlags.Instance | BindingFlags.NonPublic);

    private static void Postfix(NCardLibrary __instance)
    {
        try
        {
            NCardViewSortButton? alphabetSorter = __instance.GetNodeOrNull<NCardViewSortButton>("%AlphabetSorter");
            NCardLibraryGrid? grid = __instance.GetNodeOrNull<NCardLibraryGrid>("%CardGrid");
            if (alphabetSorter == null || grid == null || alphabetSorter.GetParent() is not Node parent)
            {
                return;
            }

            NCardViewSortButton pickRateButton = parent.GetNodeOrNull<NCardViewSortButton>(PickRateButtonName)
                ?? CreateSortButton(alphabetSorter, PickRateButtonName);
            NCardViewSortButton winRateButton = parent.GetNodeOrNull<NCardViewSortButton>(WinRateButtonName)
                ?? CreateSortButton(alphabetSorter, WinRateButtonName);

            if (pickRateButton.GetParent() == null)
            {
                parent.AddChild(pickRateButton);
            }

            if (winRateButton.GetParent() == null)
            {
                parent.AddChild(winRateButton);
            }

            int alphabetIndex = alphabetSorter.GetIndex();
            parent.MoveChild(pickRateButton, alphabetIndex);
            parent.MoveChild(winRateButton, alphabetIndex + 1);

            pickRateButton.SetLabel(UiTextProvider.Get(ModEntry.Config.LabelLanguage).PickRate);
            winRateButton.SetLabel(UiTextProvider.Get(ModEntry.Config.LabelLanguage).WinRate);

            CardLibrarySortStateStore.Register(__instance, grid, pickRateButton, winRateButton);
            ResetCustomSort(__instance);

            pickRateButton.Connect(NClickableControl.SignalName.Released, Callable.From<NClickableControl>(button =>
                OnStatSortReleased(__instance, CardLibraryStatSortMetric.PickRate, button)));
            winRateButton.Connect(NClickableControl.SignalName.Released, Callable.From<NClickableControl>(button =>
                OnStatSortReleased(__instance, CardLibraryStatSortMetric.WinRate, button)));
            pickRateButton.Connect(Control.SignalName.FocusEntered, Callable.From(() => SetLastHoveredControl(__instance, pickRateButton)));
            winRateButton.Connect(Control.SignalName.FocusEntered, Callable.From(() => SetLastHoveredControl(__instance, winRateButton)));
            ScheduleSidebarLayoutAdjustment(__instance);
        }
        catch (Exception ex)
        {
            Log.Warn($"HeyboxCardStatsOverlay: failed to initialize card library stat sort buttons: {ex.Message}", 2);
        }
    }

    private static NCardViewSortButton CreateSortButton(NCardViewSortButton source, string name)
    {
        const int duplicateWithoutSignalsFlags = 14;
        NCardViewSortButton button = (NCardViewSortButton)source.Duplicate(duplicateWithoutSignalsFlags);
        button.Name = name;
        DetachVisualResources(button);
        return button;
    }

    private static void DetachVisualResources(NCardViewSortButton button)
    {
        TextureRect? buttonImage = button.GetNodeOrNull<TextureRect>("ButtonImage");
        if (buttonImage?.Material != null)
        {
            buttonImage.Material = (Material)buttonImage.Material.Duplicate(true);
        }
    }

    private static void OnStatSortReleased(NCardLibrary screen, CardLibraryStatSortMetric metric, NClickableControl button)
    {
        if (button is not NCardViewSortButton sorter
            || !CardLibrarySortStateStore.TryGet(screen, out CardLibrarySortState? state)
            || state == null)
        {
            return;
        }

        state.ActiveMetric = metric;
        if (metric == CardLibraryStatSortMetric.PickRate)
        {
            state.WinRateButton.IsDescending = true;
        }
        else
        {
            state.PickRateButton.IsDescending = true;
        }

        if (!ReferenceEquals(state.GetButton(metric), sorter))
        {
            return;
        }

        InvokeUpdateFilter(screen);
    }

    private static void SetLastHoveredControl(NCardLibrary screen, Control control)
    {
        LastHoveredControlField?.SetValue(screen, control);
    }

    internal static void ResetCustomSort(NCardLibrary screen)
    {
        if (!CardLibrarySortStateStore.TryGet(screen, out CardLibrarySortState? state) || state == null)
        {
            return;
        }

        state.ActiveMetric = CardLibraryStatSortMetric.None;
        state.PickRateButton.IsDescending = true;
        state.WinRateButton.IsDescending = true;
    }

    internal static void InvokeUpdateFilter(NCardLibrary screen)
    {
        screen.CallDeferred(NCardLibrary.MethodName.UpdateFilter, false);
    }

    internal static void ScheduleSidebarLayoutAdjustment(NCardLibrary screen)
    {
        TaskHelper.RunSafely(AdjustSidebarLayoutAfterDelay(screen));
    }

    private static async Task AdjustSidebarLayoutAfterDelay(NCardLibrary screen)
    {
        SceneTree? tree = screen.GetTree();
        if (tree == null)
        {
            return;
        }

        SceneTreeTimer timer = tree.CreateTimer(0.45);
        await screen.ToSignal(timer, SceneTreeTimer.SignalName.Timeout);
        AdjustSidebarLayout(screen);
    }

    internal static void AdjustSidebarLayout(NCardLibrary screen)
    {
        if (!CardLibrarySortStateStore.TryGet(screen, out CardLibrarySortState? state) || state == null)
        {
            return;
        }

        NBackButton? backButton = state.BackButton;
        Control? bottomVBox = screen.GetNodeOrNull<Control>("Sidebar/MarginContainer/BottomVBox");
        NCardViewSortButton? alphabetSorter = screen.GetNodeOrNull<NCardViewSortButton>("%AlphabetSorter");
        if (backButton == null || bottomVBox == null || alphabetSorter == null)
        {
            return;
        }

        float lowestSorterBottom = Math.Max(
            alphabetSorter.GlobalPosition.Y + alphabetSorter.Size.Y,
            Math.Max(
                state.PickRateButton.GlobalPosition.Y + state.PickRateButton.Size.Y,
                state.WinRateButton.GlobalPosition.Y + state.WinRateButton.Size.Y));
        float minBackTop = lowestSorterBottom + SidebarLayoutGap;
        float maxBackTop = bottomVBox.GlobalPosition.Y - backButton.Size.Y - SidebarLayoutGap;
        if (maxBackTop <= backButton.GlobalPosition.Y)
        {
            return;
        }

        float newBackTop = Math.Clamp(minBackTop, backButton.GlobalPosition.Y, maxBackTop);
        float deltaY = newBackTop - backButton.GlobalPosition.Y;
        if (deltaY <= 0f)
        {
            return;
        }

        Vector2 currentShowPos = BackButtonShowPosField?.GetValue(backButton) is Vector2 showPos
            ? showPos
            : backButton.GlobalPosition;
        Vector2 currentHidePos = BackButtonHidePosField?.GetValue(backButton) is Vector2 hidePos
            ? hidePos
            : backButton.GlobalPosition;
        Vector2 adjustedShowPos = currentShowPos + new Vector2(0f, deltaY);
        Vector2 adjustedHidePos = currentHidePos + new Vector2(0f, deltaY);

        BackButtonShowPosField?.SetValue(backButton, adjustedShowPos);
        BackButtonHidePosField?.SetValue(backButton, adjustedHidePos);
        backButton.GlobalPosition = adjustedShowPos;
    }
}

[HarmonyPatch(typeof(NCardLibrary), "OnSubmenuOpened")]
internal static class CardLibraryOnSubmenuOpenedPatch
{
    private static void Prefix(NCardLibrary __instance)
    {
        CardLibraryReadyPatch.ResetCustomSort(__instance);
    }

    private static void Postfix(NCardLibrary __instance)
    {
        CardLibraryReadyPatch.ScheduleSidebarLayoutAdjustment(__instance);
    }
}

[HarmonyPatch(typeof(NCardLibrary), "OnCardTypeSort")]
internal static class CardLibraryOnCardTypeSortPatch
{
    private static void Prefix(NCardLibrary __instance)
    {
        CardLibraryReadyPatch.ResetCustomSort(__instance);
    }
}

[HarmonyPatch(typeof(NCardLibrary), "OnRaritySort")]
internal static class CardLibraryOnRaritySortPatch
{
    private static void Prefix(NCardLibrary __instance)
    {
        CardLibraryReadyPatch.ResetCustomSort(__instance);
    }
}

[HarmonyPatch(typeof(NCardLibrary), "OnCostSort")]
internal static class CardLibraryOnCostSortPatch
{
    private static void Prefix(NCardLibrary __instance)
    {
        CardLibraryReadyPatch.ResetCustomSort(__instance);
    }
}

[HarmonyPatch(typeof(NCardLibrary), "OnAlphabetSort")]
internal static class CardLibraryOnAlphabetSortPatch
{
    private static void Prefix(NCardLibrary __instance)
    {
        CardLibraryReadyPatch.ResetCustomSort(__instance);
    }
}

[HarmonyPatch(typeof(NCardLibraryGrid), "FilterCards", typeof(Func<CardModel, bool>), typeof(List<SortingOrders>))]
internal static class CardLibraryGridFilterCardsPatch
{
    private static readonly FieldInfo? AllCardsField = typeof(NCardLibraryGrid).GetField("_allCards", BindingFlags.Instance | BindingFlags.NonPublic);

    private static bool Prefix(NCardLibraryGrid __instance, Func<CardModel, bool> filter, List<SortingOrders> sortingPriority)
    {
        try
        {
            if (!CardLibrarySortStateStore.TryGet(__instance, out CardLibrarySortState? state) || state == null || !state.HasCustomSort)
            {
                return true;
            }

            if (AllCardsField?.GetValue(__instance) is not List<CardModel> allCards)
            {
                return true;
            }

            List<CardModel> filteredCards = allCards.Where(filter).ToList();
            Dictionary<CardModel, double?> metricValues = filteredCards.ToDictionary(
                card => card,
                card => GetMetricValue(state.ActiveMetric, ModEntry.Repository.Resolve(card.Id?.ToString() ?? string.Empty, card)));

            bool descending = state.GetButton(state.ActiveMetric).IsDescending;
            filteredCards.Sort((left, right) => CompareCards(left, right, metricValues, descending, sortingPriority));

            List<SortingOrders> preserveOrder = new()
            {
                SortingOrders.Ascending
            };
            __instance.SetCards(filteredCards, PileType.None, preserveOrder, Task.CompletedTask);
            return false;
        }
        catch (Exception ex)
        {
            Log.Warn($"HeyboxCardStatsOverlay: failed to apply card library stat sorting: {ex.Message}", 2);
            return true;
        }
    }

    private static double? GetMetricValue(CardLibraryStatSortMetric metric, CardStatsLookupResult lookup)
    {
        CardStatsValues? stats = lookup.Card?.Stats;
        return metric switch
        {
            CardLibraryStatSortMetric.PickRate => stats?.PickRate,
            CardLibraryStatSortMetric.WinRate => stats?.WinRate,
            _ => null
        };
    }

    private static int CompareCards(
        CardModel left,
        CardModel right,
        IReadOnlyDictionary<CardModel, double?> metricValues,
        bool descending,
        IReadOnlyList<SortingOrders> sortingPriority)
    {
        double? leftValue = metricValues[left];
        double? rightValue = metricValues[right];
        bool leftHasValue = leftValue.HasValue;
        bool rightHasValue = rightValue.HasValue;

        if (leftHasValue != rightHasValue)
        {
            return leftHasValue ? -1 : 1;
        }

        if (leftHasValue)
        {
            int valueComparison = leftValue.GetValueOrDefault().CompareTo(rightValue.GetValueOrDefault());
            if (valueComparison != 0)
            {
                return descending ? -valueComparison : valueComparison;
            }
        }

        int tieBreak = CompareUsingSortingPriority(left, right, sortingPriority);
        if (tieBreak != 0)
        {
            return tieBreak;
        }

        return string.CompareOrdinal(left.Id?.ToString() ?? string.Empty, right.Id?.ToString() ?? string.Empty);
    }

    private static int CompareUsingSortingPriority(CardModel left, CardModel right, IReadOnlyList<SortingOrders> sortingPriority)
    {
        foreach (SortingOrders order in sortingPriority)
        {
            int result = order switch
            {
                SortingOrders.RarityAscending => GetCardRarityComparisonValue(left).CompareTo(GetCardRarityComparisonValue(right)),
                SortingOrders.RarityDescending => -GetCardRarityComparisonValue(left).CompareTo(GetCardRarityComparisonValue(right)),
                SortingOrders.CostAscending => left.EnergyCost.Canonical.CompareTo(right.EnergyCost.Canonical),
                SortingOrders.CostDescending => -left.EnergyCost.Canonical.CompareTo(right.EnergyCost.Canonical),
                SortingOrders.TypeAscending => left.Type.CompareTo(right.Type),
                SortingOrders.TypeDescending => -left.Type.CompareTo(right.Type),
                SortingOrders.AlphabetAscending => string.Compare(left.Title, right.Title, LocManager.Instance.CultureInfo, CompareOptions.None),
                SortingOrders.AlphabetDescending => -string.Compare(left.Title, right.Title, LocManager.Instance.CultureInfo, CompareOptions.None),
                _ => 0
            };

            if (result != 0)
            {
                return result;
            }
        }

        return 0;
    }

    private static int GetCardRarityComparisonValue(CardModel card)
    {
        if (card.Rarity <= CardRarity.Ancient)
        {
            return (int)card.Rarity;
        }

        return card.Rarity switch
        {
            CardRarity.Status => 6,
            CardRarity.Curse => 7,
            CardRarity.Event => 8,
            CardRarity.Quest => 9,
            CardRarity.Token => 10,
            _ => throw new ArgumentOutOfRangeException(nameof(card), card.Rarity, null)
        };
    }
}

internal static class CardLibrarySortStateStore
{
    private static readonly ConditionalWeakTable<NCardLibrary, CardLibrarySortState> ScreenStates = new();

    private static readonly ConditionalWeakTable<NCardLibraryGrid, CardLibrarySortState> GridStates = new();

    public static void Register(
        NCardLibrary screen,
        NCardLibraryGrid grid,
        NCardViewSortButton pickRateButton,
        NCardViewSortButton winRateButton)
    {
        NBackButton? backButton = screen.GetNodeOrNull<NBackButton>("BackButton");
        CardLibrarySortState state = new(
            screen,
            grid,
            pickRateButton,
            winRateButton,
            backButton);
        ScreenStates.Remove(screen);
        ScreenStates.Add(screen, state);
        GridStates.Remove(grid);
        GridStates.Add(grid, state);
    }

    public static bool TryGet(NCardLibrary screen, out CardLibrarySortState? state)
    {
        return ScreenStates.TryGetValue(screen, out state);
    }

    public static bool TryGet(NCardLibraryGrid grid, out CardLibrarySortState? state)
    {
        return GridStates.TryGetValue(grid, out state);
    }
}

internal sealed class CardLibrarySortState(
    NCardLibrary screen,
    NCardLibraryGrid grid,
    NCardViewSortButton pickRateButton,
    NCardViewSortButton winRateButton,
    NBackButton? backButton)
{
    public NCardLibrary Screen { get; } = screen;

    public NCardLibraryGrid Grid { get; } = grid;

    public NCardViewSortButton PickRateButton { get; } = pickRateButton;

    public NCardViewSortButton WinRateButton { get; } = winRateButton;

    public NBackButton? BackButton { get; } = backButton;

    public CardLibraryStatSortMetric ActiveMetric { get; set; }

    public bool HasCustomSort => ActiveMetric != CardLibraryStatSortMetric.None;

    public NCardViewSortButton GetButton(CardLibraryStatSortMetric metric)
    {
        return metric switch
        {
            CardLibraryStatSortMetric.PickRate => PickRateButton,
            CardLibraryStatSortMetric.WinRate => WinRateButton,
            _ => PickRateButton
        };
    }
}

internal enum CardLibraryStatSortMetric
{
    None,
    PickRate,
    WinRate
}
