param(
    [string]$ConfigPath,
    [string]$GameDir,
    [string]$ModDir,
    [switch]$RefreshFallback
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "Sts2InstallHelpers.ps1")

$tempConfigPath = $null
if ([string]::IsNullOrWhiteSpace($ConfigPath) -or -not [string]::IsNullOrWhiteSpace($GameDir) -or -not [string]::IsNullOrWhiteSpace($ModDir)) {
    $resolvedGameDir = $null
    if (-not [string]::IsNullOrWhiteSpace($GameDir)) {
        $resolvedGameDir = Resolve-Sts2GameDir -RequestedPath $GameDir
    } elseif ([string]::IsNullOrWhiteSpace($ModDir)) {
        $resolvedGameDir = Resolve-Sts2GameDir -AllowMissing
    }

    $resolvedModDir = $ModDir
    if ([string]::IsNullOrWhiteSpace($resolvedModDir) -and -not [string]::IsNullOrWhiteSpace($resolvedGameDir)) {
        $resolvedModDir = Join-Path (Resolve-Sts2ModsRoot -GameDir $resolvedGameDir) "HeyboxCardStatsOverlay"
    }

    $tempConfigPath = New-TemporarySyncerConfig -ProjectRoot $projectRoot -GameDir $resolvedGameDir -ModDir $resolvedModDir
    $ConfigPath = $tempConfigPath
} elseif (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$node = (Get-Command node -ErrorAction Stop).Source
$args = @((Join-Path $projectRoot "syncer\sync-cards.mjs"), "--config", $ConfigPath)
if ($RefreshFallback) {
    $args += "--refresh-fallback"
}

try {
    & $node @args
    exit $LASTEXITCODE
}
finally {
    if ($tempConfigPath -and (Test-Path -LiteralPath $tempConfigPath)) {
        Remove-Item -LiteralPath $tempConfigPath -Force -ErrorAction SilentlyContinue
    }
}
