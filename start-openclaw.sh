#!/usr/bin/env bash
# Start OpenClaw with NAS-mounted storage
set -euo pipefail

export OPENCLAW_CONFIG_DIR=/mnt/raid-storage/nas-share/docker-volume-mounts/openclaw/config
export OPENCLAW_WORKSPACE_DIR=/mnt/raid-storage/nas-share/docker-volume-mounts/openclaw/config/workspace
export OPENCLAW_IMAGE=openclaw:local

cd "$(dirname "$0")"
docker compose "$@"
