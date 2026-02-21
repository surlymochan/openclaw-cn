# 功能测试说明（openclaw-cn）

**说明**：本仓库为发布版；配置与代码以 **src/** 为准。

---

## 已执行检查（发布前）

| 项目 | 结果 | 说明 |
|------|------|------|
| 根目录 deploy.sh 语法 | ✅ 通过 | bash -n 通过 |
| scripts/deploy-from-src.sh、workspace-backup.sh、workspace-restore.sh | ✅ 通过 | 语法检查通过 |
| src/openclaw.template.json | ✅ 通过 | 合法 JSON |
| src/docker-compose.yml | ✅ 通过 | 含 gateway、bigclaw 挂载与环境变量 |
| src/bigclaw 插件 | ✅ 通过 | 合法 JSON，composite_search 注册 |

## 百度搜索验收（SP0223）

- **自测**：`BAIDU_API_KEY=<key> node src/bigclaw/scripts/test-baidu-web-search.js`，退出码 0、输出 references 条数。
- **远端**：部署后 `POST /tools/invoke`，tool=composite_search、args.source=baidu，应返回「【百度搜索】共 N 条结果」而非超时或未配置。已通过（175.178.157.123.nip.io:18443）。

## 建议在目标机执行的验证

- 执行 `./deploy.sh all` 后：Web UI 200、飞书与 composite_search 可用。
- 部署前在 workspace 写入标记文件，部署后检查该文件仍存在（workspace 已恢复）。
- 仅备份/仅恢复：执行 `./deploy.sh workspace-backup`、`./deploy.sh workspace-restore` 验证行为符合 DESIGN。
