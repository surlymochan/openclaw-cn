# OpenClaw Docker CN

一行命令部署 OpenClaw。

```bash
./deploy-openclaw.sh <你的服务器IP>
```

就完事了。

---

## 一步启动

```bash
# 1. 克隆
git clone https://github.com/surlymochan/openclaw-docker-cn.git
cd openclaw-docker-cn

# 2. 部署（会问你要服务器IP）
./deploy-openclaw.sh
```

脚本会自动：
- 拉取源码
- 构建镜像
- 启动服务
- 配置 qwen3-max 模型

访问 `https://<IP>.nip.io:18443`，搞定。

---

## 常见问题

### 配对 Token 在哪看？
```bash
ssh root@<IP> "cat /data/openclaw-deploy/.env | grep TOKEN"
```

### 怎么重启？
```bash
ssh root@<IP> "cd /data/openclaw-deploy && docker compose restart"
```

### 怎么看日志？
```bash
ssh root@<IP> "docker logs openclaw-deploy-openclaw-gateway-1 -f"
```

---

## 进阶配置

### 阿里百炼模型（可选）

创建 `../../private/keys/openclaw-docker-cn/llm.env`：

```bash
BAILIAN_API_KEY=your-key
```

重新部署即可。

### 使用本地源码调试

```bash
./deploy-openclaw.sh <IP> /path/to/openclaw
```

---

## 详细说明

### 前置要求
- Linux 服务器（已装 Docker）
- Mac/Linux 本地机（装 rsync + git）

### 默认配置
- 模型：qwen3-max (80k context)
- 端口：18443 (HTTPS)
- 架构：Caddy 反向代理

### 服务地址
- Gateway: `http://<IP>:18789`
- Web UI: `https://<IP>.nip.io:18443`

---

## 声明

与 OpenClaw 官方无关，仅作社区部署工具。
