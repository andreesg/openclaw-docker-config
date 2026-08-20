#!/bin/bash
# =============================================================================
# OpenClaw Backup Script
# =============================================================================
# Purpose: Creates a backup of ~/.openclaw directory.
# Usage: Run on the VPS directly, or called by systemd timer.
#
# This script:
#   1. Creates a timestamped tar.gz of ~/.openclaw
#   2. Stores it in ~/backups/
#   3. Removes backups older than 7 days
#
# Note: This script is meant to run ON the VPS, not from your laptop.
#       For remote backup, use: ssh openclaw@VPS ./deploy/backup.sh
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

BACKUP_DIR="$HOME/backups"
SOURCE_DIR="$HOME/.openclaw"
RETENTION_DAYS=7

# -----------------------------------------------------------------------------
# Create backup directory
# -----------------------------------------------------------------------------

mkdir -p "$BACKUP_DIR"

# -----------------------------------------------------------------------------
# Check if source exists
# -----------------------------------------------------------------------------

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Warning: Source directory $SOURCE_DIR does not exist"
    echo "Nothing to backup"
    exit 0
fi

# -----------------------------------------------------------------------------
# Create backup
# -----------------------------------------------------------------------------

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/openclaw_backup_$TIMESTAMP.tar.gz"

echo "=== OpenClaw Backup ==="
echo "Source: $SOURCE_DIR"
echo "Destination: $BACKUP_FILE"
echo ""

echo "[...] Creating backup..."

# Create tar.gz archive
tar -czf "$BACKUP_FILE" -C "$HOME" ".openclaw"

# Get backup size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo "[OK] Backup created: $BACKUP_FILE ($BACKUP_SIZE)"

# -----------------------------------------------------------------------------
# Clean up old backups
# -----------------------------------------------------------------------------

echo ""
echo "[...] Cleaning up backups older than $RETENTION_DAYS days..."

# Find and delete old backups
OLD_COUNT=$(find "$BACKUP_DIR" -name "openclaw_backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS | wc -l)

if [[ $OLD_COUNT -gt 0 ]]; then
    find "$BACKUP_DIR" -name "openclaw_backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
    echo "[OK] Deleted $OLD_COUNT old backup(s)"
else
    echo "[OK] No old backups to delete"
fi

# -----------------------------------------------------------------------------
# List current backups
# -----------------------------------------------------------------------------

echo ""
echo "=== Current Backups ==="
ls -lh "$BACKUP_DIR"/openclaw_backup_*.tar.gz 2>/dev/null || echo "No backups found"

echo ""
echo "=== Backup Complete ==="
