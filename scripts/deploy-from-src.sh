#!/bin/bash
# 从 src/ 部署（发布版本）；部署前备份 workspace、部署后恢复 workspace。
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

SERVER_IP="${SERVER_IP:?请设置 SERVER_IP（目标服务器 IP），例如: export SERVER_IP=1.2.3.4}"
SERVER_USER="${SERVER_USER:-root}"
OPENCLAW_WORKSPACE_PATH="${OPENCLAW_WORKSPACE_PATH:-/root/.openclaw/workspace}"
OPENCLAW_WORKSPACE_BACKUP_PATH="${OPENCLAW_WORKSPACE_BACKUP_PATH:-/data/openclaw-deploy/workspace-backup.tar}"

KEYS_DIR="${KEYS_DIR:-$PROJECT_ROOT/../keys/openclaw-cn}"
if [ -n "$KEYS_DIR" ] && [ -f "$KEYS_DIR/server.env" ]; then set -a; source "$KEYS_DIR/server.env"; set +a; fi
if [ -n "$KEYS_DIR" ] && [ -f "$KEYS_DIR/feishu.env" ]; then source "$KEYS_DIR/feishu.env"; fi
if [ -n "$KEYS_DIR" ] && [ -f "$KEYS_DIR/search.env" ]; then source "$KEYS_DIR/search.env"; fi
if [ -n "$KEYS_DIR" ] && [ -f "$KEYS_DIR/llm.env" ]; then source "$KEYS_DIR/llm.env"; fi

if [ ! -d "$SRC_DIR/bigclaw" ] || [ ! -f "$SRC_DIR/docker-compose.yml" ]; then
    log_error "src/ 不完整（需 bigclaw/ 与 docker-compose.yml）"
    exit 1
fi

log_info "全部部署：从 src+spec 发布版本部署（含 workspace 备份与恢复）"
log_info "目标服务器: $SERVER_IP（仅使用 $SRC_DIR）"
if [ -z "${BAILIAN_API_KEY:-}" ]; then
    log_warn "未设置 BAILIAN_API_KEY（需在 KEYS_DIR/llm.env 或环境中配置），部署后模型对话将不可用"
fi

echo ""
if [ "${SKIP_WORKSPACE_BACKUP:-0}" != "1" ]; then
    log_info "[0/8] 备份 workspace（若存在）..."
    if ssh "$SERVER_USER@$SERVER_IP" "test -d '$OPENCLAW_WORKSPACE_PATH'" 2>/dev/null; then
        ssh "$SERVER_USER@$SERVER_IP" "rm -f '$OPENCLAW_WORKSPACE_BACKUP_PATH'; tar cf '$OPENCLAW_WORKSPACE_BACKUP_PATH' -C '$(dirname "$OPENCLAW_WORKSPACE_PATH")' '$(basename "$OPENCLAW_WORKSPACE_PATH")'"
        log_success "workspace 已备份到 $OPENCLAW_WORKSPACE_BACKUP_PATH"
    else
        log_info "workspace 不存在，跳过备份（如首次部署）"
    fi
else
    log_info "[0/8] 跳过 workspace 备份 (SKIP_WORKSPACE_BACKUP=1)"
fi

echo ""
log_info "[1/8] 同步 bigclaw 到 /data/bigclaw..."
rsync -avz --delete "$SRC_DIR/bigclaw/" "$SERVER_USER@$SERVER_IP:/data/bigclaw/" 2>/dev/null || true
log_success "bigclaw 同步完成"

echo ""
log_info "[2/8] 配置 OpenClaw (openclaw.json)..."
ssh "$SERVER_USER@$SERVER_IP" "cat > /root/.openclaw/openclaw.json << 'EOF'
{
  \"meta\": {
    \"lastTouchedVersion\": \"2026.2.13\",
    \"lastTouchedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\"
  },
  \"models\": {
    \"mode\": \"merge\",
    \"providers\": {
      \"bailian\": {
        \"baseUrl\": \"https://coding.dashscope.aliyuncs.com/v1\",
        \"apiKey\": \"${BAILIAN_API_KEY:-}\",
        \"api\": \"openai-completions\",
        \"models\": [
          {
            \"id\": \"qwen3.5-plus\",
            \"name\": \"qwen3.5-plus\",
            \"reasoning\": false,
            \"input\": [\"text\"],
            \"cost\": { \"input\": 0, \"output\": 0, \"cacheRead\": 0, \"cacheWrite\": 0 },
            \"contextWindow\": 262144,
            \"maxTokens\": 65536
          }
        ]
      }
    }
  },
  \"agents\": {
    \"defaults\": {
      \"model\": { \"primary\": \"bailian/qwen3.5-plus\" },
      \"models\": { \"bailian/qwen3.5-plus\": { \"alias\": \"qwen3.5-plus\" } },
      \"maxConcurrent\": 4,
      \"subagents\": { \"maxConcurrent\": 8 },
      \"workspace\": \"/home/node/.openclaw/workspace\"
    }
  },
  \"commands\": { \"native\": \"auto\", \"nativeSkills\": \"auto\" },
  \"tools\": { \"deny\": [\"web_search\"], \"allow\": [\"composite_search\"] },
  \"plugins\": {
    \"enabled\": true,
    \"load\": { \"paths\": [\"/app/bigclaw\"] },
    \"entries\": { \"bigclaw\": { \"enabled\": true } }
  },
  \"channels\": {
    \"feishu\": {
      \"enabled\": true,
      \"appId\": \"${FEISHU_APP_ID:-}\",
      \"appSecret\": \"${FEISHU_APP_SECRET:-}\",
      \"encryptKey\": \"${FEISHU_ENCRYPT_KEY:-}\",
      \"verificationToken\": \"${FEISHU_VERIFICATION_TOKEN:-}\",
      \"webhookPath\": \"/webhooks/feishu\",
      \"dmPolicy\": \"open\",
      \"allowFrom\": [\"*\"]
    }
  },
  \"gateway\": {
    \"port\": 18789,
    \"controlUi\": { \"allowInsecureAuth\": true },
    \"trustedProxies\": [\"0.0.0.0/0\"]
  }
}
EOF"
ssh "$SERVER_USER@$SERVER_IP" "chown -R 1000:1000 /root/.openclaw 2>/dev/null || true"
log_success "OpenClaw 配置完成"

echo ""
log_info "[3/8] 上传 docker-compose.yml 与 Caddyfile 到服务器..."
scp -q "$SRC_DIR/docker-compose.yml" "$SERVER_USER@$SERVER_IP:/data/openclaw-deploy/docker-compose.yml"
scp -q "$SRC_DIR/Caddyfile" "$SERVER_USER@$SERVER_IP:/data/openclaw-deploy/Caddyfile"
log_success "编排文件已更新"

echo ""
log_info "[4/8] 写入搜索与 LLM API Key 到服务器 .env..."
TMP_ENV=$(mktemp)
trap "rm -f '$TMP_ENV'" EXIT
echo "GAODE_API_KEY=${GAODE_API_KEY:-}" >> "$TMP_ENV"
echo "BAIDU_API_KEY=${BAIDU_API_KEY:-}" >> "$TMP_ENV"
echo "BAILIAN_API_KEY=${BAILIAN_API_KEY:-}" >> "$TMP_ENV"
scp -q "$TMP_ENV" "$SERVER_USER@$SERVER_IP:/tmp/keys.env"
ssh "$SERVER_USER@$SERVER_IP" "cat /data/openclaw-deploy/.env 2>/dev/null | grep -v '^GAODE_API_KEY=\|^BAIDU_API_KEY=\|^BAILIAN_API_KEY=' > /data/openclaw-deploy/.env.tmp 2>/dev/null || true; cat /tmp/keys.env >> /data/openclaw-deploy/.env.tmp; mv /data/openclaw-deploy/.env.tmp /data/openclaw-deploy/.env; rm -f /tmp/keys.env"
log_success "搜索与 LLM Key 已写入"

echo ""
log_info "[5/8] 重启服务..."
ssh "$SERVER_USER@$SERVER_IP" "cd /data/openclaw-deploy && docker compose up -d --force-recreate"
sleep 18

if ssh "$SERVER_USER@$SERVER_IP" "docker ps | grep -q 'openclaw-deploy-openclaw-gateway-1.*Up'"; then
    log_success "服务已启动"
else
    log_warn "gateway 尚未就绪，继续执行恢复与健康检查（若仍 502 请稍后重试或查看 gateway 日志）"
fi

echo ""
if [ "${SKIP_WORKSPACE_RESTORE:-0}" != "1" ]; then
    log_info "[6/8] 恢复 workspace（若存在备份）..."
    if ssh "$SERVER_USER@$SERVER_IP" "test -f '$OPENCLAW_WORKSPACE_BACKUP_PATH'" 2>/dev/null; then
        ssh "$SERVER_USER@$SERVER_IP" "mkdir -p '$(dirname "$OPENCLAW_WORKSPACE_PATH")'; rm -rf '$OPENCLAW_WORKSPACE_PATH'; tar xf '$OPENCLAW_WORKSPACE_BACKUP_PATH' -C '$(dirname "$OPENCLAW_WORKSPACE_PATH")'; chown -R 1000:1000 '$OPENCLAW_WORKSPACE_PATH' 2>/dev/null || true"
        log_success "workspace 已从备份恢复"
    else
        log_info "无有效备份，跳过恢复（首次部署或未备份）"
    fi
else
    log_info "[6/8] 跳过 workspace 恢复 (SKIP_WORKSPACE_RESTORE=1)"
fi

echo ""
log_info "[7/8] 验证部署..."
sleep 3
HEALTH_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$SERVER_IP.nip.io:18443/" 2>/dev/null || echo "000")
if [ "$HEALTH_STATUS" = "200" ]; then
    log_success "健康检查通过 (HTTP 200)"
else
    log_warn "健康检查返回 HTTP $HEALTH_STATUS，继续观察..."
fi

echo ""
log_info "[8/8] 完成"
log_success "全部部署完成（src+spec 发布版本，含 workspace 备份与恢复）"
echo ""
echo -e "${GREEN}访问:${NC} https://$SERVER_IP.nip.io:18443/"
echo -e "${GREEN}版本:${NC} 见 spec/README.md"
echo ""
