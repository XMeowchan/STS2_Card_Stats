using System.Reflection;
using Godot;
using HarmonyLib;
using MegaCrit.Sts2.Core.Localization;
using MegaCrit.Sts2.Core.Nodes.Cards;
using MegaCrit.Sts2.Core.Nodes.Screens;

namespace HeyboxCardStatsOverlay;

[HarmonyPatch(typeof(NInspectCardScreen), "UpdateCardDisplay")]
internal static class InspectCardScreenUpdateCardDisplayPatch
{
    private const string StatsDockName = "HeyboxInspectStatsDock";

    private const string StatsPanelName = "HeyboxInspectStatsPanel";

    private const string ToggleButtonName = "HeyboxInspectStatsToggle";

    private static readonly FieldInfo? CardField = typeof(NInspectCardScreen).GetField("_card", BindingFlags.Instance | BindingFlags.NonPublic);

    private static readonly FieldInfo? HoverTipRectField = typeof(NInspectCardScreen).GetField("_hoverTipRect", BindingFlags.Instance | BindingFlags.NonPublic);

    private static readonly FieldInfo? LeftButtonField = typeof(NInspectCardScreen).GetField("_leftButton", BindingFlags.Instance | BindingFlags.NonPublic);

    private static bool _inspectStatsVisible = true;

    private static void Postfix(NInspectCardScreen __instance)
    {
        RemoveExistingDock(__instance);

        if (!ModEntry.Config.Enabled)
        {
            return;
        }

        if (CardField?.GetValue(__instance) is not NCard cardNode || cardNode.Model == null)
        {
            return;
        }

        VBoxContainer dock = EnsureDock(__instance);
        Button toggleButton = EnsureToggleButton(__instance, dock);
        toggleButton.Text = GetToggleText();
        toggleButton.TooltipText = GetToggleTooltip();

        if (dock.GetNodeOrNull<Control>(StatsPanelName) is Control existingPanel)
        {
            existingPanel.QueueFree();
        }

        if (_inspectStatsVisible)
        {
            HoverStatsBuiltTip builtTip = HoverStatsTipBuilder.BuildTip(cardNode.Model);
            Control panel = HoverStatsTooltipRenderer.CreateStandalonePanel(builtTip.Payload);
            panel.Name = StatsPanelName;
            panel.MouseFilter = Control.MouseFilterEnum.Ignore;
            panel.ZIndex = 20;
            dock.AddChild(panel);
        }

        PlaceDock(__instance, dock, cardNode);
    }

    private static VBoxContainer EnsureDock(NInspectCardScreen screen)
    {
        if (screen.GetNodeOrNull<VBoxContainer>(StatsDockName) is VBoxContainer existing)
        {
            return existing;
        }

        VBoxContainer dock = new()
        {
            Name = StatsDockName,
            MouseFilter = Control.MouseFilterEnum.Pass,
            ZIndex = 20
        };
        dock.AddThemeConstantOverride("separation", 8);
        screen.AddChild(dock);
        screen.MoveChild(dock, screen.GetChildCount() - 1);
        return dock;
    }

    private static Button EnsureToggleButton(NInspectCardScreen screen, VBoxContainer dock)
    {
        if (dock.GetNodeOrNull<Button>(ToggleButtonName) is Button existing)
        {
            return existing;
        }

        Button button = new()
        {
            Name = ToggleButtonName,
            MouseFilter = Control.MouseFilterEnum.Stop,
            FocusMode = Control.FocusModeEnum.None,
            SizeFlagsHorizontal = Control.SizeFlags.ShrinkCenter,
            Text = GetToggleText()
        };
        button.AddThemeFontSizeOverride("font_size", 13);
        button.AddThemeColorOverride("font_color", new Color(0.95f, 0.92f, 0.84f, 1.0f));
        button.AddThemeStyleboxOverride("normal", CreateButtonStyle(new Color(0.18f, 0.21f, 0.27f, 0.94f), new Color(0.44f, 0.52f, 0.66f, 0.78f)));
        button.AddThemeStyleboxOverride("hover", CreateButtonStyle(new Color(0.23f, 0.27f, 0.34f, 0.98f), new Color(0.62f, 0.72f, 0.86f, 0.95f)));
        button.AddThemeStyleboxOverride("pressed", CreateButtonStyle(new Color(0.14f, 0.17f, 0.22f, 1.0f), new Color(0.70f, 0.80f, 0.92f, 1.0f)));
        button.Pressed += () =>
        {
            _inspectStatsVisible = !_inspectStatsVisible;
            screen.CallDeferred(NInspectCardScreen.MethodName.UpdateCardDisplay);
        };
        dock.AddChild(button);
        return button;
    }

    private static void PlaceDock(NInspectCardScreen screen, VBoxContainer dock, NCard cardNode)
    {
        Control anchor = HoverTipRectField?.GetValue(screen) as Control ?? cardNode;
        Control? leftButton = LeftButtonField?.GetValue(screen) as Control;
        dock.ResetSize();
        Vector2 size = dock.GetCombinedMinimumSize();
        if (size.X > 0f && size.Y > 0f)
        {
            dock.Size = size;
        }

        Vector2 viewport = screen.GetViewportRect().Size;
        Vector2 anchorTopLeft = anchor.GlobalPosition;
        Vector2 anchorSize = anchor.Size * anchor.Scale;
        float preferredX = anchorTopLeft.X - dock.Size.X - 64f;
        if (leftButton != null)
        {
            preferredX = Math.Min(preferredX, leftButton.GlobalPosition.X - dock.Size.X - 28f);
        }

        float preferredY = anchorTopLeft.Y + 4f;
        preferredX = Math.Clamp(preferredX, 24f, Math.Max(24f, viewport.X - dock.Size.X - 24f));
        preferredY = Math.Clamp(preferredY, 24f, Math.Max(24f, viewport.Y - dock.Size.Y - 24f));
        dock.GlobalPosition = new Vector2(preferredX, preferredY);
    }

    private static void RemoveExistingDock(NInspectCardScreen screen)
    {
        foreach (Node child in screen.GetChildren())
        {
            if (child is not Control existing || !string.Equals(existing.Name, StatsDockName, StringComparison.Ordinal))
            {
                continue;
            }

            screen.RemoveChild(existing);
            existing.QueueFree();
        }
    }

    private static string GetToggleText()
    {
        return IsChineseLocale()
            ? (_inspectStatsVisible ? "隐藏数据" : "显示数据")
            : (_inspectStatsVisible ? "Hide Stats" : "Show Stats");
    }

    private static string GetToggleTooltip()
    {
        return IsChineseLocale()
            ? "切换卡牌统计面板"
            : "Toggle the card stats panel";
    }

    private static bool IsChineseLocale()
    {
        string locale = TranslationServer.GetLocale();
        return !string.IsNullOrWhiteSpace(locale)
            && locale.StartsWith("zh", StringComparison.OrdinalIgnoreCase);
    }

    private static StyleBoxFlat CreateButtonStyle(Color background, Color border)
    {
        StyleBoxFlat style = new()
        {
            BgColor = background,
            BorderColor = border
        };
        style.SetBorderWidthAll(1);
        style.SetCornerRadiusAll(9);
        style.ContentMarginLeft = 12;
        style.ContentMarginRight = 12;
        style.ContentMarginTop = 7;
        style.ContentMarginBottom = 7;
        return style;
    }
}
