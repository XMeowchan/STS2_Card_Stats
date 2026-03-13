param(
    [string]$OutputDir,
    [string]$StatsUrl = $(if ([string]::IsNullOrWhiteSpace($env:TELEMETRY_STATS_URL)) { "https://sts2-card-stats-telemetry.xmeowchan0415.workers.dev/v1/stats.json?days=365" } else { $env:TELEMETRY_STATS_URL })
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    throw "OutputDir is required."
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$usageJsonPath = Join-Path $OutputDir "usage-stats.json"
$usageSvgPath = Join-Path $OutputDir "users-history.svg"

function Get-IntOrZero {
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return 0
    }

    return [int]$Value
}

function Convert-ToUsageRows {
    param([object[]]$Rows)

    if (-not $Rows -or $Rows.Count -eq 0) {
        return @()
    }

    $normalized = $Rows |
        ForEach-Object {
            [pscustomobject]@{
                day = [string]$_.day
                new_users = Get-IntOrZero -Value $_.new_users
                active_users = Get-IntOrZero -Value $_.active_users
                cumulative_users = Get-IntOrZero -Value $_.cumulative_users
            }
        } |
        Sort-Object day

    $byDay = @{}
    foreach ($row in $normalized) {
        $byDay[$row.day] = $row
    }

    $start = [DateTime]::SpecifyKind(
        [DateTime]::ParseExact($normalized[0].day, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture),
        [DateTimeKind]::Utc)
    $end = [DateTime]::SpecifyKind(
        [DateTime]::ParseExact($normalized[-1].day, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture),
        [DateTimeKind]::Utc)

    $filled = New-Object System.Collections.Generic.List[object]
    $cumulativeUsers = 0
    for ($cursor = $start; $cursor -le $end; $cursor = $cursor.AddDays(1)) {
        $day = $cursor.ToString("yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
        if ($byDay.ContainsKey($day)) {
            $row = $byDay[$day]
            $cumulativeUsers = [int]$row.cumulative_users
            $filled.Add($row)
            continue
        }

        $filled.Add([pscustomobject]@{
            day = $day
            new_users = 0
            active_users = 0
            cumulative_users = $cumulativeUsers
        })
    }

    return $filled.ToArray()
}

function Get-NiceUpperBound {
    param([int]$Value)

    if ($Value -le 10) {
        return 10
    }

    $magnitude = [math]::Pow(10, [math]::Floor([math]::Log10($Value)))
    foreach ($factor in @(1, 2, 5, 10)) {
        $candidate = [int]($magnitude * $factor)
        if ($candidate -ge $Value) {
            return $candidate
        }
    }

    return $Value
}

function Format-Number {
    param([int]$Value)

    return $Value.ToString("N0", [System.Globalization.CultureInfo]::InvariantCulture)
}

function New-PlaceholderUsageChartSvg {
    param([string]$StatusText)

    $safeStatus = if ([string]::IsNullOrWhiteSpace($StatusText)) { "Telemetry not configured yet." } else { $StatusText }
    $lines = @(
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1200 420' role='img' aria-labelledby='title desc'>",
        "  <title id='title'>STS2 Mod User Curve</title>",
        "  <desc id='desc'>Placeholder chart while telemetry is unavailable.</desc>",
        "  <defs>",
        "    <linearGradient id='bg' x1='0%' y1='0%' x2='100%' y2='100%'>",
        "      <stop offset='0%' stop-color='#fffaf0'/>",
        "      <stop offset='100%' stop-color='#efe3c5'/>",
        "    </linearGradient>",
        "  </defs>",
        "  <style>",
        "    .font { font-family: 'Segoe UI', 'Microsoft YaHei UI', sans-serif; }",
        "    .eyebrow { font-size: 16px; font-weight: 700; fill: #9a6b17; letter-spacing: 0.08em; text-transform: uppercase; }",
        "    .title { font-size: 36px; font-weight: 700; fill: #1f252b; }",
        "    .body { font-size: 18px; fill: #5a6570; }",
        "  </style>",
        "  <rect width='1200' height='420' rx='28' fill='url(#bg)'/>",
        "  <rect x='28' y='28' width='1144' height='364' rx='24' fill='#fffdf8' stroke='#e2d6b7'/>",
        "  <text x='60' y='80' class='font eyebrow'>Anonymous telemetry</text>",
        "  <text x='60' y='128' class='font title'>STS2 Mod User Curve</text>",
        "  <text x='60' y='172' class='font body'>This chart will appear after the telemetry worker is deployed.</text>",
        "  <text x='60' y='206' class='font body'>$safeStatus</text>",
        "  <text x='60' y='338' class='font body'>README uses this file directly, so you can keep the image path stable.</text>",
        "</svg>"
    )

    return [string]::Join("`n", $lines)
}

function New-UsageChartSvg {
    param([object[]]$Rows, [string]$GeneratedAt)

    if (-not $Rows -or $Rows.Count -eq 0) {
        return New-PlaceholderUsageChartSvg -StatusText "No telemetry data received yet."
    }

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $width = 1200
    $height = 420
    $plotLeft = 72.0
    $plotTop = 164.0
    $plotWidth = 1088.0
    $plotHeight = 192.0
    $rowCount = [double][math]::Max(1, $Rows.Count - 1)
    $maxUsers = Get-NiceUpperBound -Value ([int](($Rows | Measure-Object -Property cumulative_users -Maximum).Maximum))
    $yTicks = 4
    $yLabels = @()
    for ($tick = 0; $tick -le $yTicks; $tick += 1) {
        $value = [int]([math]::Round($maxUsers * ($yTicks - $tick) / $yTicks))
        $y = $plotTop + ($plotHeight * $tick / $yTicks)
        $yLabels += [pscustomobject]@{
            value = $value
            y = $y
        }
    }

    $points = New-Object System.Collections.Generic.List[string]
    $areaPoints = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt $Rows.Count; $index += 1) {
        $row = $Rows[$index]
        $x = $plotLeft + ($plotWidth * $index / $rowCount)
        $ratio = if ($maxUsers -le 0) { 0.0 } else { [double]$row.cumulative_users / [double]$maxUsers }
        $y = $plotTop + $plotHeight - ($plotHeight * $ratio)
        $point = ("{0:F2},{1:F2}" -f $x, $y)
        $points.Add($point)
        $areaPoints.Add($point)
    }

    $baselineY = $plotTop + $plotHeight
    $areaPath = "M $($points[0]) L $([string]::Join(' L ', $areaPoints)) L {0:F2},{1:F2} L {2:F2},{3:F2} Z" -f (
        $plotLeft + $plotWidth
    ), $baselineY, $plotLeft, $baselineY
    $linePath = "M $($points[0]) L $([string]::Join(' L ', $points))"

    $latest = $Rows[-1]
    $first = $Rows[0]
    $latestDayText = $latest.day
    $generatedAtText = if ([string]::IsNullOrWhiteSpace($GeneratedAt)) {
        [DateTimeOffset]::UtcNow.ToString("yyyy-MM-dd HH:mm 'UTC'", $culture)
    } else {
        try {
            ([DateTimeOffset]::Parse($GeneratedAt, $culture)).ToUniversalTime().ToString("yyyy-MM-dd HH:mm 'UTC'", $culture)
        }
        catch {
            $GeneratedAt
        }
    }

    $xLabelIndexes = @(0)
    foreach ($fraction in @(0.25, 0.5, 0.75, 1.0)) {
        $candidate = [int][math]::Round(($Rows.Count - 1) * $fraction)
        if (-not $xLabelIndexes.Contains($candidate)) {
            $xLabelIndexes += $candidate
        }
    }
    $xLabelIndexes = $xLabelIndexes | Sort-Object

    $lines = @(
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 $width $height' role='img' aria-labelledby='title desc'>",
        "  <title id='title'>STS2 Mod User Curve</title>",
        "  <desc id='desc'>Cumulative anonymous mod users by day.</desc>",
        "  <defs>",
        "    <linearGradient id='bg' x1='0%' y1='0%' x2='100%' y2='100%'>",
        "      <stop offset='0%' stop-color='#fffaf0'/>",
        "      <stop offset='100%' stop-color='#efe3c5'/>",
        "    </linearGradient>",
        "    <linearGradient id='fill' x1='0%' y1='0%' x2='0%' y2='100%'>",
        "      <stop offset='0%' stop-color='#e0b85f' stop-opacity='0.46'/>",
        "      <stop offset='100%' stop-color='#e0b85f' stop-opacity='0.04'/>",
        "    </linearGradient>",
        "  </defs>",
        "  <style>",
        "    .font { font-family: 'Segoe UI', 'Microsoft YaHei UI', sans-serif; }",
        "    .eyebrow { font-size: 16px; font-weight: 700; fill: #9a6b17; letter-spacing: 0.08em; text-transform: uppercase; }",
        "    .title { font-size: 36px; font-weight: 700; fill: #1f252b; }",
        "    .body { font-size: 16px; fill: #5a6570; }",
        "    .metricLabel { font-size: 14px; fill: #6c7780; }",
        "    .metricValue { font-size: 28px; font-weight: 700; fill: #1f252b; }",
        "    .axis { font-size: 12px; fill: #6c7780; }",
        "    .grid { stroke: #eadfc6; stroke-width: 1; }",
        "  </style>",
        "  <rect width='$width' height='$height' rx='28' fill='url(#bg)'/>",
        "  <rect x='28' y='28' width='1144' height='364' rx='24' fill='#fffdf8' stroke='#e2d6b7'/>",
        "  <text x='60' y='80' class='font eyebrow'>Anonymous telemetry</text>",
        "  <text x='60' y='128' class='font title'>STS2 Mod User Curve</text>",
        "  <text x='60' y='154' class='font body'>Daily cumulative installations observed by the telemetry worker.</text>",
        "  <text x='860' y='84' class='font metricLabel'>Cumulative</text>",
        "  <text x='860' y='118' class='font metricValue'>$(Format-Number -Value $latest.cumulative_users)</text>",
        "  <text x='1000' y='84' class='font metricLabel'>Active</text>",
        "  <text x='1000' y='118' class='font metricValue'>$(Format-Number -Value $latest.active_users)</text>",
        "  <text x='1096' y='84' text-anchor='end' class='font metricLabel'>New</text>",
        "  <text x='1096' y='118' text-anchor='end' class='font metricValue'>$(Format-Number -Value $latest.new_users)</text>"
    )

    foreach ($tick in $yLabels) {
        $y = "{0:F2}" -f $tick.y
        $lines += "  <line x1='$plotLeft' y1='$y' x2='$(("{0:F2}" -f ($plotLeft + $plotWidth)))' y2='$y' class='grid'/>"
        $lines += "  <text x='60' y='$(("{0:F2}" -f ($tick.y + 4)))' class='font axis'>$(Format-Number -Value $tick.value)</text>"
    }

    $lines += "  <path d='$areaPath' fill='url(#fill)'/>"
    $lines += "  <path d='$linePath' fill='none' stroke='#c78a1f' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'/>"

    foreach ($labelIndex in $xLabelIndexes) {
        $row = $Rows[$labelIndex]
        $x = $plotLeft + ($plotWidth * $labelIndex / $rowCount)
        $formattedX = "{0:F2}" -f $x
        $lines += "  <line x1='$formattedX' y1='$(("{0:F2}" -f ($plotTop + $plotHeight)))' x2='$formattedX' y2='$(("{0:F2}" -f ($plotTop + $plotHeight + 8)))' stroke='#b6a57e' stroke-width='1'/>"
        $lines += "  <text x='$formattedX' y='$(("{0:F2}" -f ($plotTop + $plotHeight + 26)))' text-anchor='middle' class='font axis'>$($row.day)</text>"
    }

    $lines += @(
        "  <circle cx='$(("{0:F2}" -f ($plotLeft + $plotWidth)))' cy='$(("{0:F2}" -f ($plotTop + $plotHeight - ($plotHeight * ([double]$latest.cumulative_users / [double][math]::Max(1, $maxUsers))))))' r='6' fill='#c78a1f' stroke='#fffdf8' stroke-width='3'/>",
        "  <text x='60' y='372' class='font body'>Range: $($first.day) to $latestDayText</text>",
        "  <text x='1140' y='372' text-anchor='end' class='font body'>Updated: $generatedAtText</text>",
        "</svg>"
    )

    return [string]::Join("`n", $lines)
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)

    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$telemetryState = [ordered]@{
    has_data = $false
    status = "not_configured"
    status_text = "Telemetry not configured yet."
    generated_at = [DateTimeOffset]::UtcNow.ToString("o")
    range_days = 365
    latest = $null
    days = @()
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

if (-not [string]::IsNullOrWhiteSpace($StatsUrl)) {
    try {
        $response = Invoke-RestMethod -Uri $StatsUrl -Method Get -TimeoutSec 20
        $rows = Convert-ToUsageRows -Rows @($response.days)
        if ($rows.Count -gt 0) {
            $telemetryState.has_data = $true
            $telemetryState.status = "ok"
            $telemetryState.status_text = "Anonymous telemetry is active."
            $telemetryState.generated_at = if ($response.generated_at) { [string]$response.generated_at } else { [DateTimeOffset]::UtcNow.ToString("o") }
            $telemetryState.range_days = if ($null -ne $response.range_days) { [int]$response.range_days } else { [int]$rows.Count }
            $telemetryState.latest = $response.latest
            $telemetryState.days = $rows
        }
        else {
            $telemetryState.status = "no_data"
            $telemetryState.status_text = "Telemetry is deployed, but no daily heartbeats have arrived yet."
        }
    }
    catch {
        $telemetryState.status = "fetch_failed"
        $telemetryState.status_text = "Failed to fetch telemetry stats."
    }
}

$svgContent = if ($telemetryState.has_data) {
    New-UsageChartSvg -Rows @($telemetryState.days) -GeneratedAt ([string]$telemetryState.generated_at)
}
else {
    New-PlaceholderUsageChartSvg -StatusText ([string]$telemetryState.status_text)
}

Write-Utf8File -Path $usageSvgPath -Content $svgContent
Write-Utf8File -Path $usageJsonPath -Content (($telemetryState | ConvertTo-Json -Depth 6))

Write-Host "Built usage curve assets: $usageSvgPath"
