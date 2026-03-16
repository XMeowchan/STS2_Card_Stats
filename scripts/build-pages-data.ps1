param(
    [string]$OutputDir = $(Join-Path (Split-Path -Parent $PSScriptRoot) "dist\pages"),
    [string]$TelemetryStatsUrl = $(if ([string]::IsNullOrWhiteSpace($env:TELEMETRY_STATS_URL)) { "https://telemetry.xmeow.cn/v1/stats?days=365" } else { $env:TELEMETRY_STATS_URL })
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
& (Join-Path $PSScriptRoot "build-usage-curve.ps1") -OutputDir $OutputDir -StatsUrl $TelemetryStatsUrl

$updatedAt = (Get-Item -LiteralPath $targetDataPath).LastWriteTimeUtc.ToString("o")
$sourceName = "community"
$remoteDataUrl = [string]$config.remote_data_url
$sourceFileName = Split-Path -Leaf $sourcePath
$usageStatsPath = Join-Path $OutputDir "usage-stats.json"
$usageStats = if (Test-Path -LiteralPath $usageStatsPath) {
    Get-Content -LiteralPath $usageStatsPath -Raw | ConvertFrom-Json
}
else {
    $null
}
$usageHasData = ($null -ne $usageStats) -and [bool]$usageStats.has_data
$usageStatusText = if ($null -ne $usageStats -and -not [string]::IsNullOrWhiteSpace([string]$usageStats.status_text)) {
    [string]$usageStats.status_text
}
else {
    "Telemetry not configured yet."
}
$usageAssetVersion = if ($null -ne $usageStats -and -not [string]::IsNullOrWhiteSpace([string]$usageStats.generated_at)) {
    [Uri]::EscapeDataString([string]$usageStats.generated_at)
}
else {
    [Uri]::EscapeDataString($updatedAt)
}
$usageStatsHref = "usage-stats.json?v=$usageAssetVersion"
$usageChartHref = "users-history.svg?v=$usageAssetVersion"
$usageCumulativeUsers = if ($usageHasData -and $null -ne $usageStats.latest) { "{0:N0}" -f [int]$usageStats.latest.cumulative_users } else { "--" }
$usageActiveUsers = if ($usageHasData -and $null -ne $usageStats.latest) { "{0:N0}" -f [int]$usageStats.latest.active_users } else { "--" }
$usageLatestDay = if ($usageHasData -and $null -ne $usageStats.latest -and -not [string]::IsNullOrWhiteSpace([string]$usageStats.latest.day)) { [string]$usageStats.latest.day } else { "--" }
$translations = [ordered]@{
    "zh-CN" = [ordered]@{
        pageTitle = "STS2 卡牌数据更新说明"
        eyebrow = "STS2 GitHub Pages 数据源"
        heroTitle = "社区卡牌数据更新说明"
        heroBody = "这个页面是 <strong>STS2 Card Stats Overlay</strong> 的在线数据入口。Mod 会先读取本地随包数据，有网时再尝试从这里刷新最新的 <code>cards.json</code>。"
        labelVersion = "当前 Mod 版本"
        labelJsonUrl = "线上 JSON 地址"
        labelRemoteUrl = "默认远程拉取地址"
        labelSourceFile = "本次发布来源"
        labelSourceName = "数据来源"
        labelUpdatedAt = "页面生成时间 (UTC)"
        sectionUsageTitle = "匿名用户量曲线"
        sectionUsageBody = "当你部署免费 Cloudflare Worker 后，Mod 会每天最多上报一次匿名心跳。下面这条曲线用来展示累计被观测到的安装实例数。"
        labelUsageJson = "Telemetry JSON"
        usageImageAlt = "STS2 mod user curve"
        sectionUpdateTitle = "如何更新卡牌数据"
        sectionUpdate1 = "先在仓库根目录运行 <code>sync-cards</code> 脚本，把最新采集结果同步到 <code>data/</code> 目录。"
        sectionUpdate2 = "确认 <code>data/cards.json</code>、<code>data/cards.fallback.json</code>、<code>data/sync_state.json</code> 都已刷新。"
        sectionUpdate3 = "把改动提交并推送到 <code>main</code> 分支。"
        sectionUpdate4 = "GitHub Actions 会自动重新发布这个 Pages 站点，Mod 后续就会从新的 <code>cards.json</code> 拉取数据。"
        sectionShortcut = "如果你想一键完成同步数据 + 本地预览 + 提交 + 推送，可以直接运行下面这条命令。"
        sectionTip = "如果你只是更新线上数据，通常不需要重新打安装包。只有在你希望新安装用户也拿到最新离线数据，或者 Mod 代码本身发生变化时，才需要重新打包并更新 Release。"
        sectionRepackTitle = "什么时候需要重打安装包"
        sectionRepack1 = "Mod 代码、配置项、界面布局发生变化。"
        sectionRepack2 = "你想让新下载安装的用户直接拿到最新离线数据。"
        sectionRepack3 = "数据结构、兼容策略或打包方式有变更。"
        sectionConfigTitle = "远程配置示例"
        sectionConfigBody = "默认配置已经指向这个仓库的 Pages 地址。如果你要手动填写，可以在 <code>config.json</code> 里使用下面这组字段。"
    }
    "en" = [ordered]@{
        pageTitle = "STS2 Card Data Update Guide"
        eyebrow = "STS2 GitHub Pages Data Source"
        heroTitle = "Community Card Stats Update Guide"
        heroBody = "This page is the hosted data entry for <strong>STS2 Card Stats Overlay</strong>. The mod reads bundled local data first, then refreshes the latest <code>cards.json</code> from here when a network connection is available."
        labelVersion = "Current mod version"
        labelJsonUrl = "Hosted JSON URL"
        labelRemoteUrl = "Default remote fetch URL"
        labelSourceFile = "Published source file"
        labelSourceName = "Data source"
        labelUpdatedAt = "Page generated at (UTC)"
        sectionUsageTitle = "Anonymous user curve"
        sectionUsageBody = "After you deploy the free Cloudflare Worker, the mod reports at most one anonymous heartbeat per day. The curve below shows the observed cumulative installs."
        labelUsageJson = "Telemetry JSON"
        usageImageAlt = "STS2 mod user curve"
        sectionUpdateTitle = "How to update card data"
        sectionUpdate1 = "Run the <code>sync-cards</code> script from the repository root to sync the latest collector output into <code>data/</code>."
        sectionUpdate2 = "Confirm that <code>data/cards.json</code>, <code>data/cards.fallback.json</code>, and <code>data/sync_state.json</code> were refreshed."
        sectionUpdate3 = "Commit the changes and push them to the <code>main</code> branch."
        sectionUpdate4 = "GitHub Actions republishes this Pages site automatically, and the mod then pulls the new <code>cards.json</code>."
        sectionShortcut = "If you want a one-command path for sync + local preview + commit + push, run this command."
        sectionTip = "If you are only refreshing the hosted data, you usually do not need to rebuild the installer. Repack only when new installs should bundle fresher offline data, or when the mod itself changes."
        sectionRepackTitle = "When to rebuild the installer"
        sectionRepack1 = "The mod code, config, or UI layout changes."
        sectionRepack2 = "You want new downloads to include the latest offline data immediately."
        sectionRepack3 = "The data structure, compatibility strategy, or packaging flow changes."
        sectionConfigTitle = "Remote config example"
        sectionConfigBody = "The default config already points to this repository's Pages URL. If you need to fill it manually, use these fields in <code>config.json</code>."
    }
    "ja" = [ordered]@{
        pageTitle = "STS2 カードデータ更新ガイド"
        eyebrow = "STS2 GitHub Pages データソース"
        heroTitle = "コミュニティカードデータ更新ガイド"
        heroBody = "このページは <strong>STS2 Card Stats Overlay</strong> のオンラインデータ入口です。Mod はまず同梱されたローカルデータを読み込み、ネット接続があるときにここから最新の <code>cards.json</code> を取得します。"
        labelVersion = "現在の Mod バージョン"
        labelJsonUrl = "公開 JSON URL"
        labelRemoteUrl = "既定のリモート取得先"
        labelSourceFile = "今回の公開元ファイル"
        labelSourceName = "データソース"
        labelUpdatedAt = "ページ生成時刻 (UTC)"
        sectionUsageTitle = "匿名ユーザー推移"
        sectionUsageBody = "無料の Cloudflare Worker を配置すると、Mod は 1 日最大 1 回だけ匿名ハートビートを送信します。下の曲線は観測された累計インストール数の推移です。"
        labelUsageJson = "Telemetry JSON"
        usageImageAlt = "STS2 mod user curve"
        sectionUpdateTitle = "カードデータの更新方法"
        sectionUpdate1 = "リポジトリのルートで <code>sync-cards</code> スクリプトを実行し、最新の収集結果を <code>data/</code> に同期します。"
        sectionUpdate2 = "<code>data/cards.json</code>、<code>data/cards.fallback.json</code>、<code>data/sync_state.json</code> が更新されたことを確認します。"
        sectionUpdate3 = "変更をコミットして <code>main</code> ブランチへ push します。"
        sectionUpdate4 = "GitHub Actions がこの Pages サイトを自動で再公開し、その後 Mod が新しい <code>cards.json</code> を取得します。"
        sectionShortcut = "同期 + ローカル確認 + コミット + push をまとめて進めたい場合は、次のコマンドを使ってください。"
        sectionTip = "公開データだけを更新するなら、通常はインストーラーの再作成は不要です。新規インストールに最新のオフラインデータを同梱したい場合や、Mod 本体が変わった場合だけ再パックしてください。"
        sectionRepackTitle = "インストーラーを再作成するタイミング"
        sectionRepack1 = "Mod のコード、設定、または UI レイアウトが変わった。"
        sectionRepack2 = "新規ダウンロードで最新のオフラインデータをすぐ使えるようにしたい。"
        sectionRepack3 = "データ構造、互換方針、またはパッケージング手順が変わった。"
        sectionConfigTitle = "リモート設定例"
        sectionConfigBody = "既定の設定はすでにこのリポジトリの Pages URL を指しています。手動で書く場合は、<code>config.json</code> に次の項目を使ってください。"
    }
}

$translationsJson = $translations | ConvertTo-Json -Depth 6 -Compress
$syncCommands = @(
    'powershell -ExecutionPolicy Bypass -File .\scripts\sync-cards.ps1',
    'git add data/cards.json data/cards.fallback.json data/sync_state.json',
    'git commit -m "Update card data"',
    'git push origin main'
) -join "`n"
$shortcutCommand = 'powershell -ExecutionPolicy Bypass -File .\scripts\update-card-data.ps1'
$repackCommand = 'powershell -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1'
$configSnippet = @(
    '{',
    '  "remote_data_enabled": true,',
    "  ""remote_data_url"": ""$remoteDataUrl"",",
    '  "remote_refresh_minutes": 180,',
    '  "remote_timeout_seconds": 5',
    '}'
) -join "`n"
$defaultTitle = $translations["zh-CN"].pageTitle
$htmlContent = @"
<!DOCTYPE html>
<html lang='zh-CN'>
<head>
  <meta charset='utf-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <title>$defaultTitle</title>
  <style>
    :root { --bg: #f5f1e8; --panel: rgba(255, 253, 248, 0.94); --ink: #1d252c; --muted: #5e6b75; --line: #d9d0bf; --accent: #165d52; --accent-soft: #e2f1ed; --code: #f0ece2; --shadow: rgba(88, 71, 36, 0.10); }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: 'Segoe UI', 'Microsoft YaHei UI', 'Hiragino Sans', 'Meiryo', 'PingFang SC', 'Noto Sans JP', 'Noto Sans SC', sans-serif; background: radial-gradient(circle at top, #fff9ef 0%, var(--bg) 52%, #efe5d4 100%); color: var(--ink); line-height: 1.75; }
    main { max-width: 1080px; margin: 0 auto; padding: 40px 20px 56px; }
    .hero, .card { background: var(--panel); border: 1px solid var(--line); border-radius: 24px; box-shadow: 0 18px 48px var(--shadow); backdrop-filter: blur(8px); }
    .hero { padding: 28px; }
    .hero-head, .usage-stage-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 18px; }
    .eyebrow { display: inline-block; padding: 6px 12px; border-radius: 999px; background: var(--accent-soft); color: var(--accent); font-size: 13px; font-weight: 700; letter-spacing: 0.04em; }
    .lang-switch { display: flex; flex-wrap: wrap; gap: 10px; justify-content: flex-end; }
    .lang-button { border: 1px solid rgba(22, 93, 82, 0.22); background: rgba(255, 255, 255, 0.8); color: var(--accent); border-radius: 999px; padding: 8px 14px; font: inherit; font-size: 14px; font-weight: 700; cursor: pointer; transition: transform 120ms ease, background-color 120ms ease, color 120ms ease, box-shadow 120ms ease; }
    .lang-button:hover { transform: translateY(-1px); box-shadow: 0 8px 18px rgba(22, 93, 82, 0.12); }
    .lang-button.is-active { background: var(--accent); color: #fffdf8; box-shadow: 0 10px 20px rgba(22, 93, 82, 0.18); }
    h1 { margin: 16px 0 10px; font-size: clamp(30px, 5vw, 46px); line-height: 1.15; }
    h2 { margin: 0 0 12px; font-size: 24px; line-height: 1.25; }
    p { margin: 0 0 12px; }
    .lede, .section-copy { color: var(--muted); font-size: 16px; max-width: 52em; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 16px; margin-top: 22px; }
    .card { padding: 22px; }
    .label { display: block; color: var(--muted); font-size: 13px; margin-bottom: 6px; }
    .value { font-size: 16px; font-weight: 700; word-break: break-all; }
    .section { margin-top: 22px; }
    .section p:last-child { margin-bottom: 0; }
    ol { margin: 0; padding-left: 22px; }
    li { margin: 0 0 10px; }
    code { font-family: 'Cascadia Code', 'Consolas', monospace; background: var(--code); padding: 2px 6px; border-radius: 6px; }
    pre { margin: 12px 0 0; padding: 14px 16px; overflow-x: auto; border-radius: 14px; background: #1f252b; color: #f6f2e8; border: 1px solid #303841; }
    pre code { background: transparent; padding: 0; color: inherit; }
    a { color: var(--accent); text-decoration: none; }
    a:hover { text-decoration: underline; }
    .tip { margin-top: 16px; padding: 14px 16px; border-left: 4px solid var(--accent); border-radius: 12px; background: var(--accent-soft); }
    .chart-shell { margin-top: 18px; border-radius: 22px; overflow: hidden; border: 1px solid var(--line); background: linear-gradient(180deg, rgba(255, 250, 241, 0.96), rgba(255, 247, 231, 0.92)); }
    .chart-image { display: block; width: 100%; height: auto; }
    .usage-stage { margin-top: 24px; }
    .usage-copy { margin-bottom: 0; }
    .usage-link { display: inline-flex; align-items: center; white-space: nowrap; font-size: 14px; color: var(--muted); }
    @media (max-width: 640px) {
      main { padding: 28px 16px 40px; }
      .hero, .card { border-radius: 20px; }
      .hero { padding: 22px; }
      .hero-head, .usage-stage-head { flex-direction: column; align-items: flex-start; }
      .lang-switch { justify-content: flex-start; }
    }
  </style>
</head>
<body>
  <main>
    <section class='hero'>
      <div class='hero-head'>
        <span class='eyebrow' data-i18n-html='eyebrow'>$($translations["zh-CN"].eyebrow)</span>
        <div class='lang-switch' aria-label='Language switcher'>
          <button class='lang-button is-active' type='button' data-lang-button='zh-CN' aria-pressed='true'>中文</button>
          <button class='lang-button' type='button' data-lang-button='en' aria-pressed='false'>English</button>
          <button class='lang-button' type='button' data-lang-button='ja' aria-pressed='false'>日本語</button>
        </div>
      </div>
      <h1 data-i18n-html='heroTitle'>$($translations["zh-CN"].heroTitle)</h1>
      <p class='lede' data-i18n-html='heroBody'>$($translations["zh-CN"].heroBody)</p>
      <div class='grid'>
        <article class='card'>
          <span class='label' data-i18n-html='labelVersion'>$($translations["zh-CN"].labelVersion)</span>
          <div class='value'>$($manifest.version)</div>
        </article>
        <article class='card'>
          <span class='label' data-i18n-html='labelJsonUrl'>$($translations["zh-CN"].labelJsonUrl)</span>
          <div class='value'><a href='cards.json'>cards.json</a></div>
        </article>
        <article class='card'>
          <span class='label' data-i18n-html='labelRemoteUrl'>$($translations["zh-CN"].labelRemoteUrl)</span>
          <div class='value'><a href='$remoteDataUrl'>$remoteDataUrl</a></div>
        </article>
        <article class='card'>
          <span class='label' data-i18n-html='labelSourceFile'>$($translations["zh-CN"].labelSourceFile)</span>
          <div class='value'>$sourceFileName</div>
        </article>
        <article class='card'>
          <span class='label' data-i18n-html='labelSourceName'>$($translations["zh-CN"].labelSourceName)</span>
          <div class='value'>$sourceName</div>
        </article>
        <article class='card'>
          <span class='label' data-i18n-html='labelUpdatedAt'>$($translations["zh-CN"].labelUpdatedAt)</span>
          <div class='value'>$updatedAt</div>
        </article>
      </div>
    </section>

    <section class='section card usage-stage'>
      <div class='usage-stage-head'>
        <div>
          <h2 data-i18n-html='sectionUsageTitle'>$($translations["zh-CN"].sectionUsageTitle)</h2>
          <p class='section-copy usage-copy' data-i18n-html='sectionUsageBody'>$($translations["zh-CN"].sectionUsageBody)</p>
        </div>
        <a class='usage-link' href='$usageStatsHref' data-i18n-html='labelUsageJson'>$($translations["zh-CN"].labelUsageJson)</a>
      </div>
      <div class='chart-shell'>
        <img id='usage-chart-image' class='chart-image' src='$usageChartHref' alt='$($translations["zh-CN"].usageImageAlt)'>
      </div>
    </section>

    <section class='section card'>
      <h2 data-i18n-html='sectionUpdateTitle'>$($translations["zh-CN"].sectionUpdateTitle)</h2>
      <ol>
        <li data-i18n-html='sectionUpdate1'>$($translations["zh-CN"].sectionUpdate1)</li>
        <li data-i18n-html='sectionUpdate2'>$($translations["zh-CN"].sectionUpdate2)</li>
        <li data-i18n-html='sectionUpdate3'>$($translations["zh-CN"].sectionUpdate3)</li>
        <li data-i18n-html='sectionUpdate4'>$($translations["zh-CN"].sectionUpdate4)</li>
      </ol>
      <pre><code>$syncCommands</code></pre>
      <p class='section-copy' data-i18n-html='sectionShortcut'>$($translations["zh-CN"].sectionShortcut)</p>
      <pre><code>$shortcutCommand</code></pre>
      <div class='tip' data-i18n-html='sectionTip'>$($translations["zh-CN"].sectionTip)</div>
    </section>

    <section class='section card'>
      <h2 data-i18n-html='sectionRepackTitle'>$($translations["zh-CN"].sectionRepackTitle)</h2>
      <ol>
        <li data-i18n-html='sectionRepack1'>$($translations["zh-CN"].sectionRepack1)</li>
        <li data-i18n-html='sectionRepack2'>$($translations["zh-CN"].sectionRepack2)</li>
        <li data-i18n-html='sectionRepack3'>$($translations["zh-CN"].sectionRepack3)</li>
      </ol>
      <pre><code>$repackCommand</code></pre>
    </section>

    <section class='section card'>
      <h2 data-i18n-html='sectionConfigTitle'>$($translations["zh-CN"].sectionConfigTitle)</h2>
      <p class='section-copy' data-i18n-html='sectionConfigBody'>$($translations["zh-CN"].sectionConfigBody)</p>
      <pre><code>$configSnippet</code></pre>
    </section>
  </main>

  <script>
    (() => {
      const translations = $translationsJson;
      const defaultLang = "zh-CN";
      const storageKey = "sts2-pages-language";
      const buttons = Array.from(document.querySelectorAll("[data-lang-button]"));
      const translatedNodes = Array.from(document.querySelectorAll("[data-i18n-html]"));
      const usageImage = document.getElementById("usage-chart-image");

      function normalizeLanguage(value) {
        const language = String(value || "").toLowerCase();
        if (language.startsWith("zh")) {
          return "zh-CN";
        }
        if (language.startsWith("ja")) {
          return "ja";
        }
        if (language.startsWith("en")) {
          return "en";
        }
        return defaultLang;
      }

      function readStoredLanguage() {
        try {
          return window.localStorage.getItem(storageKey);
        }
        catch (error) {
          return "";
        }
      }

      function writeStoredLanguage(value) {
        try {
          window.localStorage.setItem(storageKey, value);
        }
        catch (error) {
        }
      }

      function applyLanguage(requestedLang) {
        const lang = Object.prototype.hasOwnProperty.call(translations, requestedLang)
          ? requestedLang
          : normalizeLanguage(requestedLang);
        const dictionary = translations[lang] || translations[defaultLang];

        translatedNodes.forEach((node) => {
          const key = node.getAttribute("data-i18n-html");
          if (Object.prototype.hasOwnProperty.call(dictionary, key)) {
            node.innerHTML = dictionary[key];
          }
        });

        if (usageImage && Object.prototype.hasOwnProperty.call(dictionary, "usageImageAlt")) {
          usageImage.alt = dictionary.usageImageAlt;
        }

        document.documentElement.lang = lang;
        document.title = dictionary.pageTitle || translations[defaultLang].pageTitle;

        buttons.forEach((button) => {
          const isActive = button.getAttribute("data-lang-button") === lang;
          button.classList.toggle("is-active", isActive);
          button.setAttribute("aria-pressed", isActive ? "true" : "false");
        });

        writeStoredLanguage(lang);
      }

      buttons.forEach((button) => {
        button.addEventListener("click", () => {
          applyLanguage(button.getAttribute("data-lang-button"));
        });
      });

      const preferredLanguage = readStoredLanguage()
        || (Array.isArray(navigator.languages) && navigator.languages.length > 0 ? navigator.languages[0] : navigator.language)
        || defaultLang;
      applyLanguage(preferredLanguage);
    })();
  </script>
</body>
</html>
"@

Set-Content -LiteralPath (Join-Path $OutputDir "index.html") -Value $htmlContent -Encoding UTF8
Set-Content -LiteralPath (Join-Path $OutputDir ".nojekyll") -Value "" -Encoding UTF8

Write-Host "Built GitHub Pages data output: $OutputDir"
