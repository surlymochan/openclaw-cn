#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Load environment files from current directory
SEARCH_KEYS_FILE="./search.env"
if [ -f "$SEARCH_KEYS_FILE" ]; then
    set -a
    source "$SEARCH_KEYS_FILE"
    set +a
fi

LLM_KEYS_FILE="./llm.env"
if [ -f "$LLM_KEYS_FILE" ]; then
    set -a
    source "$LLM_KEYS_FILE"
    set +a
fi

SERVER_IP="${1:-${SERVER_IP:-}}"
LOCAL_SRC="${2:-}"
SERVER_USER="${SERVER_USER:-root}"

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}错误: 未指定服务器IP${NC}"
    echo "用法:"
    echo "  # 使用 GitHub 源码（默认）"
    echo "  ./deploy-openclaw.sh <服务器IP>"
    echo ""
    echo "  # 使用本地源码（调试）"
    echo "  ./deploy-openclaw.sh <服务器IP> <本地源码路径>"
    exit 1
fi

REMOTE_DIR="/data/openclaw-deploy"
CONFIG_DIR="/root/.openclaw"
WORKSPACE_DIR="/root/.openclaw/workspace"
TEMP_SRC="openclaw-src-tmp-$$"

if [ -n "$LOCAL_SRC" ]; then
    echo -e "${BLUE}📥 使用本地源码: $LOCAL_SRC${NC}"
    
    if [ ! -d "$LOCAL_SRC" ]; then
        echo -e "${RED}错误: 本地源码目录不存在: $LOCAL_SRC${NC}"
        exit 1
    fi
    
    rm -rf "$TEMP_SRC"
    rsync -av --exclude='.git' --exclude='CLAUDE.md' "$LOCAL_SRC/" "$TEMP_SRC/"
    echo -e "${GREEN}✓ 本地源码复制完成${NC}"
else
    echo -e "${BLUE}📥 从 GitHub 拉取 OpenClaw 源码...${NC}"
    rm -rf "$TEMP_SRC"
    git clone https://github.com/openclaw/openclaw.git "$TEMP_SRC"
    echo -e "${GREEN}✓ GitHub 源码拉取完成${NC}"
fi

echo -e "${BLUE}💉 注入定制 Dockerfile...${NC}"
cp Dockerfile "$TEMP_SRC/"

echo -e "${BLUE}🚀 同步到服务器: $SERVER_IP...${NC}"
ssh "$SERVER_USER@$SERVER_IP" "mkdir -p $REMOTE_DIR/context $CONFIG_DIR $WORKSPACE_DIR"

rsync -avz --exclude '.git' --delete "$TEMP_SRC/" "$SERVER_USER@$SERVER_IP:$REMOTE_DIR/context/"
rsync -avz docker-compose.yml Caddyfile "$SERVER_USER@$SERVER_IP:$REMOTE_DIR/"

echo -e "${BLUE}🐳 远程构建并启动...${NC}"
ssh "$SERVER_USER@$SERVER_IP" << 'EOF'
    set -e
    cd $REMOTE_DIR
    export SERVER_IP=$SERVER_IP
    
    EXISTING_TOKEN=""
    if [ -f "$CONFIG_DIR/openclaw.json" ]; then
        EXISTING_TOKEN=$(cat "$CONFIG_DIR/openclaw.json" 2>/dev/null | grep -o '"token": "[^"]*"' | head -1 | cut -d'"' -f4 || echo '')
        if [ -n "$EXISTING_TOKEN" ]; then
            echo "检测到现有配置，复用 Token"
        fi
    fi
    
    if [ -f .env ]; then
        if [ -z "$EXISTING_TOKEN" ]; then
            EXISTING_TOKEN=$(grep "OPENCLAW_GATEWAY_TOKEN=" .env | cut -d'=' -f2)
        fi
    else
        if [ -z "$EXISTING_TOKEN" ]; then
            TOKEN=$(openssl rand -hex 16)
        else
            TOKEN="$EXISTING_TOKEN"
        fi
        
        cat > .env << EENV
OPENCLAW_IMAGE=openclaw:local
OPENCLAW_GATEWAY_TOKEN=$TOKEN
OPENCLAW_CONFIG_DIR=$CONFIG_DIR
OPENCLAW_WORKSPACE_DIR=$WORKSPACE_DIR
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_GATEWAY_TRUSTED_PROXIES="0.0.0.0/0"
SERVER_IP=$SERVER_IP
EENV
    fi
    
    if [ -n "$EXISTING_TOKEN" ]; then
        if grep -q "OPENCLAW_GATEWAY_TOKEN=" .env; then
            sed -i "s/OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=$EXISTING_TOKEN/" .env
        fi
    fi
    
    if grep -q "SERVER_IP=" .env; then
        sed -i "s/SERVER_IP=.*/SERVER_IP=$SERVER_IP/" .env
    else
        echo "SERVER_IP=$SERVER_IP" >> .env
    fi
    
    CURRENT_TOKEN=$(grep "OPENCLAW_GATEWAY_TOKEN=" .env | cut -d'=' -f2)
    echo "Token: $CURRENT_TOKEN"
    
    # 生成 openclaw.json 配置（qwen3-max 模型 + 复合搜索插件）
    BAILIAN_API_KEY_PARAM="${BAILIAN_API_KEY:-}"
    if [ -n "$BAILIAN_API_KEY_PARAM" ]; then
        cat > "$CONFIG_DIR/openclaw.json" << GCONFIG
{
  "meta": {
    "lastTouchedVersion": "2026.2.13",
    "lastTouchedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
  },
  "models": {
    "mode": "merge",
    "providers": {
      "bailian": {
        "baseUrl": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "apiKey": "$BAILIAN_API_KEY_PARAM",
        "api": "openai-completions",
        "models": [
          {
            "id": "qwen3-max",
            "name": "Qwen3 Max",
            "contextWindow": 80000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "bailian/qwen3-max"
      },
      "models": {
        "bailian/qwen3-max": {}
      },
      "workspace": "/home/node/.openclaw/workspace"
    }
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "tools": {
    "deny": ["web_search"],
    "allow": ["composite_search"]
  },
  "plugins": {
    "enabled": true,
    "load": {
      "paths": ["/app/plugins/bigclaw"]
    },
    "entries": {
      "bigclaw": {
        "enabled": true
      }
    }
  },
  "gateway": {
    "port": 18789,
    "controlUi": {
      "allowInsecureAuth": true
    },
    "trustedProxies": [
      "0.0.0.0/0"
    ]
  }
}
GCONFIG
        echo "已生成 openclaw.json 配置（qwen3-max + 复合搜索插件）"
    fi
    
    # 修复权限
    chown -R 1000:1000 "$CONFIG_DIR" 2>/dev/null || true
    
    cd context
    docker build -t openclaw:local .
    cd ..
    
    docker compose up -d
    
    rm -rf context
    
    sleep 5
    
    docker ps | grep openclaw-deploy || true
EOF

rm -rf "$TEMP_SRC"

echo ""
echo -e "${GREEN}✅ 部署完成！${NC}"
echo ""
echo -e "🔗 Web UI: https://$SERVER_IP.nip.io:18443/"
echo ""
echo -e "获取 Token:"
echo "   ssh $SERVER_USER@$SERVER_IP \"cat /data/openclaw-deploy/.env | grep TOKEN\""
