# OpenClaw Docker CN

One command to deploy OpenClaw.

```bash
./deploy-openclaw.sh <YOUR_SERVER_IP>
```

---

## Key Features

| Feature | Description |
|---------|-------------|
| 🚀 **One-Click** | Clone and run, no manual config |
| 🔥 **Out of Box** | Built-in qwen3-max model |
| 🇨🇳 **CN Optimized** | NPM mirror, network issues solved |
| 🔒 **HTTPS Direct** | Caddy proxy, no SSH tunnel needed |

---

## One-Click Start

```bash
# 1. Clone
git clone https://github.com/surlymochan/openclaw-docker-cn.git
cd openclaw-docker-cn

# 2. Deploy
./deploy-openclaw.sh
```

Done automatically:
- Fetch source → Build image → Start services → Configure model

Visit `https://<IP>.nip.io:18443`, you're in.

---

## FAQ

**Where is the token?**
```bash
ssh root@<IP> "cat /data/openclaw-deploy/.env | grep TOKEN"
```

**How to restart?**
```bash
ssh root@<IP> "cd /data/openclaw-deploy && docker compose restart"
```

**View logs?**
```bash
ssh root@<IP> "docker logs openclaw-deploy-openclaw-gateway-1 -f"
```

---

## Advanced

### Enable LLM

Create `../../private/keys/openclaw-docker-cn/llm.env`:

```bash
BAILIAN_API_KEY=your-key
```

Re-run deploy.

### Local Source Debug

```bash
./deploy-openclaw.sh <IP> /path/to/openclaw
```

---

## Default Config

- Model: qwen3-max (80k context)
- Port: 18443 (HTTPS)
- Gateway: 18789

---

## Disclaimer

Community tool. Not affiliated with OpenClaw.
