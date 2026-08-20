#!/bin/bash
# =============================================================================
# OpenClaw Status Script
# =============================================================================
# Purpose: Check the status of OpenClaw on the VPS.
# Usage: ./deploy/status.sh [VPS_IP]
#
# This script:
#   1. Shows Docker Compose container status
#   2. Shows recent container logs
#   3. Shows system info (disk, memory, uptime)
#   4. Shows Tailscale VPN status (if installed)
#   5. Shows backup status
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
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo -e "${BOLD}OpenClaw Status${NC}  ${DIM}$VPS_IP${NC}"
echo ""

# -----------------------------------------------------------------------------
# Check status on VPS
# -----------------------------------------------------------------------------

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" bash -s << 'REMOTE_SCRIPT'

# Colors
G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Docker Compose status
# -----------------------------------------------------------------------------

cd "$HOME/openclaw" 2>/dev/null || {
    echo -e "${R}Error:${NC} ~/openclaw directory not found. Run bootstrap first."
    exit 1
}

echo -e "${BOLD}Containers${NC}"
echo ""
echo -e "  ${DIM}NAME                          STATUS${NC}"

if [[ -f "docker-compose.yml" ]]; then
    while IFS= read -r line; do
        NAME=$(echo "$line" | cut -f1)
        STATUS=$(echo "$line" | cut -f2-)
        if echo "$STATUS" | grep -q "Up"; then
            echo -e "  ${G}●${NC} ${NAME}  ${G}${STATUS}${NC}"
        elif echo "$STATUS" | grep -q "Restarting\|Exit"; then
            echo -e "  ${R}●${NC} ${NAME}  ${R}${STATUS}${NC}"
        else
            echo -e "  ○ ${NAME}  ${STATUS}"
        fi
    done < <(docker compose ps --format '{{.Name}}\t{{.Status}}' 2>/dev/null)
else
    echo -e "  ${Y}No docker-compose.yml found${NC}"
fi

# -----------------------------------------------------------------------------
# Container logs
# -----------------------------------------------------------------------------

echo ""
echo -e "${BOLD}Recent Logs${NC}"
echo ""

if docker compose ps --quiet 2>/dev/null | grep -q .; then
    docker compose logs --tail=10 --no-log-prefix 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${DIM}${line}${NC}"
    done
else
    echo -e "  ${Y}No running containers${NC}"
fi

# -----------------------------------------------------------------------------
# System info
# -----------------------------------------------------------------------------

echo ""
echo -e "${BOLD}System${NC}"
echo ""

# Disk
DISK_LINE=$(df -h / | tail -1)
DISK_USED=$(echo "$DISK_LINE" | awk '{print $5}' | tr -d '%')
DISK_INFO=$(echo "$DISK_LINE" | awk '{printf "%s / %s (%s)", $3, $2, $5}')
if [ "$DISK_USED" -gt 90 ] 2>/dev/null; then
    echo -e "  ${R}Disk:${NC}    $DISK_INFO"
elif [ "$DISK_USED" -gt 70 ] 2>/dev/null; then
    echo -e "  ${Y}Disk:${NC}    $DISK_INFO"
else
    echo -e "  ${G}Disk:${NC}    $DISK_INFO"
fi

# Memory
MEM_INFO=$(free -h | awk 'NR==2{printf "%s / %s", $3, $2}')
echo -e "  ${G}Memory:${NC}  $MEM_INFO"

# Uptime
UP=$(uptime | sed 's/.*up /up /' | sed 's/,.*user.*//')
echo -e "  ${G}Uptime:${NC}  $UP"

# -----------------------------------------------------------------------------
# Tailscale status
# -----------------------------------------------------------------------------

if command -v tailscale &> /dev/null; then
    echo ""
    echo -e "${BOLD}Tailscale${NC}"
    echo ""

    TS_STATE=$(sudo tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "unknown")
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "N/A")

    if [ "$TS_STATE" = "Running" ]; then
        echo -e "  ${G}Status:${NC}  Connected"
        echo -e "  ${G}IP:${NC}      $TS_IP"
    elif [ "$TS_STATE" = "NeedsLogin" ]; then
        echo -e "  ${Y}Status:${NC}  Not authenticated"
        echo -e "  ${DIM}Run 'sudo tailscale up' to authenticate${NC}"
    else
        echo -e "  ${Y}Status:${NC}  $TS_STATE"
        echo -e "  ${DIM}IP:      $TS_IP${NC}"
    fi
fi

# -----------------------------------------------------------------------------
# Backup status
# -----------------------------------------------------------------------------

echo ""
echo -e "${BOLD}Backups${NC}"
echo ""

LATEST=$(ls -1t "$HOME/backups"/openclaw_backup_*.tar.gz 2>/dev/null | head -1 || true)
if [ -n "$LATEST" ]; then
    COUNT=$(ls -1 "$HOME/backups"/openclaw_backup_*.tar.gz 2>/dev/null | wc -l || echo "0")
    SIZE=$(du -sh "$LATEST" 2>/dev/null | awk '{print $1}')
    NAME=$(basename "$LATEST")
    echo -e "  ${G}Latest:${NC}  $NAME ($SIZE)"
    echo -e "  ${DIM}Total:   $COUNT backup(s)${NC}"
else
    echo -e "  ${DIM}No backups found${NC}"
fi

echo ""
REMOTE_SCRIPT
