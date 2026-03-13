# 杀戮尖塔2 小黑盒卡牌数据库调研记录

更新时间：2026-03-12  
工作目录：`E:\playwrightTest`

## 目标

为后续制作《杀戮尖塔2》内置 Mod 做资料沉淀，重点确认：

- 小黑盒卡牌数据库的真实入口
- 页面背后的数据接口
- 能否抓到每张卡的胜率、选取率、略过率
- 这些数据是否适合直接在 Mod 内调用
- 更稳妥的集成方式是什么

## 结论摘要

- 小黑盒“卡牌数据库”不是本地 App 私有数据库，而是远端 WebView 页面。
- `appid=558` 对应的小程序就是《杀戮尖塔2》的卡牌数据库。
- 页面背后确实存在可用的远端接口，已经能返回逐卡统计数据。
- 核心统计字段已经确认可拿到：`win_rate`、`pick_rate`、`skip_rate`、`times_picked`、`times_skipped`、`times_won`、`times_lost`、排名字段等。
- 直接离开页面环境裸调接口时，会遇到 `login` / `relogin`，说明不仅有 `hkey/_time/nonce` 参数，还有登录态依赖。
- 因此，不建议把小黑盒鉴权逻辑直接塞进游戏 Mod。更稳的方式是：
  - 单独做一个同步器
  - 由同步器在浏览器环境里打开小黑盒页面并拦截接口响应
  - 导出成本地 `json`
  - Mod 只读取本地 `json`

## 入口定位

用户提供的分享页：

- <https://web.xiaoheihe.cn/tools/common_share?appid=558&share_bg_color=0160FF&is_v2=true>

该页背后请求：

- `GET https://api.xiaoheihe.cn/game/mini_app/share_detail?mini_app_id=558&is_v2=true`

返回结果中有关键字段：

- `mini_program_id = 558`
- `search_info.desc = "卡牌数据库"`
- `protocol.webview.url = "https://web.xiaoheihe.cn/game/slay_the_spire/database_v2/card_database"`

也就是说，分享页本质只是一个壳，真实页面是：

- <https://www.xiaoheihe.cn/game/slay_the_spire/database_v2/card_database>

## 卡牌数据库页面

页面地址：

- <https://www.xiaoheihe.cn/game/slay_the_spire/database_v2/card_database>

页面可见列：

- 卡牌名
- 胜率
- 选取率
- 略过率

我在页面上直接看到的样例：

- `祭品`：胜率 `64.5%`，选取率 `62.4%`，略过率 `37.6%`

## 卡牌列表接口

页面真实请求：

- `GET https://api.xiaoheihe.cn/game/slaythespire/v2/card/list`

典型查询参数：

- `offset`
- `limit`
- `q`
- `card_category`
- `card_type`
- `card_rarity`
- `sort_by`
- `sort_order`
- `app`
- `heybox_id`
- `os_type`
- `x_app`
- `x_client_type`
- `x_os_type`
- `x_client_version`
- `version`
- `hkey`
- `_time`
- `nonce`

页面默认请求示例语义：

- `card_category=ironclad`
- `card_type=`
- `card_rarity=`
- `sort_by=win_rate`
- `sort_order=1`

### 已确认返回字段

`result.card_stat_list[]` 中至少包含：

- `card_id`
- `card_icon`
- `card_name`
- `times_lost`
- `times_picked`
- `pick_rate`
- `times_skipped`
- `skip_rate`
- `times_won`
- `win_rate`
- `win_rate_rank`
- `pick_rate_rank`

### 抓到的真实样例

以 `Offering / 祭品` 为例：

```json
{
  "card_id": "Offering",
  "card_icon": "https://heyboxbj.max-c.com/slay_the_spire_2/cards/ironclad_offering.png",
  "times_lost": 43574,
  "times_picked": 108556,
  "pick_rate": "62.4",
  "times_skipped": 65527,
  "skip_rate": "37.6",
  "times_won": 79275,
  "win_rate": "64.5",
  "card_name": "祭品",
  "win_rate_rank": 1,
  "pick_rate_rank": 2
}
```

注意：

- 页面卡面上显示的“胜率排名”与接口里某些字段在不同页面有过口径差异，后续做同步时建议以接口实际返回为准，不要只信 UI 文案。

## 页面筛选项

通过拦截 `card/list` 的响应，确认了 `filter_list`：

### `card_category`

- `ironclad`
- `silent`
- `regent`
- `necrobinder`
- `defect`
- `colorless`
- `ancient`
- `else`

### `card_type`

- `""` 全部分类
- `attack`
- `skill`
- `power`
- `else`

### `card_rarity`

- `""` 全部稀有度
- `common`
- `uncommon`
- `rare`
- `else`

## 单卡详情页

列表页点击单卡后，前端尝试打开：

- <https://www.xiaoheihe.cn/game/slay_the_spire/match_record_v2/card_detail?card_id=Offering>

页面背后接口：

- `GET https://api.xiaoheihe.cn/game/slaythespire/v2/card/detail`

参数核心是：

- `card_id=Offering`

### 已确认返回结构

`result` 至少包含：

- `card_info`
- `card_stat`
- `card_match_info_list`

### `card_info` 样例

```json
{
  "id": "Offering",
  "name": "祭品",
  "category": "ironclad",
  "card_type": "skill",
  "card_rarity": "rare",
  "cost": 0,
  "magic": 3,
  "exhaust": true,
  "retain": false,
  "innate": false,
  "is_ethereal": false,
  "is_upgraded": false,
  "desc": "失去6点生命。\\n获得2 点 能量。\\n抽3张牌。",
  "upgrade_info": {
    "desc": "失去6点生命。\\n获得2 点 能量。\\n抽5张牌。",
    "magic": 5
  },
  "cdn_url": "https://heyboxbj.max-c.com/slay_the_spire_2/cards/ironclad_offering.png"
}
```

### `card_stat` 样例

```json
{
  "card_id": "Offering",
  "card_name": "祭品",
  "times_lost": 43574,
  "times_picked": 108556,
  "pick_rate": "62.4",
  "times_skipped": 65527,
  "skip_rate": "37.6",
  "times_won": 79275,
  "win_rate": "64.5",
  "win_rate_rank": 83,
  "pick_rate_rank": 10
}
```

### `card_match_info_list` 样例特征

我抓到的第一条对局样本字段包括：

- `match_id`
- `start_time`
- `card_icon_list`
- `is_win`
- `ascension_level`
- `duration`
- `player_name`
- `player_icon`
- `deck_size`

这意味着单卡详情页不只是静态卡面信息，还混入了“高阶对局样本”。

## 战绩页相关接口

战绩主页脚本中还发现了这些接口路径：

- `/game/slaythespire/v2/create_archive_analyze_task`
- `/game/slaythespire/v2/queue_process`
- `/game/slaythespire/v2/save/overview`

推测用途：

- 存档上传或解析任务创建
- 任务轮询
- 战绩概览

这一块本次没有继续深挖到可直接复用的稳定流程，但它更像“玩家存档解析”链路，不是卡牌数据库的主数据源。

## 请求签名与鉴权情况

前端脚本里确认有两层东西：

### 1. Web 参数生成

前端会自动给请求补上：

- `hkey`
- `_time`
- `nonce`
- `version=999.0.4`

并且 `hkey` 不是常量，而是根据：

- 请求路径
- 当前时间
- `nonce`

算出来的。

### 2. 登录态依赖

即便把 `hkey/_time/nonce` 补齐，离开页面环境直接请求时，仍然可能收到：

- `status = "login"`
- `status = "relogin"`

这说明接口还依赖：

- Cookie
- 站内登录态
- 可能还有额外 token 或页面环境里注入的状态

因此：

- 不能把它简单看成“只要复现 hkey 就能裸调”
- 也不建议在 Mod 里直接硬编码小黑盒 Cookie 或登录逻辑

## 为什么推荐“同步器 + 本地 JSON”

推荐架构：

1. 单独做一个同步脚本
2. 用浏览器自动化打开小黑盒页面
3. 拦截 `/game/slaythespire/v2/card/list` 和 `/game/slaythespire/v2/card/detail`
4. 把结果整理为本地 `json`
5. Mod 只读取本地 `json`

优势：

- 不把小黑盒鉴权耦合进游戏
- 页面自己发请求，签名和登录态都走现成逻辑
- 接口将来若微调，请求也更容易跟着页面行为适配
- 更适合离线缓存和版本管理

## 建议导出的数据结构

建议把同步结果整理成类似下面的结构：

```json
{
  "source": "xiaoheihe",
  "game": "slay_the_spire_2",
  "updated_at": "2026-03-12T10:25:00Z",
  "categories": ["ironclad", "silent", "regent", "necrobinder", "defect", "colorless", "ancient", "else"],
  "cards": [
    {
      "id": "Offering",
      "name_cn": "祭品",
      "category": "ironclad",
      "type": "skill",
      "rarity": "rare",
      "cost": 0,
      "icon_url": "https://heyboxbj.max-c.com/slay_the_spire_2/cards/ironclad_offering.png",
      "stats": {
        "win_rate": 64.5,
        "pick_rate": 62.4,
        "skip_rate": 37.6,
        "times_won": 79275,
        "times_lost": 43574,
        "times_picked": 108556,
        "times_skipped": 65527,
        "win_rate_rank": 83,
        "pick_rate_rank": 10
      },
      "desc": "失去6点生命。获得2点能量。抽3张牌。",
      "upgrade_desc": "失去6点生命。获得2点能量。抽5张牌。"
    }
  ]
}
```

## 下个 Session 建议直接做的事

### 方案 A：做同步器

目标：

- 自动抓全卡牌列表
- 自动按 `card_id` 抓详情
- 导出 `cards.json`

建议技术路线：

- Playwright
- 登录小黑盒后进入卡牌数据库页
- 监听网络响应
- 直接解析 JSON，不走页面 DOM 抠文本

### 方案 B：做 Mod 数据层

目标：

- 先不碰小黑盒请求
- 先约定 Mod 的数据格式和读取逻辑
- 等同步器准备好后直接替换输入文件

适合先做：

- 本地缓存格式
- 热更新
- UI 排序和筛选
- 卡牌详情展示

## Playwright 抓取思路

核心思路不是“模拟点点点”，而是“拦响应”。

### 列表页

- 打开：`https://www.xiaoheihe.cn/game/slay_the_spire/database_v2/card_database`
- 等待响应 URL 包含：`/game/slaythespire/v2/card/list`
- 直接取响应 JSON

### 详情页

- 打开：`https://www.xiaoheihe.cn/game/slay_the_spire/match_record_v2/card_detail?card_id=<CARD_ID>`
- 等待响应 URL 包含：`/game/slaythespire/v2/card/detail`
- 直接取响应 JSON

### 注意事项

- 页面里有视频背景，有时会挡住点击，不要依赖视觉点击流程。
- 直接拼详情页 URL 比从列表页点进去更稳。
- 裸请求会遇到 `login/relogin`，优先在已登录浏览器上下文里拦接口。

## 风险与不确定点

- 小黑盒可能后续改接口路径或字段名。
- `win_rate_rank` / `pick_rate_rank` 的页面展示和接口字段可能出现口径不一致。
- 某些卡牌 `times_picked=0` 但 `win_rate` 非 0，说明他们的统计口径不一定等于“只看被主动选取的局”。
- 社区里已经有人反馈抓取率口径有问题或疑似 bug，因此做 Mod 时建议把这些数据标注为“社区统计，仅供参考”。

## 已确认的重要 URL

- 分享页：<https://web.xiaoheihe.cn/tools/common_share?appid=558&share_bg_color=0160FF&is_v2=true>
- 分享详情接口：<https://api.xiaoheihe.cn/game/mini_app/share_detail?mini_app_id=558&is_v2=true>
- 卡牌数据库页：<https://www.xiaoheihe.cn/game/slay_the_spire/database_v2/card_database>
- 单卡详情页示例：<https://www.xiaoheihe.cn/game/slay_the_spire/match_record_v2/card_detail?card_id=Offering>

## 已确认的重要接口路径

- `GET /game/slaythespire/v2/card/list`
- `GET /game/slaythespire/v2/card/detail`
- `POST /game/slaythespire/v2/create_archive_analyze_task`
- `GET /game/slaythespire/v2/queue_process`
- `GET /game/slaythespire/v2/save/overview`

## 一句话建议

下一次开新 session 时，优先让助手直接做：

- “写一个 Playwright 同步器，登录后抓小黑盒 `card/list` 和 `card/detail`，导出 `cards.json`，给 Mod 读取”

## 当前已落地的脚本

这次 session 里，已经新增了一个同步器原型：

- `tools/xhh-sts2-sync.mjs`

设计思路：

- 不再尝试“自动登录”
- 直接复用持久化浏览器 profile
- 第一次运行时由用户手动完成登录
- 后续脚本只复用登录态，进入页面后直接通过页面环境里的 `$hbClientRequest` 抓数据

建议的使用方式：

```bash
node tools/xhh-sts2-sync.mjs
```

常用参数：

- `--profile <dir>`：指定持久化浏览器数据目录
- `--output <file>`：指定导出文件路径
- `--category ironclad,silent`：只抓指定分类
- `--no-details`：只抓列表统计，不抓单卡详情
- `--detail-limit 20`：只抓前 N 张卡的详情，方便调试

注意：

- 脚本依赖 `playwright`
- 当前 workspace 里没有自动安装依赖；若要运行，需要先自行安装
- 这个脚本的目标是“做同步器”，不是“让 Mod 直接请求小黑盒接口”
