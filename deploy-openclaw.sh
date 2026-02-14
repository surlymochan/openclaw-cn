#!/bin/bash

# ==========================================
# OpenClaw 一键部署脚本 (无源码版)
# ==========================================

# 0. 加载私有配置 (如果存在)
# 允许从 keys 目录自动加载 IP，方便开发者调试
KEYS_FILE="../../private/keys/openclaw-docker-cn/deploy.env"
if [ -f "$KEYS_FILE" ]; then
    echo "🔑 [0/5] 加载私有配置: $KEYS_FILE"
    set -a # 自动导出变量
    source "$KEYS_FILE"
    set +a
fi

# 优先使用命令行参数，如果为空则使用 Env 里的默认值
SERVER_IP="${1:-$SERVER_IP}"
SERVER_USER="${2:-${SERVER_USER:-root}}"

# 检查参数
if [ -z "$SERVER_IP" ]; then
    echo "❌ 错误: 未指定服务器IP"
    echo "用法: ./deploy-openclaw.sh <SERVER_IP> [USER]"
    exit 1
fi

REMOTE_DIR="/data/openclaw-deploy"
CONFIG_DIR="/root/.openclaw"
WORKSPACE_DIR="/root/.openclaw/workspace"
TEMP_SRC="openclaw-src-tmp"

# 1. 准备源码
echo "📥 [1/5] 拉取最新 OpenClaw 源码..."
rm -rf $TEMP_SRC
git clone https://github.com/openclaw/openclaw.git $TEMP_SRC

echo "💉 [2/5] 注入定制 Dockerfile..."
# 将我们的定制 Dockerfile 覆盖到源码目录
cp Dockerfile $TEMP_SRC/

# 2. 同步到服务器
echo "🚀 [3/5] 同步构建上下文到服务器: $SERVER_IP..."
ssh $SERVER_USER@$SERVER_IP "mkdir -p $REMOTE_DIR/context $CONFIG_DIR $WORKSPACE_DIR"

# 同步源码+Dockerfile 到 context 目录
rsync -avz --exclude '.git' --delete $TEMP_SRC/ $SERVER_USER@$SERVER_IP:$REMOTE_DIR/context/

# 同步编排文件 到 根目录
rsync -avz docker-compose.yml Caddyfile $SERVER_USER@$SERVER_IP:$REMOTE_DIR/

if [ $? -ne 0 ]; then
    echo "❌ 同步失败"
    exit 1
fi

# 3. 远程构建与运行
echo "🐳 [4/5] 远程构建镜像并启动..."
ssh $SERVER_USER@$SERVER_IP << EOF
    set -e
    cd $REMOTE_DIR
    
    # 导出 IP 供 Caddy 使用
    export SERVER_IP=$SERVER_IP
    
    # 生成 .env
    if [ ! -f .env ]; then
        TOKEN=\$(openssl rand -hex 16)
        cat > .env << EENV
OPENCLAW_IMAGE=openclaw:local
OPENCLAW_GATEWAY_TOKEN=\$TOKEN
OPENCLAW_CONFIG_DIR=$CONFIG_DIR
OPENCLAW_WORKSPACE_DIR=$WORKSPACE_DIR
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_GATEWAY_BIND=0.0.0.0
OPENCLAW_GATEWAY_TRUSTED_PROXIES="0.0.0.0/0"
TRUSTED_PROXIES="0.0.0.0/0"
CLAUDE_AI_SESSION_KEY=""
SERVER_IP=$SERVER_IP
EENV
    else
        # 更新 .env 中的 SERVER_IP (如果变了)
        # 简单替换：如果存在 SERVER_IP=... 则替换，否则追加
        if grep -q "SERVER_IP=" .env; then
            sed -i "s/^SERVER_IP=.*/SERVER_IP=$SERVER_IP/" .env
        else
            echo "SERVER_IP=$SERVER_IP" >> .env
        fi
    fi
    
    # 构建
    echo "Building Docker Image..."
    cd context
    docker build -t openclaw:local .
    cd ..
    
    # 启动
    echo "Starting Services..."
    # 确保 docker-compose 能读到 .env 中的 SERVER_IP
    docker compose up -d
    
    # 清理远程源码 (节省空间)
    rm -rf context
EOF

# 4. 本地清理
echo "🧹 [5/5] 清理本地临时文件..."
rm -rf $TEMP_SRC

echo "✅ 部署完成！"
echo "Web UI: https://$SERVER_IP.nip.io:18443"
