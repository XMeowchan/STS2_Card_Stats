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

function New-ChartPoint {
    param(
        [double]$X,
        [double]$Y
    )

    return [pscustomobject]@{
        x = $X
        y = $Y
    }
}

function Convert-ToSmoothSvgPath {
    param([object[]]$Points)

    if (-not $Points -or $Points.Count -eq 0) {
        return ""
    }

    $segments = New-Object System.Collections.Generic.List[string]
    $segments.Add(("M {0:F2},{1:F2}" -f $Points[0].x, $Points[0].y))

    if ($Points.Count -eq 1) {
        return $segments[0]
    }

    for ($index = 0; $index -lt $Points.Count - 1; $index += 1) {
        $p0 = if ($index -gt 0) { $Points[$index - 1] } else { $Points[$index] }
        $p1 = $Points[$index]
        $p2 = $Points[$index + 1]
        $p3 = if ($index + 2 -lt $Points.Count) { $Points[$index + 2] } else { $Points[$index + 1] }

        $cp1x = $p1.x + (($p2.x - $p0.x) / 6.0)
        $cp1y = $p1.y + (($p2.y - $p0.y) / 6.0)
        $cp2x = $p2.x - (($p3.x - $p1.x) / 6.0)
        $cp2y = $p2.y - (($p3.y - $p1.y) / 6.0)

        $segments.Add(("C {0:F2},{1:F2} {2:F2},{3:F2} {4:F2},{5:F2}" -f $cp1x, $cp1y, $cp2x, $cp2y, $p2.x, $p2.y))
    }

    return [string]::Join(" ", $segments)
}

function Get-DateTickIndexes {
    param(
        [object[]]$Rows,
        [int]$TickCount = 5
    )

    if (-not $Rows -or $Rows.Count -eq 0) {
        return @()
    }

    if ($Rows.Count -le $TickCount) {
        return @(0..($Rows.Count - 1))
    }

    $indexes = New-Object System.Collections.Generic.List[int]
    $indexes.Add(0)

    for ($slot = 1; $slot -lt ($TickCount - 1); $slot += 1) {
        $candidate = [int][math]::Round((($Rows.Count - 1) * $slot) / ($TickCount - 1))
        if (-not $indexes.Contains($candidate)) {
            $indexes.Add($candidate)
        }
    }

    if (-not $indexes.Contains($Rows.Count - 1)) {
        $indexes.Add($Rows.Count - 1)
    }

    return $indexes.ToArray() | Sort-Object
}

function Format-AxisDay {
    param(
        [string]$Day,
        [int]$SeriesLength,
        [bool]$IncludeYear = $false
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    try {
        $parsed = [DateTime]::ParseExact($Day, "yyyy-MM-dd", $culture)
    }
    catch {
        return $Day
    }

    if ($SeriesLength -ge 120) {
        return $parsed.ToString($(if ($IncludeYear) { "MMM yyyy" } else { "MMM" }), $culture)
    }

    if ($SeriesLength -ge 45) {
        return $parsed.ToString($(if ($IncludeYear) { "yyyy-MM-dd" } else { "MM-dd" }), $culture)
    }

    return $parsed.ToString($(if ($IncludeYear) { "yyyy-MM-dd" } else { "MM-dd" }), $culture)
}

function New-PlaceholderUsageChartSvg {
    param([string]$StatusText)

    $safeStatus = if ([string]::IsNullOrWhiteSpace($StatusText)) { "Telemetry not configured yet." } else { $StatusText }
    $lines = @(
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1240 436' role='img' aria-labelledby='title desc'>",
        "  <title id='title'>STS2 Mod User Curve</title>",
        "  <desc id='desc'>Placeholder chart while telemetry is unavailable.</desc>",
        "  <defs>",
        "    <linearGradient id='shell' x1='0%' y1='0%' x2='100%' y2='100%'>",
        "      <stop offset='0%' stop-color='#ece1c8'/>",
        "      <stop offset='100%' stop-color='#e2d4b5'/>",
        "    </linearGradient>",
        "    <linearGradient id='plotFill' x1='0%' y1='0%' x2='0%' y2='100%'>",
        "      <stop offset='0%' stop-color='#e5c88a' stop-opacity='0.26'/>",
        "      <stop offset='100%' stop-color='#e5c88a' stop-opacity='0.03'/>",
        "    </linearGradient>",
        "  </defs>",
        "  <style>",
        "    .font { font-family: 'Segoe UI', 'Microsoft YaHei UI', sans-serif; }",
        "    .eyebrow { font-size: 16px; font-weight: 700; fill: #996813; letter-spacing: 0.08em; text-transform: uppercase; }",
        "    .title { font-size: 36px; font-weight: 700; fill: #15263b; }",
        "    .body { font-size: 18px; fill: #5d6670; }",
        "    .metricLabel { font-size: 15px; fill: #5d6670; }",
        "    .metricValue { font-size: 26px; font-weight: 700; fill: #15263b; }",
        "    .grid { stroke: #e8dcc2; stroke-width: 1; }",
        "  </style>",
        "  <rect width='1240' height='436' rx='34' fill='url(#shell)'/>",
        "  <rect x='32' y='28' width='1176' height='380' rx='26' fill='#fffdf8' stroke='#d7c8a6'/>",
        "  <text x='66' y='82' class='font eyebrow'>Anonymous telemetry</text>",
        "  <text x='66' y='128' class='font title'>STS2 Mod User Curve</text>",
        "  <text x='66' y='158' class='font body'>Daily cumulative installations observed by the telemetry worker.</text>",
        "  <text x='876' y='84' class='font metricLabel'>Cumulative</text>",
        "  <text x='876' y='120' class='font metricValue'>--</text>",
        "  <text x='1012' y='84' class='font metricLabel'>Active</text>",
        "  <text x='1012' y='120' class='font metricValue'>--</text>",
        "  <text x='1120' y='84' text-anchor='end' class='font metricLabel'>New</text>",
        "  <text x='1120' y='120' text-anchor='end' class='font metricValue'>--</text>",
        "  <line x1='80' y1='194' x2='1162' y2='194' class='grid'/>",
        "  <line x1='80' y1='256' x2='1162' y2='256' class='grid'/>",
        "  <line x1='80' y1='318' x2='1162' y2='318' class='grid'/>",
        "  <path d='M 80,318 C 306,316 522,314 742,310 C 906,307 1038,303 1162,300 L 1162,346 L 80,346 Z' fill='url(#plotFill)'/>",
        "  <path d='M 80,318 C 306,316 522,314 742,310 C 906,307 1038,303 1162,300' fill='none' stroke='#c88a21' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'/>",
        "  <circle cx='80' cy='318' r='5' fill='#c88a21'/>",
        "  <circle cx='1162' cy='300' r='6' fill='#c88a21' stroke='#fffdf8' stroke-width='3'/>",
        "  <text x='66' y='278' class='font body'>This chart appears automatically after the telemetry worker starts receiving heartbeats.</text>",
        "  <text x='66' y='306' class='font body'>$safeStatus</text>",
        "  <text x='66' y='382' class='font body'>Range: awaiting telemetry data</text>",
        "  <text x='1140' y='382' text-anchor='end' class='font body'>Updated: pending</text>",
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
    $width = 1240
    $height = 436
    $plotLeft = 82.0
    $plotTop = 176.0
    $plotWidth = 1080.0
    $plotHeight = 164.0
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

    $points = New-Object System.Collections.Generic.List[object]
    for ($index = 0; $index -lt $Rows.Count; $index += 1) {
        $row = $Rows[$index]
        $x = $plotLeft + ($plotWidth * $index / $rowCount)
        $ratio = if ($maxUsers -le 0) { 0.0 } else { [double]$row.cumulative_users / [double]$maxUsers }
        $y = $plotTop + $plotHeight - ($plotHeight * $ratio)
        $points.Add((New-ChartPoint -X $x -Y $y))
    }

    $baselineY = $plotTop + $plotHeight
    $linePath = Convert-ToSmoothSvgPath -Points $points.ToArray()
    $lastPoint = $points[$points.Count - 1]
    $firstPoint = $points[0]
    $areaPath = "$linePath L $(("{0:F2},{1:F2}" -f $lastPoint.x, $baselineY)) L $(("{0:F2},{1:F2}" -f $firstPoint.x, $baselineY)) Z"

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

    $xLabelIndexes = Get-DateTickIndexes -Rows $Rows -TickCount 5
    $showYearOnEdges = $first.day.Substring(0, 4) -ne $latest.day.Substring(0, 4)

    $lines = @(
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 $width $height' role='img' aria-labelledby='title desc'>",
        "  <title id='title'>STS2 Mod User Curve</title>",
        "  <desc id='desc'>Cumulative anonymous mod users by day.</desc>",
        "  <defs>",
        "    <linearGradient id='shell' x1='0%' y1='0%' x2='100%' y2='100%'>",
        "      <stop offset='0%' stop-color='#ece1c8'/>",
        "      <stop offset='100%' stop-color='#e2d4b5'/>",
        "    </linearGradient>",
        "    <linearGradient id='fill' x1='0%' y1='0%' x2='0%' y2='100%'>",
        "      <stop offset='0%' stop-color='#e1be76' stop-opacity='0.42'/>",
        "      <stop offset='100%' stop-color='#e1be76' stop-opacity='0.04'/>",
        "    </linearGradient>",
        "  </defs>",
        "  <style>",
        "    .font { font-family: 'Segoe UI', 'Microsoft YaHei UI', sans-serif; }",
        "    .eyebrow { font-size: 16px; font-weight: 700; fill: #996813; letter-spacing: 0.08em; text-transform: uppercase; }",
        "    .title { font-size: 36px; font-weight: 700; fill: #15263b; }",
        "    .body { font-size: 18px; fill: #5d6670; }",
        "    .metricLabel { font-size: 15px; fill: #5d6670; }",
        "    .metricValue { font-size: 26px; font-weight: 700; fill: #15263b; }",
        "    .axis { font-size: 12px; fill: #5d6670; }",
        "    .grid { stroke: #e8dcc2; stroke-width: 1; }",
        "  </style>",
        "  <rect width='$width' height='$height' rx='34' fill='url(#shell)'/>",
        "  <rect x='32' y='28' width='1176' height='380' rx='26' fill='#fffdf8' stroke='#d7c8a6'/>",
        "  <text x='66' y='82' class='font eyebrow'>Anonymous telemetry</text>",
        "  <text x='66' y='128' class='font title'>STS2 Mod User Curve</text>",
        "  <text x='66' y='158' class='font body'>Daily cumulative installations observed by the telemetry worker.</text>",
        "  <text x='876' y='84' class='font metricLabel'>Cumulative</text>",
        "  <text x='876' y='120' class='font metricValue'>$(Format-Number -Value $latest.cumulative_users)</text>",
        "  <text x='1012' y='84' class='font metricLabel'>Active</text>",
        "  <text x='1012' y='120' class='font metricValue'>$(Format-Number -Value $latest.active_users)</text>",
        "  <text x='1120' y='84' text-anchor='end' class='font metricLabel'>New</text>",
        "  <text x='1120' y='120' text-anchor='end' class='font metricValue'>$(Format-Number -Value $latest.new_users)</text>"
    )

    foreach ($tick in $yLabels) {
        $y = "{0:F2}" -f $tick.y
        $lines += "  <line x1='$plotLeft' y1='$y' x2='$(("{0:F2}" -f ($plotLeft + $plotWidth)))' y2='$y' class='grid'/>"
        $lines += "  <text x='66' y='$(("{0:F2}" -f ($tick.y + 4)))' class='font axis'>$(Format-Number -Value $tick.value)</text>"
    }

    $lines += "  <path d='$areaPath' fill='url(#fill)'/>"
    $lines += "  <path d='$linePath' fill='none' stroke='#d8522b' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'/>"
    $lines += "  <circle cx='$(("{0:F2}" -f $firstPoint.x))' cy='$(("{0:F2}" -f $firstPoint.y))' r='5' fill='#d39a29'/>"

    foreach ($labelIndex in $xLabelIndexes) {
        $row = $Rows[$labelIndex]
        $x = $plotLeft + ($plotWidth * $labelIndex / $rowCount)
        $formattedX = "{0:F2}" -f $x
        $lines += "  <line x1='$formattedX' y1='$(("{0:F2}" -f ($plotTop + $plotHeight)))' x2='$formattedX' y2='$(("{0:F2}" -f ($plotTop + $plotHeight + 8)))' stroke='#b6a57e' stroke-width='1'/>"
        $labelText = Format-AxisDay -Day $row.day -SeriesLength $Rows.Count -IncludeYear (($showYearOnEdges -and ($labelIndex -eq 0 -or $labelIndex -eq ($Rows.Count - 1))))
        $lines += "  <text x='$formattedX' y='$(("{0:F2}" -f ($plotTop + $plotHeight + 28)))' text-anchor='middle' class='font axis'>$labelText</text>"
    }

    $lines += @(
        "  <circle cx='$(("{0:F2}" -f $lastPoint.x))' cy='$(("{0:F2}" -f $lastPoint.y))' r='6' fill='#c88a21' stroke='#fffdf8' stroke-width='3'/>",
        "  <text x='66' y='382' class='font body'>Range: $($first.day) to $latestDayText</text>",
        "  <text x='1140' y='382' text-anchor='end' class='font body'>Updated: $generatedAtText</text>",
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
