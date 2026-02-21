# PRD — 产品需求与验收（发布版）

本文档为 **openclaw-cn** 发布版的产品需求与验收视图。

## 能力范围（当前版本 v2026.2.21）

1. **模型**：阿里百炼 qwen3-max（80k context，8k max tokens）。
2. **工具**：composite_search（百度千帆 web_search 接口 + 高德 POI）；禁用内置 web_search。百度分支已修复网关超时导致的中断（SP0223：web_search、8s×2、不传 runSignal）。
3. **插件**：bigclaw（OpenClaw Plugin），加载路径 `/app/bigclaw`。
4. **通道**：飞书（webhookPath /webhooks/feishu，dmPolicy open，allowFrom *）。
5. **Skills**：find-skills、skill-creator 等（镜像内置）。
6. **部署**：全部部署默认「先备份 workspace → 重新拉起 → 再恢复 workspace」；支持仅备份（`./deploy.sh workspace-backup`）、仅恢复（`./deploy.sh workspace-restore`）；路径见 spec/DESIGN.md。

## 验收标准（发布版）

- 部署来自 **src/** 后，Web UI 健康 200，Overview/Chat 可用。
- 飞书 Webhook 可连，机器人可收发消息（需配置密钥）。
- composite_search 可调用，无“API key 未配置”且能返回结果或友好提示。
- 密钥通过环境变量或 KEYS_DIR 指定目录提供，部署时注入服务器 .env。
- 全部部署后 workspace 与部署前一致（有备份则恢复）；首次部署无备份时不报错、跳过恢复；仅备份/仅恢复入口可用。

## 依赖与密钥

- 见 [README.md](./README.md) 密钥小节；路径与开关见 [DESIGN.md](./DESIGN.md)。
