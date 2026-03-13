using System.Text.Json.Serialization;

namespace HeyboxCardStatsOverlay;

internal sealed class CardStatsFile
{
    [JsonPropertyName("source")]
    public string? Source { get; set; }

    [JsonPropertyName("game")]
    public string? Game { get; set; }

    [JsonPropertyName("updated_at")]
    public string? UpdatedAt { get; set; }

    [JsonPropertyName("categories")]
    public List<string>? Categories { get; set; }

    [JsonPropertyName("cards")]
    public List<CardStatsCard>? Cards { get; set; }
}

internal sealed class CardStatsCard
{
    [JsonPropertyName("id")]
    public string? Id { get; set; }

    [JsonPropertyName("alt_ids")]
    public List<string>? AltIds { get; set; }

    [JsonPropertyName("name_cn")]
    public string? NameCn { get; set; }

    [JsonPropertyName("name_en")]
    public string? NameEn { get; set; }

    [JsonPropertyName("category")]
    public string? Category { get; set; }

    [JsonPropertyName("type")]
    public string? Type { get; set; }

    [JsonPropertyName("rarity")]
    public string? Rarity { get; set; }

    [JsonPropertyName("cost")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public int? Cost { get; set; }

    [JsonPropertyName("icon_url")]
    public string? IconUrl { get; set; }

    [JsonPropertyName("desc")]
    public string? Desc { get; set; }

    [JsonPropertyName("upgrade_desc")]
    public string? UpgradeDesc { get; set; }

    [JsonPropertyName("updated_at")]
    public string? UpdatedAt { get; set; }

    [JsonPropertyName("stats")]
    public CardStatsValues? Stats { get; set; }
}

internal sealed class CardStatsValues
{
    [JsonPropertyName("win_rate")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public double? WinRate { get; set; }

    [JsonPropertyName("pick_rate")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public double? PickRate { get; set; }

    [JsonPropertyName("skip_rate")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public double? SkipRate { get; set; }

    [JsonPropertyName("times_won")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public int? TimesWon { get; set; }

    [JsonPropertyName("times_lost")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public int? TimesLost { get; set; }

    [JsonPropertyName("times_picked")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public int? TimesPicked { get; set; }

    [JsonPropertyName("times_skipped")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public int? TimesSkipped { get; set; }

    [JsonPropertyName("win_rate_rank")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public int? WinRateRank { get; set; }

    [JsonPropertyName("pick_rate_rank")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public int? PickRateRank { get; set; }
}

internal sealed class CardStatsSnapshot
{
    public required string Source { get; init; }

    public required string Path { get; init; }

    public required string CacheKind { get; init; }

    public required DateTime FileWriteTimeUtc { get; init; }

    public required DateTimeOffset? UpdatedAt { get; init; }

    public required Dictionary<string, CardStatsCard> ById { get; init; }

    public required Dictionary<string, CategoryRelativeStats> RelativeStatsById { get; init; }
}

internal readonly record struct CardStatsLookupResult(
    CardStatsSnapshot? Snapshot,
    CardStatsCard? Card,
    string RequestedId,
    CategoryRelativeStats? RelativeStats)
{
    public bool HasSnapshot => Snapshot != null;

    public bool HasCard => Card != null;
}

internal sealed class CategoryRelativeStats
{
    public double? WinRatePercent { get; set; }

    public int? WinRateRank { get; set; }

    public int? WinRateCount { get; set; }

    public double? PickRatePercent { get; set; }

    public int? PickRateRank { get; set; }

    public int? PickRateCount { get; set; }
}
