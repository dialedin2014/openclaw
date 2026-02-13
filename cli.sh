#!/bin/bash
# Convenient wrapper for accessing the OpenClaw CLI container via SSH

set -e

# Determine SSH key and port
SSH_KEY="${HOME}/.openclaw/ssh/id_rsa"
SSH_PORT="${OPENCLAW_CLI_SSH_PORT:-2222}"
SSH_HOST="${OPENCLAW_CLI_HOST:-localhost}"

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
  echo "Error: SSH key not found at $SSH_KEY"
  echo "Please run: ./docker-setup.sh"
  exit 1
fi

# Execute command or start interactive shell
if [ $# -eq 0 ]; then
  # Interactive shell
  ssh -i "$SSH_KEY" -p "$SSH_PORT" "node@${SSH_HOST}"
else
  # Run specific command through the CLI
  ssh -i "$SSH_KEY" -p "$SSH_PORT" "node@${SSH_HOST}" "node /app/dist/index.js" "$@"
fi
