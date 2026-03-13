# XHH STS2 Collector Fallback Extension

这是 `tools/xhh-sts2-sync.mjs` 的二级 fallback：当 CDP 附着到真实 Chrome 仍被小黑盒打回 `relogin` 时，用扩展在页面环境里直接抓取数据。

## 加载方式

1. 打开 Chrome 扩展页 `chrome://extensions`
2. 开启开发者模式
3. 选择“加载已解压的扩展程序”
4. 指向本目录 `tools/xhh-extension-fallback/`

## 使用方式

### 模式 A：上传到本地接收器

1. 启动接收器：

   ```bash
   node tools/json-upload-receiver.mjs --keep-open
   ```

2. 在扩展选项页保持默认上传地址 `http://127.0.0.1:8765/upload`
3. 使用已登录小黑盒的真实浏览器，打开或允许扩展打开卡牌数据库页
4. 点击扩展图标，扩展会抓取并上传 `cards.snapshot.json`

### 模式 B：直接下载 JSON

1. 在扩展选项页把 `Output mode` 改成 `download`
2. 点击扩展图标
3. 扩展会直接下载一份 `cards.snapshot.*.json`

## 说明

- 这个扩展不依赖 Playwright。
- 它仍然依赖真实浏览器里的小黑盒登录态。
- 它只作为二级 fallback，不建议替代主采集器的自动调度链路。
