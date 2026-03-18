<p align="center">
  <a href="README.md"><img alt="简体中文" src="https://img.shields.io/badge/Language-ZH-2ea043"></a>
  <a href="README.en.md"><img alt="English" src="https://img.shields.io/badge/Language-EN-4c8eda"></a>
  <a href="README.ja.md"><img alt="日本語" src="https://img.shields.io/badge/Language-JA-f4c542"></a>
</p>

<p align="center">
  <img src="pack_assets/HeyboxCardStatsOverlay/mod_image.png" alt="STS2 Card Stats Overlay" width="160">
</p>

<h1 align="center">STS2 卡牌数据悬浮窗</h1>

<p align="center">
  把社区卡牌统计直接叠进《Slay the Spire 2》的选牌、查卡和构筑流程里。
</p>

<p align="center">
  悬停即看胜率、抓取率、略过率、样本量和职业内排名。
</p>

<p align="center">
  <a href="https://github.com/XMeowchan/STS2_Card_Stats/releases"><strong>下载最新版</strong></a>
  ·
  <a href="https://github.com/XMeowchan/STS2_Card_Stats/releases">查看 Releases</a>
</p>

<p align="center">
  <img alt="release" src="https://img.shields.io/github/v/release/XMeowchan/STS2_Card_Stats?label=Release&color=2ea043">
  <img alt="game" src="https://img.shields.io/badge/Game-Slay%20the%20Spire%202-f4c542">
  <img alt="platform" src="https://img.shields.io/badge/Platform-Windows%20%7C%20Steam-4c8eda">
</p>

<p align="center">
  <a href="#功能截图">功能截图</a>
  ·
  <a href="#当前版本亮点">版本亮点</a>
  ·
  <a href="#安装方法">安装方法</a>
  ·
  <a href="#怎么使用">使用方式</a>
  ·
  <a href="#常见问题">常见问题</a>
</p>

<table>
  <tr>
    <td align="center" width="33%">
      <strong>悬停即看</strong>
      <br>
      卡牌旁直接显示关键统计
    </td>
    <td align="center" width="33%">
      <strong>不切网页</strong>
      <br>
      选牌、查卡、构筑都在游戏内完成
    </td>
    <td align="center" width="33%">
      <strong>只做参考</strong>
      <br>
      不改卡牌效果、不碰战斗流程与存档
    </td>
  </tr>
</table>

## 功能截图

下面这几张图分别展示了悬停统计、卡牌库排序和单卡详情面板。

<table>
  <tr>
    <td align="center" width="50%">
      <img src="docs/images/readme-feature-hover-stats.png" alt="悬停卡牌时显示统计数据与关键词解释" width="100%">
      <br>
      <strong>悬停直接看数据</strong>
      <br>
      在卡牌提示旁直接显示胜率、抓取率、略过率和职业内排名。
    </td>
    <td align="center" width="50%">
      <img src="docs/images/readme-feature-library-sort.png" alt="卡牌库支持按抓取率和胜率排序" width="308">
      <br>
      <strong>卡牌库快速排序</strong>
      <br>
      支持按抓取率、胜率和拼音顺序切换，找卡更快。
    </td>
  </tr>
  <tr>
    <td align="center" colspan="2">
      <img src="docs/images/readme-feature-card-detail.png" alt="单卡详情页显示完整统计面板" width="100%">
      <br>
      <strong>单卡详情页也能看</strong>
      <br>
      在聚焦查看单卡时同样保留统计面板，方便比较与决策。
    </td>
  </tr>
</table>

## 当前版本亮点

当前 README 展示基于 `v0.2.4`：

- 卡牌库支持按抓取率 / 胜率排序，定位强卡更快
- README 展示匿名用户量曲线，项目增长趋势更直观
- 安装包、便携包与发布脚本共用同一套构建流程，发版更稳定

## 用户量曲线

<p align="center">
  <img src="https://xmeowchan.github.io/STS2_Card_Stats/users-history.svg?v=16710ce" alt="STS2 Mod 用户量曲线" width="100%">
</p>

> 这条曲线来自 Mod 的匿名日心跳：每个安装实例每天最多上报一次，只统计随机安装 ID，不采集 Steam 账号、用户名或硬件指纹。

## 这是什么

这是一个《Slay the Spire 2》Mod，会在卡牌悬浮提示或单卡详情页旁边追加统计面板，让你在游戏里直接参考社区数据做判断。

你可以直接看到：

- 胜率
- 抓取率
- 略过率
- 抓取次数、胜局数、败局数和更新时间
- 职业内相对排名
- 卡牌库内按抓取率 / 胜率快速排序

这些数据都属于社区统计，仅供参考，不会改动卡牌本身效果、战斗流程或存档。

## 它能带来什么帮助

| 使用场景 | 你会得到什么 |
| --- | --- |
| 选牌时 | 不用反复切网页，直接判断一张卡值不值得拿 |
| 构筑时 | 可以快速对比抓取率、胜率和职业内排名 |
| 查卡时 | 在卡牌库和单卡详情页都能保持同一套参考面板 |

## 适合谁

如果你属于下面任意一种情况，这个 Mod 会比较合适：

- 想在选牌时多一个直观的数据参考
- 不想边打边切网页或查表
- 希望在卡牌库里更快筛选高优先级卡牌
- 想把社区统计作为构筑时的辅助信息

## 安装方法

推荐直接使用安装包，最省事。

1. 打开 [Releases](https://github.com/XMeowchan/STS2_Card_Stats/releases)
2. 下载最新的 `HeyboxCardStatsOverlay-Setup-版本号.exe`
3. 先关闭游戏
4. 双击运行安装包
5. 安装完成后启动《Slay the Spire 2》

安装程序会自动把 Mod 放进游戏的 `mods` 文件夹。

如果你对安装包弹窗比较敏感，也可以直接下载 `portable.zip`，按下面的手动安装方式解压复制。

## 手动安装

如果你拿到的是解压后的文件，而不是安装器，也可以手动安装：

1. 找到《Slay the Spire 2》游戏目录下的 `mods` 文件夹
2. 把整个 `HeyboxCardStatsOverlay` 文件夹复制进去
3. 启动游戏

最终目录类似：

```text
Slay the Spire 2\mods\HeyboxCardStatsOverlay
```

## 安全说明

- 当前发布的安装包还没有使用商业代码签名证书，所以 Windows 或浏览器可能会提示“未知发布者”或“此文件不常见”。这类提示更常见于“信誉不足”，不等于已经确认有病毒。
- 本项目的公开发布渠道只有这个仓库的 [GitHub Releases](https://github.com/XMeowchan/STS2_Card_Stats/releases)。如果你是从别的网盘、群文件或二次转载处下载，建议改为从 Releases 重新获取。
- 安装器本身只负责定位《Slay the Spire 2》目录，并把 `HeyboxCardStatsOverlay` 文件复制到游戏的 `mods` 文件夹，不会安装系统服务、计划任务或开机自启。
- 如果你不想运行安装器，可以直接使用 `portable.zip` 手动安装；手动安装完成后的目标目录就是 `Slay the Spire 2\mods\HeyboxCardStatsOverlay`。
- Mod 默认会联网做三件事：拉取卡牌统计数据、检查 GitHub Releases 更新，以及发送一条匿名心跳用于统计活跃安装量。
- 如果你想关闭联网行为，可以编辑 Mod 目录里的 `config.cfg`，把 `remote_data_enabled`、`mod_update_enabled`、`telemetry_enabled` 改成 `false`。

## 怎么使用

安装成功后，不需要额外操作：

1. 进入游戏
2. 把鼠标悬停到卡牌上
3. 在卡牌旁边查看统计面板

## 常见问题

### 下载后提示“有风险”或“未知发布者”

这是因为安装包目前没有商业代码签名证书，Windows/浏览器可能把它归类为“未知发布者”或“不常见下载”。

如果你介意这类提示，建议这样处理：

- 只从本仓库的 GitHub Releases 下载
- 优先使用 `portable.zip` 手动安装
- 自己用 Windows 安全中心或常用杀毒软件再扫描一遍
- 不放心就直接查看源码，或等待后续补充正式签名

### 这个 Mod 会上传什么数据

- 默认会从远端拉取卡牌统计数据
- 默认会去 GitHub Releases 检查更新
- 默认每天发送一次匿名心跳，只包含匿名安装 ID、Mod 版本、平台、系统版本和上报时间

### 安装后没看到统计面板

可以先检查这几项：

- 确认游戏已经完全重启
- 确认 Mod 已安装到 `Slay the Spire 2\mods\HeyboxCardStatsOverlay`
- 如果你刚更新过版本，建议重启一次游戏再看

### 某些卡牌没有数据

这通常不是安装问题，而是当前数据里暂时没有收录这张卡。

### 我需要自己手动更新数据吗

普通玩家不需要。安装好后直接用就行。

### 用户量曲线会收集什么

只会发送匿名安装 ID、Mod 版本、平台和上报时间，用来统计累计用户数和日活。

如果你不想参与匿名统计，可以把 `config.cfg` 里的 `telemetry_enabled` 改成 `false`。
