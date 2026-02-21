# DESIGN — 技术方案与配置（发布版）

本文档为 **openclaw-cn** 发布版的技术方案。

## 部署与目录

- **src/**：代码与配置（bigclaw、docker-compose.yml、openclaw.template.json、Caddyfile、Dockerfile）。
- **spec/**：说明与报告（MRD、PRD、DESIGN、TEST、REVIEW、README）。

## 配置来源

- 服务器 openclaw.json：由部署脚本根据密钥与模板生成（deploy-from-src 内联写入）。
- 服务器 docker-compose：来自 **src/docker-compose.yml**，部署时写入目标目录。
- openclaw.template.json：位于 **src/**，与当前生效配置一致。

## 插件与工具

- bigclaw：源码在 **src/bigclaw/**，**唯一源码为 index.ts**，index.js 由 `npm run build` 生成；部署时 rsync 到服务器，compose 挂载为 /app/bigclaw。
- composite_search：支持 source（baidu/gaode/auto）、query，以及 region/landmark/keyword（高德 POI）。百度分支使用千帆 web_search API，返回 references 列表；超时策略为 8s×2、不传 runSignal 给 fetch，避免网关提前 abort（SP0223）。

## 密钥注入

- 部署脚本从 KEYS_DIR 或环境变量读取后，将 GAODE_API_KEY、BAIDU_API_KEY 等写入服务器 .env，由 docker-compose 传入 gateway 容器。

## Workspace 备份与恢复

- **workspace 路径**：服务器默认 `/root/.openclaw/workspace`，可配置 `OPENCLAW_WORKSPACE_PATH`。
- **备份路径**：默认 `/data/openclaw-deploy/workspace-backup.tar`，可配置 `OPENCLAW_WORKSPACE_BACKUP_PATH`；只保留最新一份。
- **全部部署流程**：备份（若 workspace 存在）→ 同步/配置/重启 → 恢复（若备份存在）；可选 `SKIP_WORKSPACE_BACKUP=1` / `SKIP_WORKSPACE_RESTORE=1` 跳过。
- **单独操作**：`./deploy.sh workspace-backup`、`./deploy.sh workspace-restore` 或直接执行 `scripts/workspace-backup.sh`、`scripts/workspace-restore.sh`。
