# OpenClaw 国内版 — 规格与说明

**当前发布版本**：`v2026.2.21`（含 SP0223 百度搜索修复）

**版本说明**：本仓库为发布版，部署使用 **src/**（代码与配置）与 **spec/**（本目录）；`./deploy.sh all` 部署的即此版本。

---

## 项目概述

本仓库为 OpenClaw 国内一键部署版，包含：大模型（阿里百炼 qwen3-max）、复合搜索（百度+高德）、飞书机器人、bigclaw 插件、关键 Skills。部署时默认先备份 Agent workspace、再拉起服务、最后恢复 workspace。

## 密钥与配置

密钥通过以下方式之一提供（部署脚本会注入到服务器）：

- **环境变量**：`BAILIAN_API_KEY`、`FEISHU_APP_ID` / `FEISHU_APP_SECRET` 等，或
- **KEYS_DIR**：指向包含 `llm.env`、`feishu.env`、`search.env` 的目录（脚本内通过 `KEYS_DIR` 环境变量或相对路径读取）。

各文件用途：`llm.env` 阿里云百炼；`feishu.env` 飞书机器人；`search.env` 百度/高德搜索 API Key。

## 部署

- **全部部署**：`./deploy.sh all` 或 `bash scripts/deploy-from-src.sh` — 从 src 同步、写配置、重启，并自动备份与恢复 workspace。
- **仅备份 workspace**：`./deploy.sh workspace-backup` 或 `bash scripts/workspace-backup.sh`。
- **仅恢复 workspace**：`./deploy.sh workspace-restore` 或 `bash scripts/workspace-restore.sh`。

常用环境变量：`SERVER_IP`（必填）、`SERVER_USER`（默认 root）、`OPENCLAW_WORKSPACE_PATH`、`OPENCLAW_WORKSPACE_BACKUP_PATH`（路径见 DESIGN.md）。

## 文档索引（spec）

| 文档 | 说明 |
|------|------|
| [README.md](./README.md) | 本文件；版本与总览 |
| [MRD.md](./MRD.md) | 需求概要 |
| [PRD.md](./PRD.md) | 产品需求与验收 |
| [DESIGN.md](./DESIGN.md) | 技术方案与配置 |
| [TEST.md](./TEST.md) | 测试说明 |
| [REVIEW.md](./REVIEW.md) | 审查说明 |
