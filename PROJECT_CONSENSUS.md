# 项目底层共识

> 面向 Agent / 维护者的内部说明，不替代对外 `README.md`。  
> 目标是减少重复判断、重复踩坑、重复试错。

## 1. 这份文档是干什么的

- 用来同步这个仓库的工程目标、边界、默认做法和验收标准。
- 当公开文档、旧 handoff、运行时状态互相冲突时，先看代码和最新运行产物，再看旧文档。
- 这不是产品宣传页，而是给后续 Agent 接手时快速建立“底层共识”的。

## 2. 工程目的

这个仓库的核心目标很简单：

1. 给《Slay the Spire 2》做一个可安装的 Mod。
2. 在游戏内卡牌悬浮提示和检视界面里直接显示小黑盒卡牌统计。
3. 把“小黑盒鉴权 / 页面抓取 / 数据同步”放在 Mod 外部，Mod 只消费本地 JSON 或 GitHub Pages 上的 JSON。
4. 保证用户安装后尽量“开箱即用”，不要求普通玩家理解抓取链路、浏览器登录态或手动同步。

一句话概括：

> 这是一个“游戏内展示卡牌社区统计”的产品，不是一个“把小黑盒接口硬塞进 Mod”的工程。

## 3. 用户偏好

### 3.1 终端玩家偏好

- 主要用户是 Windows + Steam 的《Slay the Spire 2》玩家。
- 中文体验优先，英文只是兼容项，不是主战场。
- 安装方式优先安装器，其次便携包，再次才是手动拷贝目录。
- 使用方式应尽量零学习成本：安装后进入游戏，鼠标悬停即可看到数据。
- 数据是“社区统计参考”，不是绝对真理，文案必须保留“仅供参考”的语义。
- 不希望边玩边切网页，不希望额外手动登录、手动导入、手动刷新。

### 3.2 项目 owner / 维护偏好

- 实用主义优先：稳定可交付 > 形式上的优雅架构。
- Windows-first，PowerShell 是一等公民。
- 优先保留“一条命令能跑通”的脚本链路。
- 数据更新最好能独立于 Mod 二进制发布，不要每次更新数据都强制重打安装包。
- 能离线回退就离线回退，不把线上接口可用性变成用户的硬依赖。

## 4. 仓库结构共识

### 4.1 目录职责

| 路径 | 作用 |
| --- | --- |
| `src/` | Mod 主体，C# / Harmony / Godot UI 逻辑 |
| `collector/` | 真正访问小黑盒的采集器，Playwright + CDP + 真浏览器登录态 |
| `syncer/` | 将 collector 的 `cards.snapshot.json` 转成 Mod 使用的 `data/cards.json` |
| `scripts/` | Windows 工作流脚本：同步、部署、安装、打包、发布辅助 |
| `data/` | 仓库内当前可用的卡牌数据、fallback 数据、同步状态 |
| `sample_data/` | 最小样例数据，作为最后兜底 |
| `pack_assets/` | 打入 `.pck` 的静态资源 |
| `installer/` | Inno Setup 安装器脚本 |
| `dist/` | 构建产物 |

### 4.2 模块边界

- `collector/` 负责“拿到数据”。
- `syncer/` 负责“把采集结果整理成 Mod 可读格式”。
- `src/` 负责“把数据展示到游戏 UI 里”。
- `scripts/` 负责“把上面几段串起来”。

不要混淆这几个边界：

- `syncer/` 不是抓取器，它默认不直接请求小黑盒。
- Mod 不是抓取器，Mod 只读本地缓存和 GitHub Pages 数据。
- 真正带登录态、带浏览器环境的链路在 `collector/`。

## 5. 当前真实状态（按仓库内最新产物）

以下结论基于仓库里的最新运行产物，而不是旧问题单：

- `data/sync_state.json` 显示最近一次成功同步时间是 `2026-03-13T11:36:44.397Z`，状态为 `success`，卡牌数 `574`。
- `collector/output/xhh/manifest.json` 显示 `status = "ok"`，`stage = "full-sync"`，最近成功快照时间也是 `2026-03-13T11:36:44.397Z`。
- 这说明当前仓库内已经存在一份成功导出的完整卡牌数据，不再只是 sample 级别。

重要提醒：

- `OPEN_ISSUES.md` 里记录的是 `2026-03-13` 时的一段排障结论，内容里写了“登录未打通 / fallback 只有 sample”。  
  这和当前仓库产物不一致，说明该文件已经部分过时。
- 后续如果文档冲突，优先级应为：

1. 代码
2. `data/`、`collector/output/xhh/` 这类最新运行产物
3. `README.md`
4. `OPEN_ISSUES.md`、旧 handoff

## 6. 主链路共识

### 6.1 数据链路

主链路是：

1. `collector/tools/xhh-sts2-sync.mjs` 连接真实浏览器的 CDP，会话里必须已有小黑盒登录态。
2. 采集器输出：
   - `cards.snapshot.json`
   - `manifest.json`
3. `syncer/sync-cards.mjs` 读取 collector 输出，转换为：
   - `data/cards.json`
   - `data/cards.fallback.json`
   - `data/sync_state.json`
4. 部署或安装时，这些文件会被复制到 Mod 目录。
5. 游戏内 Mod 优先读本地 `cards.json`，必要时回退到 fallback 或 sample。

### 6.2 游戏内展示链路

1. `src/ModEntry.cs` 初始化配置、仓库、自动更新器，并打 Harmony 补丁。
2. `src/HoverTipPatches.cs` 给原生悬浮提示追加统计卡片。
3. `src/HoverStatsTipBuilder.cs` 把卡牌数据整理成展示 payload。
4. `src/HoverStatsTooltipRenderer.cs` 把 payload 渲染成自定义面板。
5. `src/InspectScreenPatches.cs` 处理检视界面，因为该场景不走普通 hover 注入逻辑。

### 6.3 远程更新链路

- Mod 支持从 `config.json` 指定的 `remote_data_url` 拉取远程 `cards.json`。
- 当前仓库默认配置指向 GitHub Pages：  
  `https://xmeowchan.github.io/STS2_Card_Stats/cards.json`
- 远程刷新是后台增量优化，不应成为用户进入游戏的前置条件。

## 7. 数据与匹配规则

### 7.1 数据文件优先级

`CardStatsRepository` 当前的加载优先级是：

1. `cards.json`
2. `cards.fallback.json`
3. 打进 `.pck` 的 `res://HeyboxCardStatsOverlay/data/cards.fallback.json`
4. `cards.sample.json`

结论：

- 任何改动都不能破坏 fallback 链路。
- 即使线上拉取失败、同步失败、安装目录缺少 live 数据，Mod 也应该尽量给出可解释的降级体验。

### 7.2 卡牌 ID 匹配规则

当前匹配不是只看一个字段，而是多候选兜底：

- `requestedId`
- `card.Id`
- `card.CanonicalInstance.Id`
- `card.GetType().Name`
- PascalCase 变体
- `alt_ids`
- `name_en`
- `name_cn`

另外还有一个细节：

- 末尾的 `+` 会被去掉再匹配，所以升级卡不会因为 `+` 后缀直接失配。

### 7.3 排名 / 相对值规则

- UI 中展示的“职业内胜率 / 抓取”并不完全依赖接口原始 rank。
- `CardStatsRepository` 会基于当前载入数据按 `category` 本地重算相对排名和百分位。
- 这意味着如果数据集不完整，职业内相对排名也会跟着偏。

## 8. 工程细节

### 8.1 技术栈

- Mod：.NET 9 + C# + Harmony
- 运行时 UI：Godot / STS2 原生节点体系
- 数据采集：Node.js + Playwright
- 工作流脚本：PowerShell
- 安装器：Inno Setup

### 8.2 构建与部署

常用脚本：

- 部署到本地游戏目录：`powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1`
- 同步数据：`powershell -ExecutionPolicy Bypass -File .\scripts\sync-cards.ps1`
- 同步数据并提交：`powershell -ExecutionPolicy Bypass -File .\scripts\update-card-data.ps1`
- 构建安装器：`powershell -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1`
- 构建便携包：`powershell -ExecutionPolicy Bypass -File .\scripts\build-portable-package.ps1`
- 本地发版打包 / 上传辅助：`powershell -ExecutionPolicy Bypass -File .\scripts\publish-release.ps1`
- 启动游戏前先同步：`powershell -ExecutionPolicy Bypass -File .\scripts\launch-with-sync.ps1`

### 8.3 PCK 兼容性

这是高频坑，必须单独强调：

- `project.godot` 里声明的是 `4.6` feature。
- 但脚本会在打包后强制把 `.pck` header 改成 Godot `4.5.x` 可接受的格式。
- `scripts/deploy.ps1` 和 `scripts/build-installer-payload.ps1` 都显式调用了 `Set-PckCompatibilityHeader`。
- 如果你自己重打了 `.pck` 却没有 patch header，游戏可能直接不认这个 Mod。

### 8.4 配置文件的真实语义

还有一个容易忽略的点：

- `src/ModConfig.cs` 里的代码默认值中，`remote_data_enabled` 和 `mod_update_enabled` 默认是 `false`。
- 但仓库根目录 `config.json` 里，这两个开关当前是 `true`。

这意味着：

- 运行时表现更依赖“随包下发的 `config.json`”，而不是代码里的默认值。
- 如果你漏拷贝了根目录 `config.json`，用户得到的是“远程数据关闭、自动更新关闭”的退化行为。

### 8.5 自动更新

- `src/ModAutoUpdater.cs` 会读取 GitHub release 的 latest。
- 它偏好下载带 `.zip` 的 portable 资产。
- 如果 release 资产命名或结构变了，自动更新就会退化甚至失效。

结论：

- 如果要维持自动更新能力，release 里必须持续提供可识别的 portable zip。

#### 8.5.1 发布侧 POST / 上传流程

- 自动更新依赖的不是安装器 `.exe`，而是 GitHub Release 里的 portable zip。
- 当前推荐发布入口是 `scripts/publish-release.ps1`。
- 这个脚本会先构建：
  - `HeyboxCardStatsOverlay-Setup-x.y.z.exe`
  - `HeyboxCardStatsOverlay-portable-x.y.z.zip`
  - release notes
- 如果本机装了 `gh`，脚本会用 `gh release create / upload`。
- 如果没装 `gh`，但环境里有 `GITHUB_TOKEN` / `GH_TOKEN` / `GITHUB_RELEASE_TOKEN`，脚本会直接走 GitHub REST API：
  1. 读取 `mod_manifest.json` 里的版本号并生成 `v<version>` tag 名。
  2. `GET /repos/{owner}/{repo}/releases/tags/{tag}` 检查 release 是否已存在。
  3. 不存在则 `POST /repos/{owner}/{repo}/releases` 创建 release。
  4. 已存在则 `PATCH /repos/{owner}/{repo}/releases/{id}` 更新标题、正文、prerelease 状态。
  5. 删除同名旧附件。
  6. 向 release 的 `upload_url` 重新上传 installer exe 和 portable zip。
- 对自动更新来说，portable zip 是强依赖；installer exe 主要服务首次安装和手动升级。
- `.github/workflows/release-self-hosted.yml` 是同一套逻辑的 CI 封装，但依赖 Windows self-hosted runner，因为构建过程要用到本机的 STS2 依赖、Godot 和 Inno Setup。

#### 8.5.2 玩家侧下载 / 替换流程

- 玩家第一次必须手动安装一个带更新器的版本；当前是 `0.2.3` 及以后。
- Mod 启动时，`src/ModAutoUpdater.cs` 会：
  1. 读取本地 `mod_manifest.json` 版本。
  2. 请求 GitHub latest release。
  3. 从 release 资产里挑选 portable zip。
  4. 比较远端版本与本地版本。
- 如果远端更高：
  1. 把 portable zip 下载到 Mod 目录下的 `_update_runtime/downloads/`。
  2. 解压到 `_update_runtime/staging/<version>/`。
  3. 校验解压结果里是否存在有效的 `mod_manifest.json`、`HeyboxCardStatsOverlay.dll`、`HeyboxCardStatsOverlay.pck`。
  4. 生成并启动一个外部 PowerShell 应用脚本。
- 之所以要起外部 PowerShell，而不是直接在游戏进程里覆盖，是因为：
  - 游戏运行时 DLL / PCK 正在被占用；
  - 直接覆盖很容易失败或把安装目录留在半更新状态。
- 外部 PowerShell 脚本会：
  1. 等待游戏主进程退出。
  2. 把 staging 目录内容复制回 Mod 安装目录。
  3. 保留玩家现有的 `config.json`，避免把玩家自己的开关和参数覆盖掉。
  4. 记录 `_update_runtime/last-applied-update.json`。
  5. 如果失败，则写 `_update_runtime/update-error.log`。
- 这条链路的验收标准不是“游戏运行中立刻变成新版本”，而是“本次运行完成下载，下次启动前已在退出阶段完成替换”。

#### 8.5.3 不要破坏的约束

- 不要把 release 资产名改成完全不可识别的格式，至少要保留 portable zip 这一类稳定产物。
- 不要只发 installer exe 而不发 portable zip。
- 不要让更新器覆盖玩家本地 `config.json`。
- 不要把“自动更新失败”设计成“Mod 无法启动”；失败时应该退化为继续跑本地已安装版本。

## 9. 已知坑

### 9.1 文档可能过时

- `OPEN_ISSUES.md` 是“历史问题记录”，不是当前真相。
- `collector/AGENT_HANDOFF.md` 和调研文档也可能只代表当时阶段。

### 9.2 PowerShell 看中文可能乱码

- 直接 `Get-Content README.md` 在某些终端编码下会乱码。
- 读中文 Markdown 时，优先用明确的 UTF-8 方式。

### 9.3 大目录搜索容易被 `node_modules/` 污染

- `collector/` 和 `syncer/` 下都可能带依赖目录。
- 搜索时要主动避开 `node_modules/`，否则会被海量无关文件淹没。

### 9.4 检视界面和普通 hover 不是一套路径

- 普通悬浮提示靠 `HoverTipPatches.cs` 注入。
- 检视界面靠 `InspectScreenPatches.cs` 单独补。
- 改一处不代表另一处自然跟着好。

### 9.5 某些场景是故意不显示统计的

当前逻辑会主动跳过一些场景，例如：

- 战斗中的手牌
- 部分战斗牌堆浏览
- 某些预览牌容器

这是刻意控制噪音，不是单纯 bug。改动前先确认产品意图。

### 9.6 采集器和同步器不要混着修

- 采集失败，先看 `collector/output/xhh/manifest.json`
- 转换失败，先看 `data/sync_state.json`
- Mod 展示失败，再看 `src/`

不要一上来就在三个层面同时大改。

## 10. 规则

### 10.1 产品规则

- 不把小黑盒登录、鉴权、Cookie、签名算法直接塞进 Mod。
- 不把“需要用户手动维护浏览器登录态”当作普通玩家使用前提。
- 不删除“社区统计，仅供参考”的提示语义。
- 不为了显示更多信息牺牲主卡牌 UI 的可读性。

### 10.2 工程规则

- 优先修主链路，不先做重构。
- 优先补脚本和自动化，不增加人工步骤。
- 数据更新和二进制发布尽量解耦。
- 任何影响安装、部署、打包的改动，都要考虑 `deploy / installer / portable` 三条链路是否一起受影响。
- 任何影响数据结构的改动，都要同时考虑：
  - collector 输出
  - syncer 转换
  - Mod 读取
  - fallback / sample 兼容

### 10.3 Agent 协作规则

- 先读现状，不要默认仓库文档永远是最新的。
- 先看运行产物，再决定问题属于采集、转换、展示、打包中的哪一层。
- 仓库可能长期带未提交改动，除非用户明确要求，否则不要回滚别人改动。
- 新增说明时优先写清“为什么这么做”，而不是只记“怎么点按钮”。

## 11. 建议的任务切分方式

如果后续任务来了，优先这样归类：

### 11.1 UI / 游戏内显示问题

重点看：

- `src/HoverTipPatches.cs`
- `src/HoverStatsTipBuilder.cs`
- `src/HoverStatsTooltipRenderer.cs`
- `src/InspectScreenPatches.cs`

### 11.2 数据同步问题

重点看：

- `collector/tools/xhh-sts2-sync.mjs`
- `collector/tools/xhh-collector-common.mjs`
- `collector/output/xhh/manifest.json`
- `syncer/sync-cards.mjs`
- `data/sync_state.json`

### 11.3 打包 / 安装问题

重点看：

- `scripts/deploy.ps1`
- `scripts/build-installer-payload.ps1`
- `scripts/build-installer.ps1`
- `scripts/build-portable-package.ps1`
- `scripts/Sts2InstallHelpers.ps1`
- `installer/HeyboxCardStatsOverlay.iss`

## 12. 验收标准

一个改动至少应该回答下面这些问题：

1. 普通玩家是否仍然能“安装后直接用”？
2. 同步失败时是否仍然有 fallback / sample 兜底？
3. 是否破坏了 `deploy`、安装器、便携包、GitHub Pages 其中任一条链路？
4. 是否把小黑盒登录耦合进了 Mod 本体？
5. 是否让文档、脚本、产物之间的关系变得更清晰，而不是更隐晦？

---

如果后续要继续补这份文档，优先补两类信息：

- 新的稳定工程规则
- 已被验证过、且会反复踩的坑

不要把一次性的临时调试日志直接堆进来。
