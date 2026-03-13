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

    private static readonly Color LabelColor = new(0.92f, 0.90f, 0.84f, 1.0f);

    private static readonly Color MutedColor = new(0.68f, 0.72f, 0.80f, 1.0f);

    private static readonly Color DividerColor = new(1.0f, 1.0f, 1.0f, 0.08f);

    private static readonly Color TrackColor = new(0.21f, 0.23f, 0.29f, 0.95f);

    private static readonly Color KnobOutlineColor = new(0.05f, 0.06f, 0.08f, 0.45f);

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
            tipRoot.ResetSize();
            ResizeTextContainer(textContainer);
            return true;
        }

        return false;
    }

    private static Control BuildContent(HoverStatsTipPayload payload)
    {
        float contentWidth = GetContentWidth();
        VBoxContainer root = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
            CustomMinimumSize = new Vector2(contentWidth, 0f)
        };
        root.AddThemeConstantOverride("separation", 6);

        foreach (HoverStatsValueRow row in payload.ValueRows)
        {
            root.AddChild(BuildValueRow(row));
        }

        foreach (HoverStatsBarRow row in payload.BarRows)
        {
            root.AddChild(BuildBarRow(row));
        }

        if (payload.NoteRows.Count > 0)
        {
            if (payload.ValueRows.Count > 0 || payload.BarRows.Count > 0)
            {
                root.AddChild(BuildDivider());
            }

            foreach (HoverStatsNoteRow noteRow in payload.NoteRows)
            {
                root.AddChild(BuildNoteRow(noteRow, contentWidth));
            }
        }

        return root;
    }

    private static Control BuildValueRow(HoverStatsValueRow row)
    {
        HBoxContainer container = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill
        };
        container.AddThemeConstantOverride("separation", 8);

        Label label = CreateLabel(row.Label);
        label.SizeFlagsHorizontal = Control.SizeFlags.ExpandFill;

        Label value = CreateValueLabel(row.Value, GetAccentColorValue(row.AccentPercent));
        value.SizeFlagsHorizontal = Control.SizeFlags.ShrinkEnd;

        container.AddChild(label);
        container.AddChild(value);
        return container;
    }

    private static Control BuildBarRow(HoverStatsBarRow row)
    {
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
        return container;
    }

    private static Control BuildNoteRow(HoverStatsNoteRow noteRow, float width)
    {
        string color = noteRow.Tone switch
        {
            HoverStatsNoteTone.Warning => "#F2B15D",
            HoverStatsNoteTone.Info => "#8BC6FF",
            _ => "#AEB7C6"
        };

        return CreateNoteLabel(noteRow.Text, Color.FromHtml(color), width);
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
        return label;
    }

    private static Label CreateValueLabel(string text, Color color)
    {
        Label label = new()
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            AutowrapMode = TextServer.AutowrapMode.Off,
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center,
            Text = text,
            CustomMinimumSize = new Vector2(96f, 0f)
        };
        label.AddThemeColorOverride("font_color", color);
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
        return label;
    }

    private static void ResizeTextContainer(VFlowContainer textContainer)
    {
        float totalHeight = 0f;
        int visibleCount = 0;
        foreach (Node node in textContainer.GetChildren())
        {
            if (node is not Control control || !control.Visible)
            {
                continue;
            }

            control.ResetSize();
            totalHeight += Math.Max(control.Size.Y, control.GetCombinedMinimumSize().Y);
            visibleCount += 1;
        }

        float width = Math.Max(textContainer.Size.X, Math.Max(360f, ModEntry.Config.PanelWidth + 40f));
        float height = totalHeight + Math.Max(0, visibleCount - 1) * TipSpacing;
        textContainer.Size = new Vector2(width, height);
    }

    private static float GetContentWidth()
    {
        return Math.Clamp(ModEntry.Config.PanelWidth - 68f, 180f, 360f);
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
