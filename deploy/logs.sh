#!/bin/bash
# =============================================================================
# OpenClaw Logs Script
# =============================================================================
# Purpose: View Docker container logs from the VPS.
# Usage: ./deploy/logs.sh [VPS_IP]
#
# This script SSHs into the VPS and streams Docker Compose logs.
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

VPS_USER="openclaw"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=" -i $SSH_KEY"
TERRAFORM_DIR="infra/terraform/envs/prod"

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

echo "=== OpenClaw Logs ==="
echo "VPS IP: $VPS_IP"
echo "Press Ctrl+C to exit"
echo ""

# -----------------------------------------------------------------------------
# Stream logs
# -----------------------------------------------------------------------------

ssh $SSH_OPTS -t "$VPS_USER@$VPS_IP" \
    "cd ~/openclaw && docker compose logs -f --tail 100"
