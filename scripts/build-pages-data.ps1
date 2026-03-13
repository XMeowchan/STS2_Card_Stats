param(
    [string]$OutputDir = $(Join-Path (Split-Path -Parent $PSScriptRoot) "dist\pages")
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content (Join-Path $projectRoot "mod_manifest.json") | ConvertFrom-Json
$candidates = @(
    (Join-Path $projectRoot "data\cards.json"),
    (Join-Path $projectRoot "data\cards.fallback.json"),
    (Join-Path $projectRoot "sample_data\cards.sample.json")
)
$sourcePath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $sourcePath) {
    throw "No data source found for GitHub Pages output."
}

if (Test-Path -LiteralPath $OutputDir) {
    Remove-Item -LiteralPath $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$targetDataPath = Join-Path $OutputDir "cards.json"
Copy-Item -LiteralPath $sourcePath -Destination $targetDataPath -Force

$updatedAt = (Get-Item -LiteralPath $targetDataPath).LastWriteTimeUtc.ToString("o")
$sourceName = "xiaoheihe"

$indexLines = @(
    "<!DOCTYPE html>",
    "<html lang='en'>",
    "<head>",
    "  <meta charset='utf-8'>",
    "  <meta name='viewport' content='width=device-width, initial-scale=1'>",
    "  <title>XiaoHeiHe Card Stats Data</title>",
    "  <style>",
    "    body { font-family: Segoe UI, sans-serif; max-width: 720px; margin: 40px auto; padding: 0 16px; line-height: 1.6; color: #1b1e22; }",
    "    code, a { color: #0057a3; }",
    "    .meta { padding: 16px; border: 1px solid #d7dde5; border-radius: 12px; background: #f8fbff; }",
    "  </style>",
    "</head>",
    "<body>",
    "  <h1>XiaoHeiHe Card Stats Data</h1>",
    "  <div class='meta'>",
    "    <p><strong>Mod version:</strong> $($manifest.version)</p>",
    "    <p><strong>Data source:</strong> $sourceName</p>",
    "    <p><strong>Updated at:</strong> $updatedAt</p>",
    "    <p><strong>JSON URL:</strong> <a href='cards.json'>cards.json</a></p>",
    "  </div>",
    "</body>",
    "</html>"
)
Set-Content -LiteralPath (Join-Path $OutputDir "index.html") -Value $indexLines -Encoding UTF8
Set-Content -LiteralPath (Join-Path $OutputDir ".nojekyll") -Value "" -Encoding UTF8

Write-Host "Built GitHub Pages data output: $OutputDir"
