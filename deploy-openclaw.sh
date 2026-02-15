#!/bin/bash

# ==========================================
# OpenClaw 一键部署脚本 (本地源码版)
# ==========================================

# 0. 加载私有配置 (如果存在)
KEYS_FILE="../../private/keys/openclaw-docker-cn/deploy.env"
if [ -f "$KEYS_FILE" ]; then
    echo "🔑 [0/5] 加载私有配置: $KEYS_FILE"
    set -a
    source "$KEYS_FILE"
    set +a
fi

SERVER_IP="${1:-$SERVER_IP}"
SERVER_USER="${2:-${SERVER_USER:-root}}"

if [ -z "$SERVER_IP" ]; then
    echo "❌ 错误: 未指定服务器IP"
    echo "用法: ./deploy-openclaw.sh <SERVER_IP> [USER]"
    exit 1
fi

REMOTE_DIR="/data/openclaw-deploy"
CONFIG_DIR="/root/.openclaw"
WORKSPACE_DIR="/root/.openclaw/workspace"
TEMP_SRC="openclaw-src-tmp"
LOCAL_SRC="/Users/chenchao/workspace/project/public/openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

echo "📥 [1/5] 复制本地 OpenClaw 源码..."
rm -rf $TEMP_SRC

if [ ! -d "$LOCAL_SRC" ]; then
    echo "❌ 错误: 本地源码目录不存在: $LOCAL_SRC"
    exit 1
fi

rsync -av --exclude='.git' --exclude='CLAUDE.md' "$LOCAL_SRC/" "$TEMP_SRC/"
if [ $? -ne 0 ]; then
    echo "❌ 源码复制失败"
    exit 1
fi
echo "✅ 已从 $LOCAL_SRC 复制源码"

echo "💉 [2/5] 注入定制 Dockerfile..."
cp Dockerfile $TEMP_SRC/

echo "🚀 [3/5] 同步构建上下文到服务器: $SERVER_IP..."
ssh $SERVER_USER@$SERVER_IP "mkdir -p $REMOTE_DIR/context $CONFIG_DIR $WORKSPACE_DIR"

rsync -avz --exclude '.git' --delete $TEMP_SRC/ $SERVER_USER@$SERVER_IP:$REMOTE_DIR/context/
rsync -avz docker-compose.yml Caddyfile $SERVER_USER@$SERVER_IP:$REMOTE_DIR/

if [ $? -ne 0 ]; then
    echo "❌ 同步失败"
    exit 1
fi

echo "🐳 [4/5] 远程构建镜像并启动..."
ssh $SERVER_USER@$SERVER_IP << EOF
    set -e
    cd $REMOTE_DIR
    export SERVER_IP=$SERVER_IP
    
    # 检查现有配置中的 Token
    EXISTING_TOKEN=""
    if [ -f "$CONFIG_FILE" ]; then
        EXISTING_TOKEN=\$(cat $CONFIG_FILE | grep -o '"token": "[^"]*"' | cut -d'"' -f4)
        if [ -n "\$EXISTING_TOKEN" ]; then
            echo "ℹ️  检测到现有配置，使用已有 Token"
        fi
    fi
    
    # 生成或复用 Token
    if [ -f .env ]; then
        # 保留现有 .env 中的 Token
        if [ -z "\$EXISTING_TOKEN" ]; then
            EXISTING_TOKEN=\$(grep "OPENCLAW_GATEWAY_TOKEN=" .env | cut -d'=' -f2)
        fi
        echo "ℹ️  保留现有 .env 配置"
    else
        # 生成新 Token（如果没有现有配置）
        if [ -z "\$EXISTING_TOKEN" ]; then
            TOKEN=\$(openssl rand -hex 16)
        else
            TOKEN="\$EXISTING_TOKEN"
        fi
        
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
        echo "✅ 已生成 .env 文件"
    fi
    
    # 如果检测到现有配置，确保 .env 中的 Token 与配置一致
    if [ -n "\$EXISTING_TOKEN" ]; then
        if grep -q "OPENCLAW_GATEWAY_TOKEN=" .env; then
            sed -i "s/^OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=\$EXISTING_TOKEN/" .env
            echo "✅ 已同步 .env Token 与现有配置一致"
        fi
    fi
    
    # 更新 SERVER_IP
    if grep -q "SERVER_IP=" .env; then
        sed -i "s/^SERVER_IP=.*/SERVER_IP=$SERVER_IP/" .env
    else
        echo "SERVER_IP=$SERVER_IP" >> .env
    fi
    
    # 显示当前使用的 Token
    CURRENT_TOKEN=\$(grep "OPENCLAW_GATEWAY_TOKEN=" .env | cut -d'=' -f2)
    echo "🔑 当前 Token: \$CURRENT_TOKEN"
    
    echo "Building Docker Image..."
    cd context
    docker build -t openclaw:local .
    cd ..
    
    echo "Starting Services..."
    docker compose up -d
    
    rm -rf context
    
    echo ""
    echo "⏳ 等待服务启动..."
    sleep 5
    
    echo ""
    echo "📊 容器状态:"
    docker ps | grep openclaw-deploy || true
EOF

echo "🧹 [5/5] 清理本地临时文件..."
rm -rf $TEMP_SRC

echo ""
echo "✅ 部署完成！"
echo ""
echo "🔗 Web UI: https://$SERVER_IP.nip.io:18443"
echo ""
echo "📋 获取 Token:"
echo "   ssh $SERVER_USER@$SERVER_IP \"cat /data/openclaw-deploy/.env | grep TOKEN\""
echo ""
echo "⚠️  如果这是首次部署或重新生成 Token，请在 Web UI 的 Overview 页面输入 Token"
echo "   如果已有配置，Token 已自动同步，直接访问即可"
