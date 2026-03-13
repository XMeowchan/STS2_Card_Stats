# Agent Handoff

## 仓库目标

这个仓库只保留“小黑盒 STS2 卡牌统计采集器”相关内容，不包含前端 demo 或其他无关实验文件。

## 当前已完成

- 主采集器改为 `CDP-first`
- 停用 `Playwright.launchPersistentContext` 作为正式生产路径
- 支持：
  - `--keepalive-only`
  - `--alert-webhook`
  - `cards.snapshot.json`
  - `manifest.json`
  - 失败保留旧快照
- 增加 Windows 启动脚本
- 增加 MV3 fallback 扩展
- 增加本地 receiver

## 关键脚本

- `tools/xhh-sts2-sync.mjs`
- `tools/xhh-collector-common.mjs`
- `tools/json-upload-receiver.mjs`
- `tools/start-xhh-chrome.ps1`

## 本地验证状态

- `npm run xhh:check` 已通过
- `node tools/xhh-sts2-sync.mjs --help` 已通过
- `node tools/json-upload-receiver.mjs --help` 已通过
- receiver smoke 已通过
- 采集器失败 manifest 路径已通过

## 尚未完成

- 在真实已登录小黑盒浏览器上完成 live 抓取验证
- 记录 `ok / login / relogin` 的真实触发条件
- 把报警接到真实 webhook 渠道
- 决定主链路是否继续 CDP，还是切扩展 fallback

## 换电脑后的继续步骤

1. `git clone`
2. `npm install`
3. `powershell -ExecutionPolicy Bypass -File tools/start-xhh-chrome.ps1`
4. 在专用浏览器 profile 中手动登录一次小黑盒
5. `npm run xhh:keepalive`
6. `npm run xhh:sync`
7. 如果 CDP 仍失败，切到 `tools/xhh-extension-fallback/`

## 重要文档

- `README.md`
- `tools/XHH_COLLECTOR_README.md`
- `tools/xhh-extension-fallback/README.md`
- `STS2_XiaoHeiHe_Data_Research.md`
