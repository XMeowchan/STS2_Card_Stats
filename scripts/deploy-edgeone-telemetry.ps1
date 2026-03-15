param(
    [string]$ProjectName = "sts2-card-stats-telemetry-overseas",
    [string]$Environment = "production",
    [string]$Area = "overseas",
    [string]$Token = $(if ([string]::IsNullOrWhiteSpace($env:EDGEONE_API_TOKEN)) { "" } else { $env:EDGEONE_API_TOKEN })
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$telemetryRoot = Join-Path $projectRoot "telemetry_edgeone"

if (-not (Test-Path -LiteralPath $telemetryRoot)) {
    throw "Telemetry EdgeOne project not found: $telemetryRoot"
}

Push-Location $telemetryRoot
try {
    $deployArgs = @(
        "-y",
        "edgeone",
        "pages",
        "deploy",
        ".",
        "-n",
        $ProjectName,
        "-e",
        $Environment,
        "-a",
        $Area
    )

    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $deployArgs += @("-t", $Token.Trim())
    }

    if ($Area -eq "global") {
        Write-Warning "Using area 'global' with a custom domain may require ICP filing. Use 'overseas' to avoid that requirement."
    }

    Write-Host "Deploying EdgeOne telemetry project '$ProjectName' from '$telemetryRoot' in area '$Area'..."
    npx @deployArgs
    if ($LASTEXITCODE -ne 0) {
        throw "EdgeOne deploy failed."
    }
}
finally {
    Pop-Location
}
