#!/bin/bash
# =============================================================================
# OpenClaw Setup Auth Script
# =============================================================================
# Purpose: Push a Claude setup-token to the VPS for subscription-based auth.
# Usage: ./scripts/setup-auth.sh [VPS_IP]
#
# This script:
#   1. Reads CLAUDE_SETUP_TOKEN from the environment
#   2. Writes auth-profiles.json directly to the VPS host volume
#   3. Restarts the container to pick up the new auth profile
#
# The auth-profiles.json is written to the host at:
#   ~/.openclaw/agents/main/agent/auth-profiles.json
# which is volume-mounted into the container and persists across deploys.
#
# Generate a setup token with:
#   claude setup-token
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

VPS_USER="openclaw"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=" -i $SSH_KEY"
TERRAFORM_DIR="infra/terraform/envs/prod"

CLAUDE_SETUP_TOKEN="${CLAUDE_SETUP_TOKEN:-}"

# -----------------------------------------------------------------------------
# Validate setup token
# -----------------------------------------------------------------------------

if [[ -z "$CLAUDE_SETUP_TOKEN" ]]; then
    echo "Error: CLAUDE_SETUP_TOKEN not set"
    echo ""
    echo "Generate a setup token and export it:"
    echo "  1. Run: claude setup-token"
    echo "  2. Copy the token output"
    echo "  3. Add to config/inputs.sh:"
    echo "     export CLAUDE_SETUP_TOKEN=\"<your-token>\""
    echo "  4. Run: source config/inputs.sh && make setup-auth"
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

echo "=== OpenClaw Setup Auth ==="
echo "VPS IP: $VPS_IP"
echo ""

# -----------------------------------------------------------------------------
# Push setup token to VPS
# -----------------------------------------------------------------------------

AUTH_DIR="\$HOME/.openclaw/agents/main/agent"
AUTH_FILE="\$HOME/.openclaw/agents/main/agent/auth-profiles.json"

echo "[...] Writing auth profile to VPS..."

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" bash -s <<REMOTE_SCRIPT
set -euo pipefail
mkdir -p "$AUTH_DIR"
cat > "$AUTH_FILE" << 'AUTHEOF'
{
  "version": 1,
  "profiles": {
    "anthropic:manual": {
      "type": "token",
      "provider": "anthropic",
      "token": "$CLAUDE_SETUP_TOKEN"
    }
  },
  "order": {
    "anthropic": ["anthropic:manual"]
  }
}
AUTHEOF
chmod 600 "$AUTH_FILE"
echo "[OK] Auth profile written to $AUTH_FILE"
REMOTE_SCRIPT

# -----------------------------------------------------------------------------
# Restart container to pick up changes
# -----------------------------------------------------------------------------

echo ""
echo "[...] Restarting container..."

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "cd ~/openclaw && docker compose restart 2>/dev/null || echo '[SKIP] No running container to restart'"

echo ""
echo "=== Done ==="
echo ""
echo "Your Claude subscription is now configured."
echo "Test it by sending a message on Telegram or the Control UI."
