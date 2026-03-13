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

    return ,($filled.ToArray())
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

function New-DoodleLinePath {
    param(
        [double]$X1,
        [double]$Y1,
        [double]$X2,
        [double]$Y2,
        [double]$Amplitude = 4.0,
        [int]$Segments = 8
    )

    $dx = $X2 - $X1
    $dy = $Y2 - $Y1
    $length = [math]::Sqrt(($dx * $dx) + ($dy * $dy))
    if ($length -le 0) {
        return ("M {0:F2},{1:F2}" -f $X1, $Y1)
    }

    $normalX = -$dy / $length
    $normalY = $dx / $length
    $points = New-Object System.Collections.Generic.List[object]

    for ($index = 0; $index -le $Segments; $index += 1) {
        $t = [double]$index / [double]$Segments
        $baseX = $X1 + ($dx * $t)
        $baseY = $Y1 + ($dy * $t)
        $offset = 0.0

        if ($index -gt 0 -and $index -lt $Segments) {
            $direction = if (($index % 2) -eq 0) { -1.0 } else { 1.0 }
            $strength = 1.0 - ([math]::Abs(0.5 - $t) * 0.8)
            $offset = $direction * $Amplitude * $strength
        }

        $points.Add((New-ChartPoint -X ($baseX + ($normalX * $offset)) -Y ($baseY + ($normalY * $offset))))
    }

    return Convert-ToSmoothSvgPath -Points $points.ToArray()
}

function New-PlaceholderUsageChartSvg {
    param([string]$StatusText)

    $safeStatus = if ([string]::IsNullOrWhiteSpace($StatusText)) { "No data yet" } else { $StatusText }
    $width = 1240
    $height = 540
    $plotLeft = 126.0
    $plotTop = 104.0
    $plotWidth = 1010.0
    $plotHeight = 328.0
    $baselineY = $plotTop + $plotHeight
    $axisColor = "#101010"
    $curveColor = "#d9472f"
    $xAxisPath = New-DoodleLinePath -X1 $plotLeft -Y1 $baselineY -X2 ($plotLeft + $plotWidth) -Y2 $baselineY -Amplitude 3.5 -Segments 10
    $yAxisPath = New-DoodleLinePath -X1 $plotLeft -Y1 $plotTop -X2 $plotLeft -Y2 $baselineY -Amplitude 4.5 -Segments 8
    $yLabels = @(
        [pscustomobject]@{ value = 10; y = $plotTop },
        [pscustomobject]@{ value = 5; y = $plotTop + ($plotHeight / 2.0) },
        [pscustomobject]@{ value = 0; y = $baselineY }
    )

    $lines = @(
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 $width $height' role='img' aria-labelledby='title desc'>",
        "  <title id='title'>STS2 Mod User Curve</title>",
        "  <desc id='desc'>Minimal hand-drawn style user curve placeholder.</desc>",
        "  <style>",
        "    .font { font-family: 'Segoe Print', 'Comic Sans MS', 'Microsoft YaHei UI', cursive; }",
        "    .metricLabel { font-size: 16px; fill: #303030; }",
        "    .metricValue { font-size: 28px; font-weight: 700; fill: #101010; }",
        "    .tick { font-size: 15px; fill: #101010; }",
        "    .axisLabel { font-size: 18px; fill: #101010; }",
        "    .meta { font-size: 14px; fill: #444444; }",
        "  </style>",
        "  <rect width='$width' height='$height' rx='22' fill='#ffffff'/>",
        "  <path d='$xAxisPath' fill='none' stroke='$axisColor' stroke-width='5' stroke-linecap='round' stroke-linejoin='round'/>",
        "  <path d='$yAxisPath' fill='none' stroke='$axisColor' stroke-width='5' stroke-linecap='round' stroke-linejoin='round'/>",
        "  <text x='860' y='52' class='font metricLabel'>Total</text>",
        "  <text x='860' y='86' class='font metricValue'>--</text>",
        "  <text x='970' y='52' class='font metricLabel'>Active</text>",
        "  <text x='970' y='86' class='font metricValue'>--</text>",
        "  <text x='1098' y='52' text-anchor='end' class='font metricLabel'>New</text>",
        "  <text x='1098' y='86' text-anchor='end' class='font metricValue'>--</text>",
        "  <path d='M 166.00,402.00 C 348.00,396.00 566.00,398.00 782.00,395.00 C 916.00,393.00 1026.00,391.00 1122.00,388.00' fill='none' stroke='$curveColor' stroke-width='5' stroke-linecap='round' stroke-linejoin='round'/>",
        "  <text x='620' y='260' text-anchor='middle' class='font meta'>$safeStatus</text>",
        "  <text x='1140' y='496' text-anchor='end' class='font meta'>Updated pending</text>",
        "  <text x='642' y='522' text-anchor='middle' class='font axisLabel'>Date</text>",
        "  <text x='44' y='270' transform='rotate(-90 44 270)' class='font axisLabel'>Users</text>"
    )

    foreach ($tick in $yLabels) {
        $y = "{0:F2}" -f $tick.y
        $lines += "  <line x1='118' y1='$y' x2='138' y2='$y' stroke='$axisColor' stroke-width='3' stroke-linecap='round'/>"
        $lines += "  <text x='96' y='$(("{0:F2}" -f ($tick.y + 5)))' text-anchor='end' class='font tick'>$($tick.value)</text>"
    }

    $lines += @(
        "  <line x1='126.00' y1='432.00' x2='126.00' y2='448.00' stroke='$axisColor' stroke-width='3' stroke-linecap='round'/>",
        "  <text x='126.00' y='474.00' text-anchor='middle' class='font tick'>--</text>",
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
    $height = 540
    $plotLeft = 126.0
    $plotTop = 104.0
    $plotWidth = 1010.0
    $plotHeight = 328.0
    $plotRows = if ($Rows.Count -eq 1) { @($Rows[0], $Rows[0]) } else { $Rows }
    $rowCount = [double][math]::Max(1, $plotRows.Count - 1)
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
    for ($index = 0; $index -lt $plotRows.Count; $index += 1) {
        $row = $plotRows[$index]
        $x = $plotLeft + ($plotWidth * $index / $rowCount)
        $ratio = if ($maxUsers -le 0) { 0.0 } else { [double]$row.cumulative_users / [double]$maxUsers }
        $y = $plotTop + $plotHeight - ($plotHeight * $ratio)
        $points.Add((New-ChartPoint -X $x -Y $y))
    }

    $baselineY = $plotTop + $plotHeight
    $linePath = Convert-ToSmoothSvgPath -Points $points.ToArray()
    $lastPoint = $points[$points.Count - 1]
    $firstPoint = $points[0]
    $xAxisPath = New-DoodleLinePath -X1 $plotLeft -Y1 $baselineY -X2 ($plotLeft + $plotWidth) -Y2 $baselineY -Amplitude 3.5 -Segments 10
    $yAxisPath = New-DoodleLinePath -X1 $plotLeft -Y1 $plotTop -X2 $plotLeft -Y2 $baselineY -Amplitude 4.5 -Segments 8

    $latest = $Rows[-1]
    $first = $Rows[0]
    $generatedAtText = if ([string]::IsNullOrWhiteSpace($GeneratedAt)) {
        [DateTimeOffset]::UtcNow.ToString("yyyy-MM-dd", $culture)
    } else {
        try {
            ([DateTimeOffset]::Parse($GeneratedAt, $culture)).ToUniversalTime().ToString("yyyy-MM-dd", $culture)
        }
        catch {
            $GeneratedAt
        }
    }

    $xLabelIndexes = if ($Rows.Count -eq 1) { @(0) } else { Get-DateTickIndexes -Rows $Rows -TickCount 5 }
    $showYearOnEdges = $first.day.Substring(0, 4) -ne $latest.day.Substring(0, 4)
    $axisColor = "#101010"
    $curveColor = "#d9472f"

    $lines = @(
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 $width $height' role='img' aria-labelledby='title desc'>",
        "  <title id='title'>STS2 Mod User Curve</title>",
        "  <desc id='desc'>Minimal hand-drawn style cumulative user curve.</desc>",
        "  <style>",
        "    .font { font-family: 'Segoe Print', 'Comic Sans MS', 'Microsoft YaHei UI', cursive; }",
        "    .metricLabel { font-size: 16px; fill: #303030; }",
        "    .metricValue { font-size: 28px; font-weight: 700; fill: #101010; }",
        "    .tick { font-size: 15px; fill: #101010; }",
        "    .axisLabel { font-size: 18px; fill: #101010; }",
        "    .meta { font-size: 14px; fill: #444444; }",
        "  </style>",
        "  <rect width='$width' height='$height' rx='22' fill='#ffffff'/>",
        "  <path d='$xAxisPath' fill='none' stroke='$axisColor' stroke-width='5' stroke-linecap='round' stroke-linejoin='round'/>",
        "  <path d='$yAxisPath' fill='none' stroke='$axisColor' stroke-width='5' stroke-linecap='round' stroke-linejoin='round'/>",
        "  <text x='860' y='52' class='font metricLabel'>Total</text>",
        "  <text x='860' y='86' class='font metricValue'>$(Format-Number -Value $latest.cumulative_users)</text>",
        "  <text x='970' y='52' class='font metricLabel'>Active</text>",
        "  <text x='970' y='86' class='font metricValue'>$(Format-Number -Value $latest.active_users)</text>",
        "  <text x='1098' y='52' text-anchor='end' class='font metricLabel'>New</text>",
        "  <text x='1098' y='86' text-anchor='end' class='font metricValue'>$(Format-Number -Value $latest.new_users)</text>"
    )

    foreach ($tick in $yLabels) {
        $y = "{0:F2}" -f $tick.y
        $lines += "  <line x1='118' y1='$y' x2='138' y2='$y' stroke='$axisColor' stroke-width='3' stroke-linecap='round'/>"
        $lines += "  <text x='96' y='$(("{0:F2}" -f ($tick.y + 5)))' text-anchor='end' class='font tick'>$(Format-Number -Value $tick.value)</text>"
    }

    $lines += "  <path d='$linePath' fill='none' stroke='$curveColor' stroke-width='5' stroke-linecap='round' stroke-linejoin='round'/>"
    $lines += "  <circle cx='$(("{0:F2}" -f $firstPoint.x))' cy='$(("{0:F2}" -f $firstPoint.y))' r='5' fill='$curveColor'/>"

    foreach ($labelIndex in $xLabelIndexes) {
        $row = $Rows[$labelIndex]
        $x = if ($Rows.Count -eq 1) { $plotLeft } else { $plotLeft + ($plotWidth * $labelIndex / [double][math]::Max(1, $Rows.Count - 1)) }
        $formattedX = "{0:F2}" -f $x
        $lines += "  <line x1='$formattedX' y1='$(("{0:F2}" -f $baselineY))' x2='$formattedX' y2='$(("{0:F2}" -f ($baselineY + 16)))' stroke='$axisColor' stroke-width='3' stroke-linecap='round'/>"
        $labelText = Format-AxisDay -Day $row.day -SeriesLength $Rows.Count -IncludeYear (($Rows.Count -eq 1) -or ($showYearOnEdges -and ($labelIndex -eq 0 -or $labelIndex -eq ($Rows.Count - 1))))
        $lines += "  <text x='$formattedX' y='$(("{0:F2}" -f ($baselineY + 42)))' text-anchor='middle' class='font tick'>$labelText</text>"
    }

    $lines += @(
        "  <circle cx='$(("{0:F2}" -f $lastPoint.x))' cy='$(("{0:F2}" -f $lastPoint.y))' r='6' fill='$curveColor'/>",
        "  <text x='1140' y='496' text-anchor='end' class='font meta'>Updated $generatedAtText</text>",
        "  <text x='642' y='522' text-anchor='middle' class='font axisLabel'>Date</text>",
        "  <text x='44' y='270' transform='rotate(-90 44 270)' class='font axisLabel'>Users</text>",
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
