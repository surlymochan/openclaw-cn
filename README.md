# OpenClaw Docker CN

一行命令部署 OpenClaw，开箱即用的 AI 助手平台。

```bash
./deploy-openclaw.sh <你的服务器IP>
```

---

## 核心特性

| 特性 | 说明 |
|------|------|
| 🚀 **一键部署** | 单命令完成完整部署，无需手动配置 |
| 🔥 **qwen3-max 模型** | 内置通义千问 Qwen3 Max 模型（80k 上下文）|
| 🇨🇳 **国内优化** | NPM 镜像加速，解决网络问题 |
| 🔒 **HTTPS 直连** | Caddy 自动 HTTPS，无需 SSH 隧道 |
| 🔍 **复合搜索** | 百度 AI 智能搜索 + 高德地图 POI 搜索 |
| 🛠️ **内置工具** | 原生命令和技能系统，开箱即用 |
| 💾 **持久化工作区** | 自动保存对话历史和文件 |
| 🌐 **Web 访问** | 通过浏览器直接访问，无需本地安装 |

---

## 一步启动

```bash
# 部署 OpenClaw
./deploy-openclaw.sh <你的服务器IP>
```

脚本自动完成：
- 拉取 OpenClaw 源码 → 构建 Docker 镜像 → 启动服务
- 配置 qwen3-max 模型 → 启用复合搜索插件
- 设置 HTTPS 反向代理 → 生成安全 Token

访问 `https://<IP>.nip.io:18443`，开始使用！

---

## AI 能力

### 🧠 qwen3-max 模型
- **超长上下文**: 80,000 tokens 上下文窗口
- **大输出能力**: 最多 8,192 tokens 输出
- **原生支持**: 内置命令系统和技能框架
- **持久化工作区**: 自动保存对话历史和生成的文件

### 🔍 复合搜索功能
- **模块化架构**: 可扩展的插件设计，支持多种搜索工具
- **百度 AI 搜索**: 通用中文搜索，AI 智能总结
- **高德地图搜索**: POI、地址、路线、出行信息  
- **智能路由**: 自动根据查询内容选择最佳搜索引擎
- **禁用内置搜索**: 避免重复功能和 token 浪费

### 使用方法
在 OpenClaw Chat 中使用：
```
/search 杭州西湖
/search 人工智能最新发展  
/search 北京三里屯美食推荐
```

### 配置搜索 API Keys
在项目根目录下创建 `search.env` 文件：
```bash
GAODE_API_KEY=your-gaode-key
BAIDU_API_KEY=your-baidu-api-key
```

然后重新部署即可启用搜索功能。

---

## 常见问题

**Token 在哪？**
```bash
ssh root@<IP> "cat /data/openclaw-deploy/.env | grep TOKEN"
```

**怎么重启？**
```bash
ssh root@<IP> "cd /data/openclaw-deploy && docker compose restart"
```

**怎么看日志？**
```bash
ssh root@<IP> "docker logs openclaw-deploy-openclaw-gateway-1 -f"
```

---

## 进阶配置

### 启用模型对话

在项目根目录下创建 `llm.env` 文件：

```bash
BAILIAN_API_KEY=your-key
```

重新部署。

### 本地源码调试

```bash
./deploy-openclaw.sh <IP> /path/to/openclaw
```

---

## 默认配置

- **AI 模型**: qwen3-max (80k 上下文，8192 输出)
- **Web 访问**: HTTPS 18443 端口 (Caddy 自动证书)
- **Gateway**: 18789 端口 (内部通信)
- **搜索功能**: 复合搜索插件 (百度 AI + 高德地图)
- **工作区**: 持久化存储 (`/root/.openclaw/workspace`)
- **命令系统**: 原生命令和技能自动启用
- **安全**: 内置 Token 认证，HTTPS 加密

---

## 声明

社区工具，与 OpenClaw 官方无关。