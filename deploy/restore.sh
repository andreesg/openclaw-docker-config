#!/bin/bash
# =============================================================================
# OpenClaw Restore Script
# =============================================================================
# Purpose: Restore from a backup archive.
# Usage: ./deploy/restore.sh <backup_filename> [VPS_IP]
#
# This script:
#   1. Stops the Docker container
#   2. Extracts the backup archive to ~/.openclaw
#   3. Restarts the container
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
# Parse arguments
# -----------------------------------------------------------------------------

if [[ -z "${1:-}" ]]; then
    echo "Error: Backup filename required"
    echo ""
    echo "Usage: $0 <backup_filename> [VPS_IP]"
    echo ""
    echo "Examples:"
    echo "  $0 openclaw_backup_20240115_030000.tar.gz"
    echo "  $0 openclaw_backup_20240115_030000.tar.gz 192.168.1.100"
    echo ""
    echo "To list available backups, run:"
    echo "  ssh openclaw@VPS_IP 'ls -la ~/backups/'"
    exit 1
fi

BACKUP_FILE="$1"
VPS_IP="${2:-}"

# -----------------------------------------------------------------------------
# Get VPS IP
# -----------------------------------------------------------------------------

if [[ -z "$VPS_IP" ]]; then
    if command -v terraform &> /dev/null && [[ -d "$TERRAFORM_DIR/.terraform" ]]; then
        VPS_IP=$(cd "$TERRAFORM_DIR" && terraform output -raw server_ip 2>/dev/null) || {
            echo "Error: Could not get VPS IP from terraform output."
            echo "Usage: $0 <backup_filename> <VPS_IP>"
            exit 1
        }
    else
        echo "Error: No VPS IP provided and terraform not available."
        echo "Usage: $0 <backup_filename> <VPS_IP>"
        exit 1
    fi
fi

echo "=== OpenClaw Restore ==="
echo "VPS IP: $VPS_IP"
echo "Backup: $BACKUP_FILE"
echo ""

# -----------------------------------------------------------------------------
# Confirm restore
# -----------------------------------------------------------------------------

echo "WARNING: This will:"
echo "  1. Stop the Docker container"
echo "  2. Replace ~/.openclaw with the backup contents"
echo "  3. Restart the container"
echo ""

read -p "Are you sure you want to restore from this backup? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled"
    exit 0
fi

# -----------------------------------------------------------------------------
# Restore on VPS
# -----------------------------------------------------------------------------

echo ""
echo "Restoring backup..."
echo ""

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" bash -s "$BACKUP_FILE" << 'REMOTE_SCRIPT'
set -euo pipefail

BACKUP_FILE="$1"
BACKUP_DIR="$HOME/backups"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

echo "=== Restoring OpenClaw Backup ==="
echo ""

# -----------------------------------------------------------------------------
# Verify backup exists
# -----------------------------------------------------------------------------

if [[ ! -f "$BACKUP_PATH" ]]; then
    echo "Error: Backup file not found: $BACKUP_PATH"
    echo ""
    echo "Available backups:"
    ls -la "$BACKUP_DIR"/openclaw_backup_*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

echo "[OK] Found backup: $BACKUP_PATH"

# -----------------------------------------------------------------------------
# Stop Docker container
# -----------------------------------------------------------------------------

echo ""
echo "[...] Stopping Docker container..."

cd "$HOME/openclaw" 2>/dev/null || cd "$HOME"

if docker compose ps --quiet 2>/dev/null | grep -q .; then
    docker compose stop
    echo "[OK] Container stopped"
else
    echo "[SKIP] No running containers"
fi

# -----------------------------------------------------------------------------
# Backup current state (just in case)
# -----------------------------------------------------------------------------

if [[ -d "$HOME/.openclaw" ]]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    echo ""
    echo "[...] Creating safety backup of current state..."
    tar -czf "$BACKUP_DIR/openclaw_pre_restore_$TIMESTAMP.tar.gz" -C "$HOME" ".openclaw"
    echo "[OK] Safety backup created"
fi

# -----------------------------------------------------------------------------
# Restore from backup
# -----------------------------------------------------------------------------

echo ""
echo "[...] Extracting backup..."

# Remove current .openclaw directory
rm -rf "$HOME/.openclaw"

# Extract backup
tar -xzf "$BACKUP_PATH" -C "$HOME"

echo "[OK] Backup extracted to ~/.openclaw"

# -----------------------------------------------------------------------------
# Restart Docker container
# -----------------------------------------------------------------------------

echo ""
echo "[...] Restarting Docker container..."

cd "$HOME/openclaw"

if [[ -f "docker-compose.yml" ]]; then
    docker compose up -d
    echo "[OK] Container restarted"
else
    echo "[SKIP] No docker-compose.yml found"
fi

echo ""
echo "=== Restore Complete ==="
echo ""
echo "Restored from: $BACKUP_FILE"
REMOTE_SCRIPT

echo ""
echo "Restore completed successfully!"
