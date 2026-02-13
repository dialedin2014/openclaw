# OpenClaw Docker Installation Guide

This document explains the Docker-based installation of OpenClaw and how to use the CLI via the web chat interface.

## Overview

This setup runs OpenClaw in a single Docker container:

- **openclaw-gateway**: Control plane with WebSocket server (port 18789), web UI, and CLI command execution

Configuration and workspace directories are shared via volume mounts.

## Local Values File (Not Committed)

Create a local sidecar file named `SETUP.local.env` (ignored by git) with your machine-specific values:

```bash
OPENCLAW_REPO_DIR="/path/to/openclaw"
OPENCLAW_CONFIG_DIR="/path/to/openclaw/config"
OPENCLAW_WORKSPACE_DIR="/path/to/openclaw/config/workspace"
OPENCLAW_GATEWAY_HOST="<HOST_IP>"
OPENCLAW_GATEWAY_USER="<USER>"
OPENCLAW_IMAGE="openclaw:local"
```

Load it once per shell before running commands in this guide:

```bash
set -a
. ./SETUP.local.env
set +a
```

## Quick Start

### Start the Container

**Using the helper script (recommended):**

```bash
cd "$OPENCLAW_REPO_DIR"

# Start all services
./start-openclaw.sh up -d

# Or use docker compose commands through the script
./start-openclaw.sh ps
./start-openclaw.sh logs -f openclaw-gateway
```

**Manual start with environment variables:**

```bash
cd "$OPENCLAW_REPO_DIR"

# Load local values (SETUP.local.env)
set -a
. ./SETUP.local.env
set +a

# Start the gateway
docker compose up -d
```

### Using the CLI

OpenClaw CLI commands are executed via the **web chat interface** at **http://127.0.0.1:18789/**

Simply type commands in the chat, for example:
- `openclaw status` - Check system health
- `openclaw config get` - View configuration
- `openclaw channels list` - List active channels
- `openclaw doctor` - Run diagnostics

The chat's exec tool runs commands directly in the gateway container.

## File Structure

All data is stored under `$OPENCLAW_CONFIG_DIR`:

```
$OPENCLAW_CONFIG_DIR/
├── openclaw.json           # Main configuration file
├── agents/
│   └── main/              # Default agent workspace
│       ├── agent/         # Agent configuration & credentials
│       └── sessions/      # Conversation sessions
├── workspace/             # Agent workspace (accessible via VS Code SSH)
├── devices/
│   ├── paired.json        # Approved devices
│   └── pending.json       # Pending pairing requests
├── channels/              # Channel-specific state
└── sandbox-browser/       # Sandbox browser profile data
```

**Note:** The `workspace/` directory is designed for collaborative editing. Files created by openclaw are automatically owned by the host user (UID 1000), making them directly accessible via VS Code's SSH plugin or other host-based editors. You can edit agent workspace files, profiles, and other data without permission issues.

## Gateway Container

## Gateway Container

The gateway runs continuously and provides:
- WebSocket control plane (wss://127.0.0.1:18789)
- Web UI chat interface at http://127.0.0.1:18789/
- CLI command execution via exec tool
- Multi-channel message routing
- Agent orchestration

**Important:** The gateway container runs as the `node` user (UID 1000) to ensure proper file permissions on the host. This matches a typical host user UID and allows seamless file access via VS Code SSH or other host tools. The `user: "1000:1000"` directive in `docker-compose.yml` ensures all files created by openclaw have the correct ownership

**View logs:**
```bash
docker compose logs -f openclaw-gateway
```

**Restart:**
```bash
docker compose restart openclaw-gateway
```

**Stop:**
```bash
docker compose stop openclaw-gateway
```

## Common Commands

## Common Commands

All commands below are executed in the **web chat interface** at http://127.0.0.1:18789/

### Setup & Configuration

```bash
# Initial onboarding (interactive wizard)
openclaw onboard

# View current configuration
openclaw config get <path>

# Set a configuration value
openclaw config set gateway.port 18789
```

### Channels

```bash
# Setup WhatsApp (QR code pairing)
openclaw channels login

# Add Telegram bot
openclaw channels add --channel telegram --token "<YOUR_BOT_TOKEN>"

# Add Discord bot
openclaw channels add --channel discord --token "<YOUR_BOT_TOKEN>"

# List active channels
openclaw channels list
```

### Messaging

```bash
# Send a direct message
openclaw message send --to +1234567890 --message "Hello from OpenClaw"

# Talk to the agent directly
openclaw agent --message "What is machine learning?" --thinking high
```

### Diagnostics

```bash
# Health check
openclaw health

# Full system diagnostics
openclaw doctor

# Deep security audit
openclaw security audit --deep

# View system status
openclaw status

# Follow live logs
openclaw logs --follow
```

### Device Pairing

```bash
# List paired and pending devices
openclaw devices list

# Approve a pending pairing request
openclaw devices approve <device-id>

# Reject a pending request
openclaw devices reject <device-id>

# Rotate a device token
openclaw devices rotate <device-id> operator
```

## Chrome Extension + Browser Relay Tunnel (Remote Workstation)

If Chrome runs on a different machine than the Gateway, the browser relay runs on that LAN
workstation. Use the tunnel script and install the extension locally on the workstation.

### Install (workstation)

Use the contents of `$OPENCLAW_CONFIG_DIR/chrome-extension` to
set up the workstation.

1. Copy the tunnel script to the workstation and make it executable:

```bash
cp "$OPENCLAW_CONFIG_DIR/chrome-extension/browser-relay-tunnel.sh" ~/
chmod +x ~/browser-relay-tunnel.sh
```

2. Start the tunnel (uses `OPENCLAW_GATEWAY_HOST` and `OPENCLAW_GATEWAY_USER` from `SETUP.local.env`):

```bash
~/browser-relay-tunnel.sh start
```

3. Install the extension locally on the workstation (requires OpenClaw CLI installed there):

```bash
openclaw browser extension install
openclaw browser extension path
```

4. Chrome → `chrome://extensions` → enable Developer mode → Load unpacked → select the printed path.

5. In the extension Options, set the relay URL to `http://127.0.0.1:18792`.

### Uninstall (workstation)

1. Stop the tunnel:

```bash
~/browser-relay-tunnel.sh stop
```

2. Remove or disable the extension in `chrome://extensions` (there is no Chrome CLI uninstall).

3. Optionally remove the extension folder printed by `openclaw browser extension path` and delete
   the tunnel script from the workstation.

## Sandbox Browser (VNC + CDP)

For browser automation requiring manual logins or full control, use the sandbox browser container. This provides a headful Chromium instance with VNC access for manual interaction and CDP (Chrome DevTools Protocol) for agent automation.

### Overview

The sandbox browser (`Dockerfile.sandbox-browser`) runs in its own container with:
- **Chromium** browser in a virtual display (Xvfb)
- **VNC server** (x11vnc) for remote desktop access
- **noVNC** web interface for browser-based VNC access
- **CDP endpoint** for programmatic control by the OpenClaw agent

This setup enables:
1. **Manual login** via VNC/noVNC to authenticate on sites with anti-bot protection
2. **Agent automation** via CDP once authenticated
3. **Session persistence** through shared browser profile volumes

### Ports & Environment Variables

**Exposed ports:**
- `9222` - CDP (Chrome DevTools Protocol)
- `5900` - VNC
- `6080` - noVNC (web-based VNC client)

**Environment variables:**
- `OPENCLAW_BROWSER_CDP_PORT` - CDP port (default: `9222`)
- `OPENCLAW_BROWSER_VNC_PORT` - VNC port (default: `5900`)
- `OPENCLAW_BROWSER_NOVNC_PORT` - noVNC web interface port (default: `6080`)
- `OPENCLAW_BROWSER_ENABLE_NOVNC` - Enable noVNC web interface (default: `1`)
- `OPENCLAW_BROWSER_HEADLESS` - Run in headless mode (default: `0`)

### Starting the Sandbox Browser

The sandbox browser service is already configured in `docker-compose.yml`. Build and start:

```bash
# Build the sandbox browser image
docker build -t openclaw-sandbox-browser:local -f Dockerfile.sandbox-browser .

# Start the container
docker compose up -d openclaw-sandbox-browser
```

### Manual Login Flow

**Step 1: Access the browser via noVNC**

Open `http://127.0.0.1:6080/vnc.html` in your regular browser. You'll see the sandbox Chromium instance.

**Step 2: Log in manually**

Navigate to the site (e.g., X/Twitter, LinkedIn) and complete the login flow manually. This bypasses anti-bot detection that often blocks automated logins.

**Step 3: Agent uses the authenticated session**

Once logged in, the agent can control the browser via CDP using the persisted session.

> **Why manual login?** Sites with strict anti-bot defenses (X/Twitter, LinkedIn, banking) often block automated logins. Manual login via VNC establishes a trusted session that the agent can then use for automation tasks.
>
> See [docs/tools/browser-login.md](docs/tools/browser-login.md) for more details on manual login workflows.

### Connecting the Gateway to Sandbox Browser CDP

The gateway is already configured to use the sandbox browser profile. The configuration in `~/.openclaw/openclaw.json` includes:

```json5
{
  "browser": {
    "defaultProfile": "sandbox",
    "profiles": {
      "sandbox": {
        "cdpUrl": "http://127.0.0.1:9222",
        "color": "#00AA00"
      },
      "chrome": {
        "cdpUrl": "http://127.0.0.1:18792",
        "color": "#FF4500"
      }
    }
  }
}
```

Specify the profile in browser commands:

```bash
openclaw browser --browser-profile sandbox open https://x.com
openclaw browser --browser-profile sandbox snapshot
```

> **Note:** After modifying the browser configuration, restart the gateway for changes to take effect:
> ```bash
> docker compose restart openclaw-gateway
> ```

> See [docs/tools/browser.md](docs/tools/browser.md) for complete browser configuration and profile management.

### Future Automation

The sandbox browser is designed to support full automation workflows:
- **Current:** Manual login via VNC + agent automation via CDP
- **Planned:** Automated captcha solving, credential injection, profile management

For automation strategies and advanced usage, see [docs/tools/browser.md](docs/tools/browser.md).

### Viewing Logs

```bash
docker compose logs -f openclaw-sandbox-browser
```

### Stopping the Sandbox Browser

```bash
docker compose stop openclaw-sandbox-browser
```

## Troubleshooting

### Gateway Won't Start

**Check if the port is already in use:**
```bash
lsof -i :18789
# Kill the process if needed:
kill -9 <PID>
```

**Check gateway logs:**
```bash
docker compose logs openclaw-gateway | tail -50
```

**Restart the gateway:**
```bash
docker compose restart openclaw-gateway
```

### CLI Can't Connect to Gateway

**Symptom:** `Error: gateway closed (1006 abnormal closure)`

**Cause:** The gateway is either not running or network connectivity is broken.

**Solutions:**
1. Check if gateway container is running:
   ```bash
   docker compose ps
   ```

2. Check gateway is listening:
   ```bash
   docker exec openclaw-openclaw-gateway-1 ss -tlnp | grep 18789
   ```

3. Verify gateway is accepting connections:
   ```bash
   docker compose logs openclaw-gateway | grep "listening"
   ```

### Configuration Issues

**File permission errors (EACCES):**

If the container can't read/write files in the mounted directories, check ownership:

```bash
# Check current ownership
ls -la "$OPENCLAW_CONFIG_DIR"

# If files are owned by root, fix permissions
sudo chown -R "$USER":"$USER" "$OPENCLAW_CONFIG_DIR"

# Restart the gateway
docker compose restart openclaw-gateway
```

**Note:** The container runs as `node` user (UID 1000) via the `user: "1000:1000"` directive in `docker-compose.yml`. This ensures files are created with proper ownership matching your host user. If you're using a different UID, adjust the `user:` directive accordingly:

```bash
# Check your UID
id -u

# Update docker-compose.yml if needed:
# user: "YOUR_UID:YOUR_GID"
```

**Forgot the gateway token:**
```bash
cat "$OPENCLAW_CONFIG_DIR/openclaw.json" | grep -A 5 '"token"'
```

**Reset to defaults:**
```bash
./cli.sh reset
# Then run onboarding again:
./cli.sh onboard
```

**Too-open file permissions warning:**
```bash
chmod 700 "$OPENCLAW_CONFIG_DIR"
chmod 600 "$OPENCLAW_CONFIG_DIR/agents/main/agent/auth-profiles.json"
```

## Environment Variables

These can be set before running `docker compose` (recommended: put them in `SETUP.local.env`):

```bash
# Configuration directories (NAS-mounted for backup and persistence)
OPENCLAW_CONFIG_DIR="/path/to/openclaw/config"
OPENCLAW_WORKSPACE_DIR="/path/to/openclaw/config/workspace"

# Gateway settings
OPENCLAW_GATEWAY_PORT="18789"          # Gateway WebSocket port
OPENCLAW_BRIDGE_PORT="18790"           # Bridge port
OPENCLAW_GATEWAY_BIND="lan"            # "loopback" or "lan"
OPENCLAW_GATEWAY_TOKEN="..."           # Auth token

# CLI SSH
OPENCLAW_CLI_SSH_PORT="2222"           # SSH port to container
OPENCLAW_SSH_PUBKEY="$OPENCLAW_CONFIG_DIR/ssh/id_rsa.pub"

# Docker image
OPENCLAW_IMAGE="openclaw:local"        # Docker image to use

# Optional: API keys (set these for model access)
ANTHROPIC_API_KEY="sk-..."
OPENAI_API_KEY="sk-..."
```

## Building the Docker Image

If you need to rebuild the image:

```bash
cd "$OPENCLAW_REPO_DIR"

# Standard build
docker build -t openclaw:local -f Dockerfile .

# With extra system packages
export OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg build-essential"
docker build -t openclaw:local -f Dockerfile .

# Build from scratch (no cache)
docker build --no-cache -t openclaw:local -f Dockerfile .
```

## Stopping & Cleanup

### Stop Containers

```bash
# Stop just the CLI
docker compose stop openclaw-cli

# Stop just the gateway
docker compose stop openclaw-gateway

# Stop everything
docker compose down
```

### Preserve Data While Cleaning Up

```bash
# Stop and remove containers (but keep volumes)
docker compose down

# Containers are removed, but ~/.openclaw data persists
# Restart anytime:
docker compose up -d
```

### Full Cleanup (Remove Everything)

```bash
# Remove containers AND volumes (DELETES DATA!)
docker compose down -v

# Remove the image
docker rmi openclaw:local

# Remove NAS config (DELETES DATA!)
rm -rf "$OPENCLAW_CONFIG_DIR"
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Host Machine (127.0.0.1)                                    │
│                                                              │
│  ~/.openclaw/  (volumes shared with containers)             │
│  ├── openclaw.json                                          │
│  ├── agents/                                                │
│  ├── workspace/                                             │
│  ├── devices/                                               │
│  └── ssh/                                                   │
│                                                              │
│  Port 18789 → openclaw-gateway:18789 (Gateway WebSocket)    │
│  Port 2222  → openclaw-cli:22 (SSH)                         │
└─────────────────────────────────────────────────────────────┘
           │                                  │
           ▼                                  ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│ openclaw-gateway         │    │ openclaw-cli             │
│ (Docker Container)       │    │ (Docker Container)       │
│                          │    │                          │
│ - Node.js process        │    │ - SSH daemon             │
│ - Gateway WS server      │    │ - Node.js CLI            │
│ - Channel routers        │    │ - Interactive shell      │
│ - Agent orchestrator     │    │ - Command execution      │
└──────────────────────────┘    └──────────────────────────┘
           │                                  │
           └──────────────────┬───────────────┘
                              │
                    ┌─────────▼────────┐
                    │ Docker Network   │
                    │ 172.18.0.0/16    │
                    └──────────────────┘
```

## Tips & Best Practices

1. **Use `./cli.sh` wrapper** for convenience instead of manually specifying SSH
2. **Keep API keys secure** - never commit `~/.openclaw/auth-profiles.json` to git
3. **Monitor gateway logs** during setup: `docker compose logs -f openclaw-gateway`
4. **Use `--local` flag** when testing: `./cli.sh agent --local --message "test"`
5. **Check `doctor`** before troubleshooting: `./cli.sh doctor` shows common issues
6. **Backup configuration** before major changes: `cp -r "$OPENCLAW_CONFIG_DIR" "${OPENCLAW_CONFIG_DIR}.backup"`
7. **Direct file editing** - The workspace directory is accessible via VS Code SSH thanks to matching UID configuration; edit files directly without copying in/out of containers

## Further Reading

### Online Documentation
- **Official Docs:** https://docs.openclaw.ai
- **CLI Reference:** https://docs.openclaw.ai/cli
- **Channels Guide:** https://docs.openclaw.ai/channels
- **Security:** https://docs.openclaw.ai/gateway/security
- **Gateway:** https://docs.openclaw.ai/gateway

### Local Documentation
Complete documentation is available locally under `$OPENCLAW_REPO_DIR/docs/`:

#### Getting Started
- [docs/start/](docs/start/) - Installation and initial setup guides
- [docs/install/](docs/install/) - Detailed installation instructions
- [docs/concepts/](docs/concepts/) - Core OpenClaw concepts

#### Core Features
- [docs/cli/](docs/cli/) - Complete CLI command reference (40+ commands)
- [docs/channels/](docs/channels/) - Channel integration guides (WhatsApp, Telegram, Discord, etc.)
- [docs/gateway/](docs/gateway/) - Gateway architecture and configuration
- [docs/automation/](docs/automation/) - Browser and task automation
- [docs/tools/](docs/tools/) - Available tools and integrations

#### Advanced Topics
- [docs/security/](docs/security/) - Security configuration and best practices
- [docs/plugins/](docs/plugins/) - Plugin development and extensibility
- [docs/providers/](docs/providers/) - LLM provider integration (Anthropic, OpenAI, Bedrock, etc.)
- [docs/platforms/](docs/platforms/) - Deployment platforms (Railway, Render, Fly.io, etc.)
- [docs/web/](docs/web/) - Web interface and UI customization
- [docs/nodes/](docs/nodes/) - Node types and agent architectures
- [docs/debugging/](docs/debugging/) - Debugging and troubleshooting

#### Reference
- [docs/reference/](docs/reference/) - API references and technical specifications
- [docs/environment.md](docs/environment.md) - Environment variable reference
- [docs/logging.md](docs/logging.md) - Logging configuration
- [docs/testing.md](docs/testing.md) - Testing guidelines
- [docs/token-use.md](docs/token-use.md) - Token usage and optimization

#### Root Level Documentation
- [README.md](README.md) - Project overview
- [AGENTS.md](AGENTS.md) - Agent configuration and management
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [SECURITY.md](SECURITY.md) - Security policy
- [CHANGELOG.md](CHANGELOG.md) - Version history and changes
- [CLAUDE.md](CLAUDE.md) - Claude-specific setup and guidelines
