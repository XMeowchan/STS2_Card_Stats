# STS2 Card Stats Telemetry

如果你的主要用户在国内，优先看 `../telemetry_edgeone/README.md` 里的 EdgeOne 方案，再把 Cloudflare Worker 留作回退。

这个目录提供一个零额外费用优先的匿名统计后端：

- Cloudflare Workers Free 接收 Mod 每日心跳
- Cloudflare D1 Free 存匿名安装实例与每日活跃
- GitHub Pages 读取 `/v1/stats.json` 生成 README 曲线

## 统计口径

- `new_users`: 当天首次出现的匿名安装实例
- `active_users`: 当天至少上报过一次的匿名安装实例
- `cumulative_users`: 截至当天累计出现过的匿名安装实例

服务端只保存随机安装 ID 的 SHA-256 哈希，不保存 Steam 账号、硬件指纹或用户名。

## 当前线上地址

- Heartbeat: `https://sts2-card-stats-telemetry.xmeowchan0415.workers.dev/v1/heartbeat`
- Stats: `https://sts2-card-stats-telemetry.xmeowchan0415.workers.dev/v1/stats.json?days=365`

## 免费部署

1. 安装依赖

   ```bash
   npm install
   ```

2. 在 Cloudflare 创建一个 D1 数据库，并把返回的 `database_id` 写入 `wrangler.jsonc`

3. 应用迁移

   ```bash
   npx wrangler d1 migrations apply sts2-card-stats-telemetry --remote
   ```

4. 部署 Worker

   ```bash
   npm run deploy
   ```

5. 记下部署后的 Worker 地址，例如：

   ```text
   https://sts2-card-stats-telemetry.<your-subdomain>.workers.dev
   ```

## 仓库接线

部署完后，把下面两个地方改掉：

1. `config.cfg`

   ```json
   {
     "telemetry_enabled": true,
     "telemetry_endpoint": "https://sts2-card-stats-telemetry.<your-subdomain>.workers.dev/v1/heartbeat",
     "telemetry_timeout_seconds": 5
   }
   ```

GitHub Pages 已经改成直接读取 Worker 的 `stats.json`，所以只要 Worker 在线，GitHub Actions 每天就会重新生成 `users-history.svg`，README 里的曲线会自动更新。
