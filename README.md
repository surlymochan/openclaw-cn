# OpenClaw Docker CN (一键部署包)

[English](./README_EN.md)

**本项目旨在为国内用户提供一个简单、稳定、一键式的 OpenClaw 部署方案。**

## 核心特性
*   🚀 **一键部署**: 自动复制本地源码、注入国内源、构建镜像、启动服务。
*   🇨🇳 **国内优化**: 内置 NPM 淘宝镜像配置，解决构建时的网络问题。
*   🔒 **HTTPS 直连**: 集成 Caddy 反向代理，自动伪装 Origin，无需 SSH 隧道即可访问 Web UI。
*   🛠 **运维增强**: 镜像内预装常用工具 (`vim`, `curl` 等) 及 `openclaw` CLI 别名。

## ⚠️ 重要声明

**本项目源码（除 OpenClaw 本身外）未经允许，请勿上传至 GitHub 或其他公开代码仓库。**

## 快速开始

### 1. 准备工作
*   一台安装了 Docker 和 SSH 的 Linux 服务器（如腾讯云、阿里云）。
*   本地机器（Mac/Linux）安装了 `rsync`。
*   **OpenClaw 源码目录**: `/Users/chenchao/workspace/project/public/openclaw`
    *   部署脚本将从此目录复制源码，不再从 GitHub 克隆

### 2. 执行部署
在本地执行部署脚本，传入服务器 IP 和用户名（默认 root）：

```bash
./deploy-openclaw.sh <服务器IP> [用户名]
# 例如: ./deploy-openclaw.sh 1.2.3.4
```

脚本会自动完成以下操作：
1.  从本地目录复制 OpenClaw 源码 (`/Users/chenchao/workspace/project/public/openclaw`)。
2.  注入定制的 Dockerfile（配置国内源）。
3.  同步到服务器并构建镜像。
4.  启动 OpenClaw Gateway 和 Caddy。

### 3. 访问与配对
部署成功后，脚本会输出访问地址。

1.  打开浏览器访问：`https://<服务器IP>.nip.io:18443`
    *   *注意：由于使用自签名证书，浏览器会提示不安全，请点击“继续前往” (Proceed)。*
2.  如果页面提示 **"Pairing Required"** 或要求输入 Token：
    *   查看服务器上的 Token：`ssh root@<IP> "cat /data/openclaw-deploy/.env | grep TOKEN"`
    *   在 Web UI 中输入 Token 完成配对
    *   或在本地终端运行 `./approve-device.sh <服务器IP>` 自动批准设备
3.  页面将自动刷新并连接成功。

## 常用运维命令

**进入容器控制台**:
```bash
ssh root@<IP> "docker exec -it openclaw-deploy-openclaw-gateway-1 /bin/bash"
# 在容器内可以使用:
openclaw status
openclaw devices list
```

**查看日志**:
```bash
ssh root@<IP> "docker logs openclaw-deploy-openclaw-gateway-1 -f --tail 100"
```

**查看 Token**:
```bash
ssh root@<IP> "cat /data/openclaw-deploy/.env | grep TOKEN"
```

## 目录说明
*   `deploy-openclaw.sh`: 部署主脚本。
*   `approve-device.sh`: 设备配对脚本。
*   `Dockerfile`: 定制构建文件（构建时注入）。
*   `docker-compose.yml`: 服务编排。
*   `Caddyfile`: 反向代理配置。

## 声明
本项目与 OpenClaw 官方无关，仅作为社区部署工具。源码版权归 OpenClaw 所有。
