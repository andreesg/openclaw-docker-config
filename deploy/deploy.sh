#!/bin/bash
# =============================================================================
# OpenClaw Deploy Script
# =============================================================================
# Purpose: Pull the latest Docker image and restart the container.
# Usage: ./deploy/deploy.sh [VPS_IP]
#
# This script:
#   1. Pulls the latest image from GHCR
#   2. Restarts the container with the new image
#   3. Cleans up old images
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

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo -e "${BOLD}OpenClaw Deploy${NC}  ${DIM}$VPS_IP${NC}"
echo ""

# -----------------------------------------------------------------------------
# Deploy on VPS
# -----------------------------------------------------------------------------

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" bash -s << 'REMOTE_SCRIPT'

# Colors
G='\033[0;32m'
R='\033[0;31m'
B='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

cd "$HOME/openclaw" 2>/dev/null || {
    echo -e "${R}Error:${NC} ~/openclaw directory not found. Run bootstrap first."
    exit 1
}

if [[ ! -f "docker-compose.yml" ]]; then
    echo -e "${R}Error:${NC} docker-compose.yml not found. Run bootstrap first."
    exit 1
fi

# Pre-create workspace directories so Docker doesn't create them as root.
# When a bind-mount target doesn't exist, Docker creates it owned by root,
# which causes EACCES errors in the gateway container (runs as uid 1000).
WORKSPACE_BASE="${OPENCLAW_WORKSPACE_DIR:-$HOME/.openclaw/workspace}"
if [[ -f docker-compose.yml ]]; then
    grep -oP '(?<=\$\{OPENCLAW_WORKSPACE_DIR:-/home/openclaw/.openclaw/workspace\}/)\w+(?=:)' docker-compose.yml \
        | sort -u \
        | while read -r agent; do
            mkdir -p "$WORKSPACE_BASE/$agent"
        done
fi

# Enable workspace sync profile if GIT_WORKSPACE_REPO or GIT_WORKSPACE_REMOTE is configured
PROFILES=""
SYNC_ENABLED=false
if [[ -f .env ]] && grep -qE '^GIT_WORKSPACE_(REPO|REMOTE)(_[A-Z]+)?=.+' .env; then
    PROFILES="--profile sync"
    SYNC_ENABLED=true
fi

# Pull
echo -e "${BOLD}Pull${NC}"
echo ""
echo -ne "  Pulling latest image...  "
if docker compose $PROFILES pull --quiet 2>/dev/null; then
    echo -e "${G}done${NC}"
else
    echo -e "${R}failed${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}Restart${NC}"
echo ""
echo -ne "  Starting container...    "
if docker compose $PROFILES up -d 2>/dev/null; then
    echo -e "${G}done${NC}"
else
    echo -e "${R}failed${NC}"
    exit 1
fi

# Stop workspace-sync containers if they were running but sync is now disabled
if [[ "$SYNC_ENABLED" == "false" ]]; then
    if docker compose ps --format '{{.Name}}' 2>/dev/null | grep -q workspace-sync; then
        echo -ne "  Stopping workspace-sync...  "
        docker compose ps --format '{{.Name}}' 2>/dev/null | grep workspace-sync | xargs -r docker compose stop 2>/dev/null
        docker compose ps -a --format '{{.Name}}' 2>/dev/null | grep workspace-sync | xargs -r docker compose rm -f 2>/dev/null
        echo -e "${G}done${NC}"
    fi
fi

# Cleanup
echo ""
echo -e "${BOLD}Cleanup${NC}"
echo ""
PRUNED=$(docker image prune -f 2>/dev/null | grep "Total reclaimed" || echo "Nothing to reclaim")
echo -e "  ${DIM}${PRUNED}${NC}"

# Verify
echo ""
echo -e "${BOLD}Status${NC}"
echo ""
sleep 2
while IFS= read -r line; do
    NAME=$(echo "$line" | cut -f1)
    STATUS=$(echo "$line" | cut -f2-)
    if echo "$STATUS" | grep -q "Up"; then
        echo -e "  ${G}●${NC} ${NAME}  ${G}${STATUS}${NC}"
    else
        echo -e "  ${R}●${NC} ${NAME}  ${R}${STATUS}${NC}"
    fi
done < <(docker compose ps --format '{{.Name}}\t{{.Status}}' 2>/dev/null)

echo ""
echo -e "${G}Deploy complete${NC}"
echo ""
REMOTE_SCRIPT
