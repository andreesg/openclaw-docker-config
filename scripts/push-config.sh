#!/bin/bash
# =============================================================================
# OpenClaw Push Config Script
# =============================================================================
# Purpose: Push config files from the local config repo to the VPS.
# Usage: ./scripts/push-config.sh [VPS_IP]
#
# This script:
#   1. Reads config files from CONFIG_DIR (local openclaw-config repo)
#   2. SCPs them to the VPS at ~/.openclaw/
#   3. Restarts the container to pick up changes
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

VPS_USER="openclaw"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=" -i $SSH_KEY"
TERRAFORM_DIR="infra/terraform/envs/prod"

# Local path to the openclaw-config repository
CONFIG_DIR="${CONFIG_DIR:-}"

# Remote config directory
REMOTE_CONFIG_DIR="/home/openclaw/.openclaw"

# -----------------------------------------------------------------------------
# Validate CONFIG_DIR
# -----------------------------------------------------------------------------

if [[ -z "$CONFIG_DIR" ]]; then
    echo "Error: CONFIG_DIR not set"
    echo ""
    echo "Set it in config/inputs.sh or export it:"
    echo "  export CONFIG_DIR=/path/to/your/openclaw-config"
    exit 1
fi

if [[ ! -d "$CONFIG_DIR/config" ]]; then
    echo "Error: $CONFIG_DIR/config directory not found"
    echo ""
    echo "Make sure CONFIG_DIR points to your openclaw-config repository"
    exit 1
fi

# -----------------------------------------------------------------------------
# Get VPS IP
# -----------------------------------------------------------------------------

if [[ -n "${1:-}" ]]; then
    VPS_IP="$1"
else
    if command -v terraform &> /dev/null && [[ -d "$TERRAFORM_DIR/.terraform" ]]; then
        VPS_IP=$(cd "$TERRAFORM_DIR" && terraform output -raw server_ip 2>/dev/null) || {
            echo "Error: Could not get VPS IP from terraform output."
            echo "Usage: $0 <VPS_IP>"
            exit 1
        }
    else
        echo "Error: No VPS IP provided and terraform not available."
        echo "Usage: $0 <VPS_IP>"
        exit 1
    fi
fi

echo "=== OpenClaw Push Config ==="
echo "VPS IP: $VPS_IP"
echo "Config Dir: $CONFIG_DIR"
echo ""

# -----------------------------------------------------------------------------
# Push config files
# -----------------------------------------------------------------------------

echo "[...] Pushing config files to VPS..."

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" "mkdir -p $REMOTE_CONFIG_DIR && chmod 700 $REMOTE_CONFIG_DIR"

FILE_COUNT=0
for file in "$CONFIG_DIR"/config/*; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        scp $SSH_OPTS "$file" "$VPS_USER@$VPS_IP:$REMOTE_CONFIG_DIR/$filename"
        echo "[OK] Pushed $filename"
        FILE_COUNT=$((FILE_COUNT + 1))
    fi
done

if [[ $FILE_COUNT -eq 0 ]]; then
    echo "[SKIP] No config files found in $CONFIG_DIR/config/"
    exit 0
fi

# Set secure permissions on config files only (not subdirectories)
ssh $SSH_OPTS "$VPS_USER@$VPS_IP" "find $REMOTE_CONFIG_DIR -maxdepth 1 -type f -exec chmod 600 {} +"

echo ""
echo "[OK] Pushed $FILE_COUNT config file(s)"

# -----------------------------------------------------------------------------
# Restart container to pick up changes
# -----------------------------------------------------------------------------

echo ""
echo "[...] Restarting container..."

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "cd ~/openclaw && docker compose restart 2>/dev/null || echo '[SKIP] No running container to restart'"

echo ""
echo "=== Done ==="
