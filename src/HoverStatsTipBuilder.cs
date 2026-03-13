using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using System.Threading;
using Godot;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization;
using MegaCrit.Sts2.Core.Models;

namespace HeyboxCardStatsOverlay;

internal static class HoverStatsTipBuilder
{
    private static readonly FieldInfo? TitleField = typeof(HoverTip).GetField("<Title>k__BackingField", BindingFlags.Instance | BindingFlags.NonPublic);

    private static readonly FieldInfo? DescriptionField = typeof(HoverTip).GetField("<Description>k__BackingField", BindingFlags.Instance | BindingFlags.NonPublic);

    private static readonly FieldInfo? IconField = typeof(HoverTip).GetField("<Icon>k__BackingField", BindingFlags.Instance | BindingFlags.NonPublic);

    private static readonly FieldInfo? CanonicalModelField = typeof(HoverTip).GetField("<CanonicalModel>k__BackingField", BindingFlags.Instance | BindingFlags.NonPublic);

    private static int _tipSequence;

    public static HoverStatsBuiltTip BuildTip(CardModel card)
    {
        UiText ui = UiTextProvider.Get(ModEntry.Config.LabelLanguage);
        CardStatsLookupResult lookup = ModEntry.Repository.Resolve(card.Id?.ToString() ?? string.Empty, card);
        string title = GetTitleText();
        string tipId = CreateTipId(lookup);
        HoverStatsTipPayload payload = lookup.HasCard
            ? BuildStatsPayload(ui, lookup, title, tipId)
            : BuildMissingPayload(ui, lookup, title, tipId);

        return new HoverStatsBuiltTip(
            CreatePlainHoverTip(payload.Title, payload.RichFallbackDescription, payload.TipId),
            payload);
    }

    private static string GetTitleText()
    {
        string locale = TranslationServer.GetLocale();
        return !string.IsNullOrWhiteSpace(locale) && locale.StartsWith("zh", StringComparison.OrdinalIgnoreCase)
            ? "\u5361\u724c\u6570\u636e"
            : "Card Data";
    }

    private static string CreateTipId(CardStatsLookupResult lookup)
    {
        string baseId = string.IsNullOrWhiteSpace(lookup.RequestedId) ? "unknown" : lookup.RequestedId;
        int sequence = Interlocked.Increment(ref _tipSequence);
        return $"heybox-card-data:{baseId}:{sequence}";
    }

    private static IHoverTip CreatePlainHoverTip(string title, string description, string id)
    {
        HoverTip tip = default;
        TitleField?.SetValueDirect(__makeref(tip), title);
        DescriptionField?.SetValueDirect(__makeref(tip), description);
        IconField?.SetValueDirect(__makeref(tip), default(Texture2D)!);
        CanonicalModelField?.SetValueDirect(__makeref(tip), default(AbstractModel)!);
        tip.Id = id;
        tip.IsSmart = false;
        tip.IsDebuff = false;
        tip.IsInstanced = false;
        tip.ShouldOverrideTextOverflow = false;
        return tip;
    }

    private static HoverStatsTipPayload BuildStatsPayload(UiText ui, CardStatsLookupResult lookup, string title, string tipId)
    {
        CardStatsValues? stats = lookup.Card!.Stats;
        if (stats == null)
        {
            return BuildMissingPayload(ui, lookup, title, tipId);
        }

        CategoryRelativeStats? relative = lookup.RelativeStats;
        List<HoverStatsValueRow> valueRows = new()
        {
            new HoverStatsValueRow(ui.WinRate, Percent(stats.WinRate), relative?.WinRatePercent),
            new HoverStatsValueRow(ui.PickRate, Percent(stats.PickRate), relative?.PickRatePercent)
        };

        if (ModEntry.Config.ShowSkipRate)
        {
            valueRows.Add(new HoverStatsValueRow(ui.SkipRate, Percent(stats.SkipRate), null));
        }

        if (ModEntry.Config.ShowCounts)
        {
            valueRows.Add(new HoverStatsValueRow(ui.TimesPicked, Count(stats.TimesPicked), null));
            valueRows.Add(new HoverStatsValueRow(ui.TimesWon, Count(stats.TimesWon), null));
            valueRows.Add(new HoverStatsValueRow(ui.TimesLost, Count(stats.TimesLost), null));
        }

        List<HoverStatsBarRow> barRows = new();
        if (ModEntry.Config.ShowRanks)
        {
            AddBarRow(barRows, ui.WinRateRank, relative?.WinRatePercent, relative?.WinRateRank, relative?.WinRateCount);
            AddBarRow(barRows, ui.PickRateRank, relative?.PickRatePercent, relative?.PickRateRank, relative?.PickRateCount);
        }

        string updated = lookup.Snapshot?.UpdatedAt?.ToLocalTime().ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture)
            ?? lookup.Snapshot?.FileWriteTimeUtc.ToLocalTime().ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture)
            ?? string.Empty;
        if (!string.IsNullOrWhiteSpace(updated))
        {
            valueRows.Add(new HoverStatsValueRow(ui.UpdatedAt, updated, null));
        }

        List<HoverStatsNoteRow> noteRows = new();
        if (lookup.Snapshot?.CacheKind == "fallback")
        {
            noteRows.Add(new HoverStatsNoteRow(ui.FallbackNote, HoverStatsNoteTone.Warning));
        }
        else if (lookup.Snapshot?.CacheKind == "sample")
        {
            noteRows.Add(new HoverStatsNoteRow(ui.SampleNote, HoverStatsNoteTone.Info));
        }

        noteRows.Add(new HoverStatsNoteRow(ui.CommunityNote, HoverStatsNoteTone.Muted));
        return CreatePayload(tipId, title, valueRows, barRows, noteRows);
    }

    private static HoverStatsTipPayload BuildMissingPayload(UiText ui, CardStatsLookupResult lookup, string title, string tipId)
    {
        List<HoverStatsValueRow> valueRows = new();
        List<HoverStatsBarRow> barRows = new();
        List<HoverStatsNoteRow> noteRows = new()
        {
            new HoverStatsNoteRow(ui.MissingBody, HoverStatsNoteTone.Warning)
        };

        if (lookup.Snapshot?.CacheKind == "fallback")
        {
            noteRows.Add(new HoverStatsNoteRow(ui.FallbackNote, HoverStatsNoteTone.Warning));
        }
        else if (lookup.Snapshot?.CacheKind == "sample")
        {
            noteRows.Add(new HoverStatsNoteRow(ui.SampleNote, HoverStatsNoteTone.Info));
        }

        return CreatePayload(tipId, title, valueRows, barRows, noteRows);
    }

    private static HoverStatsTipPayload CreatePayload(
        string tipId,
        string title,
        List<HoverStatsValueRow> valueRows,
        List<HoverStatsBarRow> barRows,
        List<HoverStatsNoteRow> noteRows)
    {
        string richFallbackDescription = BuildFallbackDescription(valueRows, barRows, noteRows, richText: true);
        string plainFallbackDescription = BuildFallbackDescription(valueRows, barRows, noteRows, richText: false);
        return new HoverStatsTipPayload(
            tipId,
            title,
            richFallbackDescription,
            plainFallbackDescription,
            valueRows,
            barRows,
            noteRows);
    }

    private static string BuildFallbackDescription(
        IEnumerable<HoverStatsValueRow> valueRows,
        IEnumerable<HoverStatsBarRow> barRows,
        IEnumerable<HoverStatsNoteRow> noteRows,
        bool richText)
    {
        List<string> lines = new();
        lines.AddRange(valueRows.Select(row => richText ? FormatRichValueRow(row) : FormatPlainValueRow(row)));
        lines.AddRange(barRows.Select(row => richText ? FormatRichBarRow(row) : FormatPlainBarRow(row)));
        lines.AddRange(noteRows.Select(row => richText ? FormatRichNoteRow(row) : row.Text));
        return string.Join("\n", lines.Where(static line => !string.IsNullOrWhiteSpace(line)));
    }

    private static void AddBarRow(List<HoverStatsBarRow> barRows, string label, double? percent, int? rank, int? count)
    {
        if (!percent.HasValue || !rank.HasValue || !count.HasValue || count.Value <= 0)
        {
            return;
        }

        string detail = $"{percent.Value:0}% (#{rank.Value}/{count.Value})";
        barRows.Add(new HoverStatsBarRow(label, percent.Value, detail));
    }

    private static string FormatPlainValueRow(HoverStatsValueRow row)
    {
        return $"{row.Label}: {row.Value}";
    }

    private static string FormatRichValueRow(HoverStatsValueRow row)
    {
        return $"{EscapeBbCode(row.Label)}: {Colorize(row.Value, row.AccentPercent)}";
    }

    private static string FormatPlainBarRow(HoverStatsBarRow row)
    {
        return $"{row.Label}: {row.Detail}";
    }

    private static string FormatRichBarRow(HoverStatsBarRow row)
    {
        return $"{EscapeBbCode(row.Label)}: {Colorize(row.Detail, row.Percent)}";
    }

    private static string FormatRichNoteRow(HoverStatsNoteRow row)
    {
        return WrapColor(EscapeBbCode(row.Text), GetNoteColor(row.Tone));
    }

    private static string Colorize(string text, double? percent)
    {
        return WrapColor(EscapeBbCode(text), GetAccentColor(percent));
    }

    private static string WrapColor(string text, string color)
    {
        return $"[color={color}]{text}[/color]";
    }

    private static string EscapeBbCode(string text)
    {
        return text
            .Replace("[", "[lb]", StringComparison.Ordinal)
            .Replace("]", "[rb]", StringComparison.Ordinal);
    }

    private static string Percent(double? value)
    {
        return value.HasValue ? $"{value.Value:0.0}%" : "--";
    }

    private static string Count(int? value)
    {
        return value.HasValue ? value.Value.ToString("N0", CultureInfo.InvariantCulture) : "--";
    }

    private static string GetAccentColor(double? percent)
    {
        if (!percent.HasValue)
        {
            return "#F3EAD1";
        }

        if (percent.Value >= 75.0)
        {
            return "#86E17B";
        }

        if (percent.Value >= 50.0)
        {
            return "#F3D46C";
        }

        if (percent.Value >= 25.0)
        {
            return "#F2A85B";
        }

        return "#EE7A74";
    }

    private static string GetNoteColor(HoverStatsNoteTone tone)
    {
        return tone switch
        {
            HoverStatsNoteTone.Warning => "#F2B15D",
            HoverStatsNoteTone.Info => "#8BC6FF",
            _ => "#AEB7C6"
        };
    }
}

internal readonly record struct HoverStatsBuiltTip(IHoverTip Tip, HoverStatsTipPayload Payload);

internal sealed record HoverStatsTipPayload(
    string TipId,
    string Title,
    string RichFallbackDescription,
    string PlainFallbackDescription,
    IReadOnlyList<HoverStatsValueRow> ValueRows,
    IReadOnlyList<HoverStatsBarRow> BarRows,
    IReadOnlyList<HoverStatsNoteRow> NoteRows);

internal sealed record HoverStatsValueRow(string Label, string Value, double? AccentPercent);

internal sealed record HoverStatsBarRow(string Label, double Percent, string Detail);

internal sealed record HoverStatsNoteRow(string Text, HoverStatsNoteTone Tone);

internal enum HoverStatsNoteTone
{
    Muted,
    Warning,
    Info
}
