using Godot;

namespace HeyboxCardStatsOverlay;

internal readonly record struct UiText(
    string WinRate,
    string PickRate,
    string SkipRate,
    string TimesPicked,
    string TimesWon,
    string TimesLost,
    string WinRateRank,
    string PickRateRank,
    string UpdatedAt,
    string CommunityNote,
    string MissingBody,
    string FallbackNote,
    string SampleNote);

internal static class UiTextProvider
{
    public static UiText Get(string labelLanguage)
    {
        string mode = (labelLanguage ?? "auto").Trim().ToLowerInvariant();
        if (mode == "zh")
        {
            return Zh;
        }

        if (mode == "en")
        {
            return En;
        }

        string locale = TranslationServer.GetLocale();
        if (!string.IsNullOrWhiteSpace(locale) && locale.StartsWith("zh", StringComparison.OrdinalIgnoreCase))
        {
            return Zh;
        }

        return En;
    }

    private static readonly UiText En = new(
        WinRate: "Win Rate",
        PickRate: "Pick Rate",
        SkipRate: "Skip Rate",
        TimesPicked: "Times Picked",
        TimesWon: "Wins",
        TimesLost: "Losses",
        WinRateRank: "Class Win",
        PickRateRank: "Class Pick",
        UpdatedAt: "Updated",
        CommunityNote: "Community data only. Use it as reference.",
        MissingBody: "No bundled stats found for this card.",
        FallbackNote: "Showing offline data.",
        SampleNote: "Showing bundled offline data."
    );

    private static readonly UiText Zh = new(
        WinRate: "胜率",
        PickRate: "抓取率",
        SkipRate: "略过率",
        TimesPicked: "抓取次数",
        TimesWon: "胜局数",
        TimesLost: "败局数",
        WinRateRank: "职业内胜率",
        PickRateRank: "职业内抓取",
        UpdatedAt: "更新时间",
        CommunityNote: "社区统计，仅供参考。",
        MissingBody: "当前内置数据里没有这张卡的统计。",
        FallbackNote: "当前显示离线数据。",
        SampleNote: "当前显示内置离线数据。"
    );
}
