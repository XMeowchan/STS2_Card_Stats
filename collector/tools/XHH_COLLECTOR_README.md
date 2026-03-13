# 小黑盒 STS2 采集器

这套脚本把生产采集路径固定为：真实 Chrome/Edge + 专用资料目录 + CDP 附着。

## 目录

- `tools/xhh-sts2-sync.mjs`：主采集器，负责 keepalive / 全量抓取 / manifest / 报警
- `tools/json-upload-receiver.mjs`：给 fallback 浏览器扩展使用的本地接收器
- `tools/start-xhh-chrome.ps1`：在 Windows 上启动专用浏览器资料目录
- `tools/xhh-extension-fallback/`：MV3 fallback 扩展

## 首次配置

1. 启动专用浏览器资料目录：

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/start-xhh-chrome.ps1
   ```

2. 在弹出的真实 Chrome / Edge 窗口里手动登录一次小黑盒。
3. 确认 `https://www.xiaoheihe.cn/game/slay_the_spire/database_v2/card_database` 能正常打开。

## 常用命令

全量抓取：

```bash
node tools/xhh-sts2-sync.mjs --output output/xhh/cards.snapshot.json
```

只做 keepalive：

```bash
node tools/xhh-sts2-sync.mjs --keepalive-only --output output/xhh/cards.snapshot.json
```

带 webhook 报警：

```bash
node tools/xhh-sts2-sync.mjs --alert-webhook https://example.com/hook --output output/xhh/cards.snapshot.json
```

## 输出

固定输出两类文件：

- `cards.snapshot.json`
- `manifest.json`

`manifest.json` 会记录：

- `status`
- `stage`
- `generatedAt`
- `lastGoodSnapshotAt`
- `snapshot.sha256`
- `snapshot.cardsCount`

当采集失败、返回 `login/relogin`、或校验失败时：

- 不覆盖旧 `cards.snapshot.json`
- 会刷新 `manifest.json` 的 `status`
- 可选发送 webhook 报警

## 推荐调度

- 每天一次：`--keepalive-only`
- 每周一次：全量抓取

Windows 计划任务建议拆成两个任务：

1. `tools/start-xhh-chrome.ps1`
2. `node tools/xhh-sts2-sync.mjs ...`

## Fallback 扩展

当 CDP 附着仍被小黑盒打回 `relogin` 时，改用 `tools/xhh-extension-fallback/`：

1. `node tools/json-upload-receiver.mjs --keep-open`
2. 打开 Chrome 扩展页，加载 `tools/xhh-extension-fallback/` 为未打包扩展
3. 在扩展选项页配置上传地址（默认 `http://127.0.0.1:8765/upload`）
4. 登录过小黑盒的真实浏览器中点击扩展图标，扩展会在页面环境里抓取并上传 / 下载 `cards.snapshot.json`

## 退出码

- `0`：成功
- `10`：会话失效，接口返回 `login` / `relogin`
- `11`：其他失败，但旧快照已保留
