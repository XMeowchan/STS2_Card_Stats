using System.Linq;
using Godot;
using MegaCrit.Sts2.Core.Nodes.HoverTips;
using MegaCrit.Sts2.addons.mega_text;

namespace HeyboxCardStatsOverlay;

internal static class HoverStatsTooltipRenderer
{
    private const string TextContainerName = "textHoverTipContainer";

    private const string DescriptionPath = "%Description";

    private const string CustomContentName = "HeyboxStatsContent";

    private const float TipSpacing = 5f;

    private const int ContentFontSize = 14;

    private static readonly Color LabelColor = new(0.92f, 0.90f, 0.84f, 1.0f);

    private static readonly Color MutedColor = new(0.68f, 0.72f, 0.80f, 1.0f);

    private static readonly Color DividerColor = new(1.0f, 1.0f, 1.0f, 0.08f);

    private static readonly Color TrackColor = new(0.21f, 0.23f, 0.29f, 0.95f);

    private static readonly Color KnobOutlineColor = new(0.05f, 0.06f, 0.08f, 0.45f);

    private static readonly Color HeroCardBackground = new(0.14f, 0.16f, 0.20f, 0.96f);

    private static readonly Color StandardCardBackground = new(0.11f, 0.13f, 0.17f, 0.92f);

    private static readonly Color NoteCardBackground = new(0.11f, 0.13f, 0.17f, 0.70f);

    private static readonly Color HeroLabelColor = new(0.78f, 0.82f, 0.90f, 1.0f);

    public static bool TryApply(NHoverTipSet hoverTipSet, HoverStatsTipPayload payload)
    {
        if (hoverTipSet.GetNodeOrNull<VFlowContainer>(TextContainerName) is not VFlowContainer textContainer)
        {
            return false;
        }

        foreach (Node node in textContainer.GetChildren())
        {
            if (node is not Control tipRoot)
            {
                continue;
            }

            MegaRichTextLabel? description = tipRoot.GetNodeOrNull<MegaRichTextLabel>(DescriptionPath);
            if (description == null || !MatchesDescription(description.Text, payload))
            {
                continue;
            }

            Control host = description.GetParentOrNull<Control>() ?? tipRoot;
            if (host.GetNodeOrNull<Control>(CustomContentName) != null)
            {
                return true;
            }

            Control content = BuildContent(payload);
            content.Name = CustomContentName;
            host.AddChild(content);
            host.MoveChild(content, description.GetIndex());
            description.Visible = false;

            if (host is Container hostContainer)
            {
                hostContainer.QueueSort();
            }

            textContainer.QueueSort();
            RefreshTextContainerSize(textContainer);
            return true;
        }

        return false;
    }

    private static Control BuildContent(HoverStatsTipPayload payload)
    {
        float contentWidth = GetContentWidth();
        List<HoverStatsValueRow> heroRows = payload.ValueRows
            .Where(static row => row.Style == HoverStatsValueStyle.Hero)
            .ToList();
        List<HoverStatsValueRow> standardRows = payload.ValueRows
            .Where(static row => row.Style == HoverStatsValueStyle.Standard)
            .ToList();
        List<HoverStatsValueRow> metaRows = payload.ValueRows
            .Where(static row => row.Style == HoverStatsValueStyle.Meta)
            .ToList();

        VBoxContainer root = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
            CustomMinimumSize = new Vector2(contentWidth, 0f)
        };
        root.AddThemeConstantOverride("separation", 8);

        bool hasSection = false;
        if (heroRows.Count > 0)
        {
            root.AddChild(BuildValueGrid(heroRows, contentWidth, emphasize: true));
            hasSection = true;
        }

        if (standardRows.Count > 0)
        {
            AddDividerIfNeeded(root, ref hasSection);
            root.AddChild(BuildValueGrid(standardRows, contentWidth, emphasize: false));
        }

        if (payload.BarRows.Count > 0)
        {
            AddDividerIfNeeded(root, ref hasSection);
            foreach (HoverStatsBarRow row in payload.BarRows)
            {
                root.AddChild(BuildBarRow(row));
            }
        }

        if (metaRows.Count > 0)
        {
            AddDividerIfNeeded(root, ref hasSection);
            foreach (HoverStatsValueRow row in metaRows)
            {
                root.AddChild(BuildMetaRow(row));
            }
        }

        if (payload.NoteRows.Count > 0)
        {
            AddDividerIfNeeded(root, ref hasSection);
            foreach (HoverStatsNoteRow noteRow in payload.NoteRows)
            {
                root.AddChild(BuildNoteRow(noteRow, contentWidth));
            }
        }

        return root;
    }

    private static void AddDividerIfNeeded(VBoxContainer root, ref bool hasSection)
    {
        if (!hasSection)
        {
            hasSection = true;
            return;
        }

        root.AddChild(BuildDivider());
    }

    private static Control BuildValueGrid(IReadOnlyList<HoverStatsValueRow> rows, float width, bool emphasize)
    {
        GridContainer grid = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
            CustomMinimumSize = new Vector2(width, 0f),
            Columns = rows.Count <= 1 ? 1 : 2
        };
        grid.AddThemeConstantOverride("h_separation", emphasize ? 8 : 6);
        grid.AddThemeConstantOverride("v_separation", emphasize ? 8 : 6);

        foreach (HoverStatsValueRow row in rows)
        {
            grid.AddChild(BuildValueCard(row, emphasize));
        }

        return grid;
    }

    private static Control BuildValueCard(HoverStatsValueRow row, bool emphasize)
    {
        Color accentColor = GetAccentColorValue(row.AccentPercent);
        PanelContainer card = CreatePanel(emphasize ? HeroCardBackground : StandardCardBackground, accentColor, emphasize ? 0.60f : 0.32f, emphasize ? 10 : 8);
        card.SizeFlagsHorizontal = Control.SizeFlags.ExpandFill;

        MarginContainer body = CreateMargin(emphasize ? 10 : 8, emphasize ? 9 : 7);

        VBoxContainer stack = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill
        };
        stack.AddThemeConstantOverride("separation", emphasize ? 4 : 3);

        Label label = CreateCaptionLabel(row.Label, emphasize ? HeroLabelColor : MutedColor);
        Control value = CreateRichValue(row.Value, accentColor, alignRight: !emphasize, bold: row.Style == HoverStatsValueStyle.Hero);

        stack.AddChild(label);
        stack.AddChild(value);
        body.AddChild(stack);
        card.AddChild(body);
        return card;
    }

    private static Control BuildBarRow(HoverStatsBarRow row)
    {
        PanelContainer panel = CreatePanel(StandardCardBackground, GetAccentColorValue(row.Percent), 0.28f, 8);
        MarginContainer body = CreateMargin(8, 8);

        VBoxContainer container = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill
        };
        container.AddThemeConstantOverride("separation", 4);

        HBoxContainer header = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill
        };
        header.AddThemeConstantOverride("separation", 8);

        Label label = CreateLabel(row.Label);
        label.SizeFlagsHorizontal = Control.SizeFlags.ExpandFill;

        Label detail = CreateValueLabel(row.Detail, GetAccentColorValue(row.Percent));
        detail.SizeFlagsHorizontal = Control.SizeFlags.ShrinkEnd;

        HoverStatsSliderBar bar = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill
        };
        bar.SetPercent(row.Percent, GetAccentColorValue(row.Percent), TrackColor);

        header.AddChild(label);
        header.AddChild(detail);
        container.AddChild(header);
        container.AddChild(bar);
        body.AddChild(container);
        panel.AddChild(body);
        return panel;
    }

    private static Control BuildMetaRow(HoverStatsValueRow row)
    {
        HBoxContainer container = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill
        };
        container.AddThemeConstantOverride("separation", 8);

        Label label = CreateCaptionLabel(row.Label, MutedColor);
        label.SizeFlagsHorizontal = Control.SizeFlags.ExpandFill;

        Label value = CreateValueLabel(row.Value, MutedColor, minimumWidth: 0f);
        value.SizeFlagsHorizontal = Control.SizeFlags.ShrinkEnd;

        container.AddChild(label);
        container.AddChild(value);
        return container;
    }

    private static Control BuildNoteRow(HoverStatsNoteRow noteRow, float width)
    {
        Color color = noteRow.Tone switch
        {
            HoverStatsNoteTone.Warning => Color.FromHtml("#F2B15D"),
            HoverStatsNoteTone.Info => Color.FromHtml("#8BC6FF"),
            _ => Color.FromHtml("#AEB7C6")
        };

        PanelContainer panel = CreatePanel(NoteCardBackground, color, 0.24f, 8);
        panel.CustomMinimumSize = new Vector2(width, 0f);

        MarginContainer body = CreateMargin(8, 8);
        body.AddChild(CreateNoteLabel(noteRow.Text, color, width));
        panel.AddChild(body);
        return panel;
    }

    private static Control BuildDivider()
    {
        ColorRect divider = new()
        {
            Color = DividerColor,
            MouseFilter = Control.MouseFilterEnum.Ignore,
            CustomMinimumSize = new Vector2(0f, 1f),
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill
        };
        return divider;
    }

    private static Label CreateLabel(string text)
    {
        Label label = new()
        {
            Text = text,
            MouseFilter = Control.MouseFilterEnum.Ignore,
            AutowrapMode = TextServer.AutowrapMode.WordSmart,
            VerticalAlignment = VerticalAlignment.Center
        };
        label.AddThemeColorOverride("font_color", LabelColor);
        label.AddThemeFontSizeOverride("font_size", ContentFontSize);
        return label;
    }

    private static Label CreateValueLabel(string text, Color color, float minimumWidth = 96f)
    {
        Label label = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            AutowrapMode = TextServer.AutowrapMode.Off,
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center,
            Text = text,
            CustomMinimumSize = new Vector2(minimumWidth, 0f)
        };
        label.AddThemeColorOverride("font_color", color);
        label.AddThemeFontSizeOverride("font_size", ContentFontSize);
        return label;
    }

    private static Label CreateCaptionLabel(string text, Color color)
    {
        Label label = new()
        {
            Text = text,
            MouseFilter = Control.MouseFilterEnum.Ignore,
            AutowrapMode = TextServer.AutowrapMode.WordSmart,
            VerticalAlignment = VerticalAlignment.Center
        };
        label.AddThemeColorOverride("font_color", color);
        label.AddThemeFontSizeOverride("font_size", ContentFontSize);
        return label;
    }

    private static Label CreateNoteLabel(string text, Color color, float width)
    {
        Label label = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            AutowrapMode = TextServer.AutowrapMode.WordSmart,
            HorizontalAlignment = HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Center,
            Text = text,
            CustomMinimumSize = new Vector2(width, 0f),
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill
        };
        label.AddThemeColorOverride("font_color", color);
        label.AddThemeFontSizeOverride("font_size", ContentFontSize);
        return label;
    }

    private static Control CreateRichValue(string text, Color color, bool alignRight, bool bold)
    {
        string escapedText = EscapeBbCode(text);
        RichTextLabel label = new()
        {
            BbcodeEnabled = true,
            FitContent = true,
            ScrollActive = false,
            MouseFilter = Control.MouseFilterEnum.Ignore,
            AutowrapMode = TextServer.AutowrapMode.Off,
            Text = bold ? $"[b]{escapedText}[/b]" : escapedText,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill
        };
        label.AddThemeColorOverride("default_color", color);
        label.AddThemeFontSizeOverride("normal_font_size", ContentFontSize);
        label.HorizontalAlignment = alignRight ? HorizontalAlignment.Right : HorizontalAlignment.Left;
        return label;
    }

    private static PanelContainer CreatePanel(Color background, Color accentColor, float borderAlpha, int radius)
    {
        StyleBoxFlat style = new()
        {
            BgColor = background,
            BorderColor = new Color(accentColor.R, accentColor.G, accentColor.B, borderAlpha)
        };
        style.SetBorderWidthAll(1);
        style.SetCornerRadiusAll(radius);

        PanelContainer panel = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore
        };
        panel.AddThemeStyleboxOverride("panel", style);
        return panel;
    }

    private static MarginContainer CreateMargin(int horizontal, int vertical)
    {
        MarginContainer container = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill
        };
        container.AddThemeConstantOverride("margin_left", horizontal);
        container.AddThemeConstantOverride("margin_right", horizontal);
        container.AddThemeConstantOverride("margin_top", vertical);
        container.AddThemeConstantOverride("margin_bottom", vertical);
        return container;
    }

    private static float GetContentWidth()
    {
        return Math.Clamp(ModEntry.Config.PanelWidth - 24f, 220f, 360f);
    }

    private static void RefreshTextContainerSize(VFlowContainer textContainer)
    {
        textContainer.ResetSize();

        Vector2 minSize = textContainer.GetCombinedMinimumSize();
        if (minSize.X <= 0f || minSize.Y <= 0f)
        {
            return;
        }

        textContainer.Size = minSize;
    }

    private static bool MatchesDescription(string actualText, HoverStatsTipPayload payload)
    {
        string normalizedActual = Normalize(actualText);
        string normalizedRich = Normalize(payload.RichFallbackDescription);
        string normalizedPlain = Normalize(payload.PlainFallbackDescription);
        if (normalizedActual == normalizedRich || normalizedActual == normalizedPlain)
        {
            return true;
        }

        string plainFirstLine = GetFirstLine(normalizedPlain);
        return !string.IsNullOrWhiteSpace(plainFirstLine)
            && normalizedActual.Contains(plainFirstLine, StringComparison.Ordinal);
    }

    private static string GetFirstLine(string text)
    {
        int index = text.IndexOf('\n');
        return index >= 0 ? text[..index] : text;
    }

    private static string Normalize(string text)
    {
        return (text ?? string.Empty).Replace("\r\n", "\n", StringComparison.Ordinal).Trim();
    }

    private static string EscapeBbCode(string text)
    {
        return (text ?? string.Empty)
            .Replace("[", "[lb]", StringComparison.Ordinal)
            .Replace("]", "[rb]", StringComparison.Ordinal);
    }

    private static Color GetAccentColorValue(double? percent)
    {
        return percent switch
        {
            >= 75.0 => new Color(0.53f, 0.88f, 0.48f, 1.0f),
            >= 50.0 => new Color(0.95f, 0.83f, 0.42f, 1.0f),
            >= 25.0 => new Color(0.95f, 0.66f, 0.36f, 1.0f),
            >= 0.0 => new Color(0.93f, 0.48f, 0.45f, 1.0f),
            _ => new Color(0.95f, 0.92f, 0.82f, 1.0f)
        };
    }

    private sealed class HoverStatsSliderBar : Control
    {
        private double _percent;

        private Color _fillColor = new(0.53f, 0.88f, 0.48f, 1.0f);

        private Color _trackColor = TrackColor;

        public HoverStatsSliderBar()
        {
            CustomMinimumSize = new Vector2(0f, 16f);
        }

        public void SetPercent(double percent, Color fillColor, Color trackColor)
        {
            _percent = Math.Clamp(percent, 0.0, 100.0);
            _fillColor = fillColor;
            _trackColor = trackColor;
            QueueRedraw();
        }

        public override void _Draw()
        {
            float width = Math.Max(Size.X, 1f);
            float height = Math.Max(Size.Y, 16f);
            float knobRadius = 4f;
            float trackHeight = 6f;
            float trackLeft = knobRadius;
            float trackWidth = Math.Max(1f, width - knobRadius * 2f);
            float y = (height - trackHeight) * 0.5f;
            float fillWidth = trackWidth * (float)(_percent / 100.0);
            Vector2 knobCenter = new(trackLeft + fillWidth, height * 0.5f);

            DrawRect(new Rect2(trackLeft, y, trackWidth, trackHeight), _trackColor, true);
            if (fillWidth > 0f)
            {
                DrawRect(new Rect2(trackLeft, y, fillWidth, trackHeight), _fillColor, true);
            }

            DrawCircle(knobCenter, knobRadius + 1f, KnobOutlineColor);
            DrawCircle(knobCenter, knobRadius, _fillColor);
        }
    }
}
