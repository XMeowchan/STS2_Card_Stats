# STS2 XiaoHeiHe Collector

生产化的《杀戮尖塔 2》小黑盒卡牌统计采集工具集。

主链路采用：

- 真实 Chrome / Edge
- 专用浏览器资料目录
- CDP 附着
- 页面环境内请求
- 本地 `snapshot + manifest`

同时提供：

- `keepalive` 健康检查
- webhook 报警
- MV3 浏览器扩展 fallback
- Windows 启动脚本

## 快速开始

1. 安装依赖

```bash
npm install
```

2. 启动专用浏览器

```powershell
powershell -ExecutionPolicy Bypass -File tools/start-xhh-chrome.ps1
```

3. 在该浏览器里手动登录一次小黑盒

4. 先跑 keepalive

```bash
npm run xhh:keepalive
```

5. 再跑全量采集

```bash
npm run xhh:sync
```

## 主要文件

- `tools/xhh-sts2-sync.mjs`
- `tools/xhh-collector-common.mjs`
- `tools/json-upload-receiver.mjs`
- `tools/start-xhh-chrome.ps1`
- `tools/xhh-extension-fallback/`
- `STS2_XiaoHeiHe_Data_Research.md`
- `AGENT_HANDOFF.md`

更详细说明见 `tools/XHH_COLLECTOR_README.md`。
