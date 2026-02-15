# OpenClaw Docker CN

One command to deploy OpenClaw.

```bash
./deploy-openclaw.sh <YOUR_SERVER_IP>
```

That's it.

---

## One-Click Start

```bash
# 1. Clone
git clone https://github.com/surlymochan/openclaw-docker-cn.git
cd openclaw-docker-cn

# 2. Deploy
./deploy-openclaw.sh
```

The script will:
- Fetch source code
- Build image
- Start services
- Configure qwen3-max model

Visit `https://<IP>.nip.io:18443`, done.

---

## FAQ

### Where's the pairing token?
```bash
ssh root@<IP> "cat /data/openclaw-deploy/.env | grep TOKEN"
```

### How to restart?
```bash
ssh root@<IP> "cd /data/openclaw-deploy && docker compose restart"
```

### View logs?
```bash
ssh root@<IP> "docker logs openclaw-deploy-openclaw-gateway-1 -f"
```

---

## Advanced

### Enable LLM (Optional)

Create `../../private/keys/openclaw-docker-cn/llm.env`:

```bash
BAILIAN_API_KEY=your-key
```

Re-run deploy.

### Use Local Source

```bash
./deploy-openclaw.sh <IP> /path/to/openclaw
```

---

## Default Config
- Model: qwen3-max (80k context)
- Port: 18443 (HTTPS)
- Gateway: http://<IP>:18789

---

## Disclaimer

Community tool. Not affiliated with OpenClaw.
