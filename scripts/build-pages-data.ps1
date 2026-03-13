param(
    [string]$OutputDir = $(Join-Path (Split-Path -Parent $PSScriptRoot) "dist\pages")
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content (Join-Path $projectRoot "mod_manifest.json") | ConvertFrom-Json
$config = Get-Content (Join-Path $projectRoot "config.json") | ConvertFrom-Json
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
$remoteDataUrl = [string]$config.remote_data_url
$sourceFileName = Split-Path -Leaf $sourcePath

$title = "STS2 &#x5361;&#x724c;&#x6570;&#x636e;&#x66f4;&#x65b0;&#x8bf4;&#x660e;"
$eyebrow = "STS2 GitHub Pages &#x6570;&#x636e;&#x6e90;"
$heroTitle = "&#x5c0f;&#x9ed1;&#x76d2;&#x5361;&#x724c;&#x6570;&#x636e;&#x66f4;&#x65b0;&#x8bf4;&#x660e;"
$heroBody = "&#x8fd9;&#x4e2a;&#x9875;&#x9762;&#x662f; <strong>XiaoHeiHei Card Stats Overlay</strong> &#x7684;&#x5728;&#x7ebf;&#x6570;&#x636e;&#x5165;&#x53e3;&#x3002;Mod&#x4f1a;&#x5148;&#x8bfb;&#x53d6;&#x672c;&#x5730;&#x968f;&#x5305;&#x6570;&#x636e;&#xff0c;&#x6709;&#x7f51;&#x65f6;&#x518d;&#x5c1d;&#x8bd5;&#x4ece;&#x8fd9;&#x91cc;&#x5237;&#x65b0;&#x6700;&#x65b0;&#x7684; <code>cards.json</code>&#x3002;"
$labelVersion = "&#x5f53;&#x524d;Mod&#x7248;&#x672c;"
$labelJsonUrl = "&#x7ebf;&#x4e0a;JSON&#x5730;&#x5740;"
$labelRemoteUrl = "&#x9ed8;&#x8ba4;&#x8fdc;&#x7a0b;&#x62c9;&#x53d6;&#x5730;&#x5740;"
$labelSourceFile = "&#x672c;&#x6b21;&#x53d1;&#x5e03;&#x6765;&#x6e90;"
$labelSourceName = "&#x6570;&#x636e;&#x6765;&#x6e90;"
$labelUpdatedAt = "&#x9875;&#x9762;&#x751f;&#x6210;&#x65f6;&#x95f4; (UTC)"
$sectionUpdateTitle = "&#x5982;&#x4f55;&#x66f4;&#x65b0;&#x5361;&#x724c;&#x6570;&#x636e;"
$sectionUpdate1 = "&#x5148;&#x5728;&#x4ed3;&#x5e93;&#x6839;&#x76ee;&#x5f55;&#x8fd0;&#x884c; <code>sync-cards</code> &#x811a;&#x672c;&#xff0c;&#x628a;&#x6700;&#x65b0;&#x91c7;&#x96c6;&#x7ed3;&#x679c;&#x540c;&#x6b65;&#x5230; <code>data/</code> &#x76ee;&#x5f55;&#x3002;"
$sectionUpdate2 = "&#x786e;&#x8ba4; <code>data/cards.json</code>&#x3001;<code>data/cards.fallback.json</code>&#x3001;<code>data/sync_state.json</code> &#x90fd;&#x5df2;&#x5237;&#x65b0;&#x3002;"
$sectionUpdate3 = "&#x628a;&#x6539;&#x52a8;&#x63d0;&#x4ea4;&#x5e76;&#x63a8;&#x9001;&#x5230; <code>main</code> &#x5206;&#x652f;&#x3002;"
$sectionUpdate4 = "GitHub Actions &#x4f1a;&#x81ea;&#x52a8;&#x91cd;&#x65b0;&#x53d1;&#x5e03;&#x8fd9;&#x4e2a; Pages &#x7ad9;&#x70b9;&#xff0c;Mod&#x540e;&#x7eed;&#x5c31;&#x4f1a;&#x4ece;&#x65b0;&#x7684; <code>cards.json</code> &#x62c9;&#x53d6;&#x6570;&#x636e;&#x3002;"
$sectionTip = "&#x5982;&#x679c;&#x4f60;&#x53ea;&#x662f;&#x66f4;&#x65b0;&#x7ebf;&#x4e0a;&#x6570;&#x636e;&#xff0c;&#x901a;&#x5e38;&#x4e0d;&#x9700;&#x8981;&#x91cd;&#x65b0;&#x6253;&#x5b89;&#x88c5;&#x5305;&#x3002;&#x53ea;&#x6709;&#x5728;&#x4f60;&#x5e0c;&#x671b;&#x65b0;&#x5b89;&#x88c5;&#x7528;&#x6237;&#x4e5f;&#x62ff;&#x5230;&#x6700;&#x65b0;&#x79bb;&#x7ebf;&#x6570;&#x636e;&#xff0c;&#x6216;&#x8005;Mod&#x4ee3;&#x7801;&#x672c;&#x8eab;&#x53d1;&#x751f;&#x53d8;&#x5316;&#x65f6;&#xff0c;&#x624d;&#x9700;&#x8981;&#x91cd;&#x65b0;&#x6253;&#x5305;&#x5e76;&#x66f4;&#x65b0;Release&#x3002;"
$sectionRepackTitle = "&#x4ec0;&#x4e48;&#x65f6;&#x5019;&#x9700;&#x8981;&#x91cd;&#x6253;&#x5b89;&#x88c5;&#x5305;"
$sectionRepack1 = "Mod&#x4ee3;&#x7801;&#x3001;&#x914d;&#x7f6e;&#x9879;&#x3001;&#x754c;&#x9762;&#x5e03;&#x5c40;&#x53d1;&#x751f;&#x53d8;&#x5316;&#x3002;"
$sectionRepack2 = "&#x4f60;&#x60f3;&#x8ba9;&#x65b0;&#x4e0b;&#x8f7d;&#x5b89;&#x88c5;&#x7684;&#x7528;&#x6237;&#x76f4;&#x63a5;&#x62ff;&#x5230;&#x6700;&#x65b0;&#x79bb;&#x7ebf;&#x6570;&#x636e;&#x3002;"
$sectionRepack3 = "&#x6570;&#x636e;&#x7ed3;&#x6784;&#x3001;&#x517c;&#x5bb9;&#x7b56;&#x7565;&#x6216;&#x6253;&#x5305;&#x65b9;&#x5f0f;&#x6709;&#x53d8;&#x66f4;&#x3002;"
$sectionConfigTitle = "&#x8fdc;&#x7a0b;&#x914d;&#x7f6e;&#x793a;&#x4f8b;"
$sectionConfigBody = "&#x9ed8;&#x8ba4;&#x914d;&#x7f6e;&#x5df2;&#x7ecf;&#x6307;&#x5411;&#x8fd9;&#x4e2a;&#x4ed3;&#x5e93;&#x7684; Pages &#x5730;&#x5740;&#x3002;&#x5982;&#x679c;&#x4f60;&#x8981;&#x624b;&#x52a8;&#x586b;&#x5199;&#xff0c;&#x53ef;&#x4ee5;&#x5728; <code>config.json</code> &#x91cc;&#x4f7f;&#x7528;&#x4e0b;&#x9762;&#x8fd9;&#x7ec4;&#x5b57;&#x6bb5;&#x3002;"

$indexLines = @(
    "<!DOCTYPE html>",
    "<html lang='zh-CN'>",
    "<head>",
    "  <meta charset='utf-8'>",
    "  <meta name='viewport' content='width=device-width, initial-scale=1'>",
    "  <title>$title</title>",
    "  <style>",
    "    :root { --bg: #f5f1e8; --panel: #fffdf8; --ink: #1d252c; --muted: #5e6b75; --line: #d9d0bf; --accent: #165d52; --accent-soft: #e2f1ed; --code: #f0ece2; }",
    "    * { box-sizing: border-box; }",
    "    body { margin: 0; font-family: 'Microsoft YaHei UI', 'PingFang SC', 'Noto Sans SC', sans-serif; background: radial-gradient(circle at top, #fff9ef 0%, var(--bg) 52%, #efe5d4 100%); color: var(--ink); line-height: 1.75; }",
    "    main { max-width: 920px; margin: 0 auto; padding: 40px 20px 56px; }",
    "    .hero { background: linear-gradient(145deg, rgba(255,255,255,0.96), rgba(249,245,236,0.95)); border: 1px solid var(--line); border-radius: 24px; padding: 28px; box-shadow: 0 18px 48px rgba(88, 71, 36, 0.10); }",
    "    .eyebrow { display: inline-block; padding: 6px 12px; border-radius: 999px; background: var(--accent-soft); color: var(--accent); font-size: 13px; font-weight: 700; letter-spacing: 0.04em; }",
    "    h1 { margin: 14px 0 10px; font-size: clamp(30px, 5vw, 46px); line-height: 1.15; }",
    "    h2 { margin: 0 0 12px; font-size: 24px; }",
    "    p { margin: 0 0 12px; }",
    "    .lede { color: var(--muted); font-size: 16px; max-width: 52em; }",
    "    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 16px; margin-top: 22px; }",
    "    .card { background: var(--panel); border: 1px solid var(--line); border-radius: 20px; padding: 20px; box-shadow: 0 10px 28px rgba(88, 71, 36, 0.07); }",
    "    .label { display: block; color: var(--muted); font-size: 13px; margin-bottom: 6px; }",
    "    .value { font-size: 16px; font-weight: 700; word-break: break-all; }",
    "    .section { margin-top: 22px; }",
    "    .section p:last-child { margin-bottom: 0; }",
    "    ol { margin: 0; padding-left: 22px; }",
    "    li { margin: 0 0 10px; }",
    "    code { font-family: 'Cascadia Code', 'Consolas', monospace; background: var(--code); padding: 2px 6px; border-radius: 6px; }",
    "    pre { margin: 12px 0 0; padding: 14px 16px; overflow-x: auto; border-radius: 14px; background: #1f252b; color: #f6f2e8; border: 1px solid #303841; }",
    "    pre code { background: transparent; padding: 0; color: inherit; }",
    "    a { color: var(--accent); text-decoration: none; }",
    "    a:hover { text-decoration: underline; }",
    "    .tip { margin-top: 16px; padding: 14px 16px; border-left: 4px solid var(--accent); border-radius: 12px; background: var(--accent-soft); }",
    "  </style>",
    "</head>",
    "<body>",
    "  <main>",
    "    <section class='hero'>",
    "      <span class='eyebrow'>$eyebrow</span>",
    "      <h1>$heroTitle</h1>",
    "      <p class='lede'>$heroBody</p>",
    "      <div class='grid'>",
    "        <article class='card'>",
    "          <span class='label'>$labelVersion</span>",
    "          <div class='value'>$($manifest.version)</div>",
    "        </article>",
    "        <article class='card'>",
    "          <span class='label'>$labelJsonUrl</span>",
    "          <div class='value'><a href='cards.json'>cards.json</a></div>",
    "        </article>",
    "        <article class='card'>",
    "          <span class='label'>$labelRemoteUrl</span>",
    "          <div class='value'><a href='$remoteDataUrl'>$remoteDataUrl</a></div>",
    "        </article>",
    "        <article class='card'>",
    "          <span class='label'>$labelSourceFile</span>",
    "          <div class='value'>$sourceFileName</div>",
    "        </article>",
    "        <article class='card'>",
    "          <span class='label'>$labelSourceName</span>",
    "          <div class='value'>$sourceName</div>",
    "        </article>",
    "        <article class='card'>",
    "          <span class='label'>$labelUpdatedAt</span>",
    "          <div class='value'>$updatedAt</div>",
    "        </article>",
    "      </div>",
    "    </section>",
    "",
    "    <section class='section card'>",
    "      <h2>$sectionUpdateTitle</h2>",
    "      <ol>",
    "        <li>$sectionUpdate1</li>",
    "        <li>$sectionUpdate2</li>",
    "        <li>$sectionUpdate3</li>",
    "        <li>$sectionUpdate4</li>",
    "      </ol>",
    "      <pre><code>powershell -ExecutionPolicy Bypass -File .\scripts\sync-cards.ps1",
    "git add data/cards.json data/cards.fallback.json data/sync_state.json",
    "git commit -m ""Update card data""",
    "git push origin main</code></pre>",
    "      <div class='tip'>$sectionTip</div>",
    "    </section>",
    "",
    "    <section class='section card'>",
    "      <h2>$sectionRepackTitle</h2>",
    "      <ol>",
    "        <li>$sectionRepack1</li>",
    "        <li>$sectionRepack2</li>",
    "        <li>$sectionRepack3</li>",
    "      </ol>",
    "      <pre><code>powershell -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1</code></pre>",
    "    </section>",
    "",
    "    <section class='section card'>",
    "      <h2>$sectionConfigTitle</h2>",
    "      <p>$sectionConfigBody</p>",
    "      <pre><code>{",
    "  ""remote_data_enabled"": true,",
    "  ""remote_data_url"": ""$remoteDataUrl"",",
    "  ""remote_refresh_minutes"": 180,",
    "  ""remote_timeout_seconds"": 5",
    "}</code></pre>",
    "    </section>",
    "  </main>",
    "</body>",
    "</html>"
)
Set-Content -LiteralPath (Join-Path $OutputDir "index.html") -Value $indexLines -Encoding UTF8
Set-Content -LiteralPath (Join-Path $OutputDir ".nojekyll") -Value "" -Encoding UTF8

Write-Host "Built GitHub Pages data output: $OutputDir"
