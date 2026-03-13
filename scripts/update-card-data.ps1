param(
    [string]$CommitMessage,
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$targetFiles = @(
    "data/cards.json",
    "data/cards.fallback.json",
    "data/sync_state.json"
)

function Get-ExistingTargetFiles {
    return @(
        $targetFiles |
        Where-Object { Test-Path -LiteralPath (Join-Path $projectRoot $_) }
    )
}

function Invoke-GitPushWithFallback {
    param(
        [Parameter(Mandatory)]
        [string]$Branch
    )

    & git push origin $Branch
    if ($LASTEXITCODE -eq 0) {
        return
    }

    $httpProxy = (& git config --global --get http.proxy 2>$null)
    $httpsProxy = (& git config --global --get https.proxy 2>$null)
    $proxyCandidates = @($httpProxy, $httpsProxy) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $hasLocalProxy = $proxyCandidates | Where-Object { $_ -match '^http://(127\.0\.0\.1|localhost)(:\d+)?/?$' } | Select-Object -First 1
    if (-not $hasLocalProxy) {
        throw "git push failed."
    }

    Write-Host "git push failed with local proxy settings. Retrying without git http/https proxy."
    & git -c http.proxy= -c https.proxy= push origin $Branch
    if ($LASTEXITCODE -ne 0) {
        throw "git push failed even after retrying without git proxy."
    }
}

try {
    & git rev-parse --is-inside-work-tree | Out-Null
}
catch {
    throw "This script must be run inside the git repository."
}

Write-Host "Syncing latest card data..."
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "sync-cards.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "sync-cards.ps1 failed."
}

Write-Host "Refreshing local Pages preview..."
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build-pages-data.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "build-pages-data.ps1 failed."
}

$existingTargetFiles = Get-ExistingTargetFiles
if (-not $existingTargetFiles) {
    throw "No tracked card data files were found."
}

$statusOutput = & git status --porcelain -- @existingTargetFiles
if (-not $statusOutput) {
    Write-Host "No card data changes detected. Nothing to commit."
    exit 0
}

if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
    $cardsPath = Join-Path $projectRoot "data/cards.json"
    $timestamp = $null
    if (Test-Path -LiteralPath $cardsPath) {
        try {
            $payload = Get-Content -LiteralPath $cardsPath -Raw | ConvertFrom-Json
            $timestamp = [string]$payload.updated_at
        }
        catch {
        }
    }

    if ([string]::IsNullOrWhiteSpace($timestamp)) {
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    $CommitMessage = "Update card data ($timestamp)"
}

Write-Host "Committing data files..."
& git add -- @existingTargetFiles
if ($LASTEXITCODE -ne 0) {
    throw "git add failed."
}

& git commit -m $CommitMessage -- @existingTargetFiles
if ($LASTEXITCODE -ne 0) {
    throw "git commit failed."
}

if ($NoPush) {
    Write-Host "Commit created locally. Push skipped because -NoPush was specified."
    exit 0
}

$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq "HEAD") {
    throw "Could not determine current git branch."
}

Write-Host "Pushing to origin/$branch..."
Invoke-GitPushWithFallback -Branch $branch

Write-Host "Done. GitHub Actions should now refresh Pages automatically."
Write-Host "Pages data URL: https://xmeowchan.github.io/STS2_Card_Stats/cards.json"
