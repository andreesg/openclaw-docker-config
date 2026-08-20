#!/bin/bash
# =============================================================================
# OpenClaw Push Environment Script
# =============================================================================
# Purpose: Push secrets/openclaw.env to the VPS as the Docker .env file.
# Usage: ./scripts/push-env.sh [VPS_IP]
#
# This script:
#   1. Reads secrets/openclaw.env
#   2. Validates required vars are non-empty
#   3. SCPs it to openclaw@VPS:/home/openclaw/openclaw/.env
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

VPS_USER="openclaw"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=" -i $SSH_KEY"
TERRAFORM_DIR="infra/terraform/envs/prod"
ENV_FILE="secrets/openclaw.env"
REMOTE_PATH="/home/openclaw/openclaw/.env"

# Required variables that must be non-empty
REQUIRED_VARS=(
    TELEGRAM_BOT_TOKEN
    OPENCLAW_GATEWAY_TOKEN
)

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

# -----------------------------------------------------------------------------
# Validate env file exists
# -----------------------------------------------------------------------------

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: $ENV_FILE not found"
    echo ""
    echo "Create it from the example:"
    echo "  cp secrets/openclaw.env.example secrets/openclaw.env"
    echo "  vim secrets/openclaw.env"
    exit 1
fi

echo "=== OpenClaw Push Environment ==="
echo "VPS IP: $VPS_IP"
echo "Source: $ENV_FILE"
echo "Target: $VPS_USER@$VPS_IP:$REMOTE_PATH"
echo ""

# -----------------------------------------------------------------------------
# Validate required variables
# -----------------------------------------------------------------------------

echo "[...] Validating required variables..."

MISSING=()
for var in "${REQUIRED_VARS[@]}"; do
    # Read the value from the env file (skip comments and empty lines)
    value=$(grep -E "^${var}=" "$ENV_FILE" | head -1 | cut -d= -f2-)
    if [[ -z "$value" ]]; then
        MISSING+=("$var")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    echo "Error: The following required variables are empty in $ENV_FILE:"
    for var in "${MISSING[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Fill them in and try again."
    exit 1
fi

echo "[OK] All required variables are set"

# Warn if no API key (setup-token may be used instead)
api_key_value=$(grep -E "^ANTHROPIC_API_KEY=" "$ENV_FILE" | head -1 | cut -d= -f2-)
if [[ -z "$api_key_value" ]]; then
    echo "[WARN] ANTHROPIC_API_KEY is empty. Make sure you've run 'make setup-auth' for subscription auth."
fi

# -----------------------------------------------------------------------------
# Push env file to VPS
# -----------------------------------------------------------------------------

echo ""
echo "[...] Pushing $ENV_FILE to VPS..."

scp $SSH_OPTS "$ENV_FILE" "$VPS_USER@$VPS_IP:$REMOTE_PATH"

echo "[OK] Environment file deployed to $REMOTE_PATH"

# -----------------------------------------------------------------------------
# Restart container to pick up changes
# -----------------------------------------------------------------------------

echo ""
echo "[...] Restarting container..."

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "cd ~/openclaw && docker compose restart 2>/dev/null || echo '[SKIP] No running container to restart'"

echo ""
echo "=== Done ==="
