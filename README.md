# OpenClaw Docker CN

一行命令部署 OpenClaw。

```bash
./deploy-openclaw.sh <你的服务器IP>
```

---

## 核心特性

| 特性 | 说明 |
|------|------|
| 🚀 **一键部署** | 克隆即跑，无需手动配置 |
| 🔥 **开箱即用** | 内置 qwen3-max 模型配置 |
| 🇨🇳 **国内友好** | NPM 镜像，解决网络问题 |
| 🔒 **HTTPS 直连** | Caddy 反向代理，无需 SSH 隧道 |

---

## 一步启动

```bash
# 1. 克隆
git clone https://github.com/surlymochan/openclaw-docker-cn.git
cd openclaw-docker-cn

# 2. 部署
./deploy-openclaw.sh
```

脚本自动完成：
- 拉取源码 → 构建镜像 → 启动服务 → 配置模型

访问 `https://<IP>.nip.io:18443`，搞定。

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

创建 `../../private/keys/openclaw-docker-cn/llm.env`：

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

- 模型：qwen3-max (80k context)
- 端口：18443 (HTTPS)
- Gateway：18789

---

## 声明

社区工具，与 OpenClaw 官方无关。
