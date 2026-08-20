#!/bin/bash
# =============================================================================
# OpenClaw Bootstrap Script
# =============================================================================
# Purpose: Run once after terraform apply to set up OpenClaw on the VPS.
# Usage: ./deploy/bootstrap.sh [VPS_IP]
#
# This script:
#   1. Logs in to GHCR for pulling private Docker images
#   2. Creates directories and copies docker-compose.yml to the VPS
#   3. Pushes secrets and config files
#   4. Copies the backup script and sets up systemd timers
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Local path to the openclaw-config repository
CONFIG_DIR="${CONFIG_DIR:-}"

# GitHub Container Registry credentials (for pulling private images)
GHCR_USERNAME="${GHCR_USERNAME:-}"
GHCR_TOKEN="${GHCR_TOKEN:-}"

# VPS user
VPS_USER="openclaw"

# SSH options
SSH_OPTS="-o StrictHostKeyChecking=accept-new"
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=" -i $SSH_KEY"

# Terraform directory (relative to repo root)
TERRAFORM_DIR="infra/terraform/envs/prod"

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

if [[ ! -f "$CONFIG_DIR/docker/docker-compose.yml" ]]; then
    echo "Error: docker-compose.yml not found at $CONFIG_DIR/docker/docker-compose.yml"
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
    # Try to get IP from terraform output
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

echo "=== OpenClaw Bootstrap ==="
echo "VPS IP: $VPS_IP"
echo "Config Dir: $CONFIG_DIR"
echo ""

# -----------------------------------------------------------------------------
# Verify SSH connectivity
# -----------------------------------------------------------------------------

echo "Verifying SSH connectivity..."
if ! ssh $SSH_OPTS "$VPS_USER@$VPS_IP" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "Error: Cannot connect to $VPS_USER@$VPS_IP"
    echo "Make sure:"
    echo "  1. The VPS is running (check: terraform output)"
    echo "  2. Cloud-init has completed (wait a few minutes after apply)"
    echo "  3. Your SSH key is correct"
    exit 1
fi

# -----------------------------------------------------------------------------
# Wait for cloud-init to finish
# -----------------------------------------------------------------------------

echo ""
echo "Waiting for cloud-init to complete..."
if ssh $SSH_OPTS "$VPS_USER@$VPS_IP" "command -v cloud-init >/dev/null 2>&1 && timeout 300 cloud-init status --wait >/dev/null 2>&1"; then
    echo "[OK] Cloud-init completed"
else
    echo "[WARN] Could not confirm cloud-init completion"
    echo "       If you hit permission errors, wait a few minutes and re-run bootstrap"
fi

# -----------------------------------------------------------------------------
# Log in to GitHub Container Registry
# -----------------------------------------------------------------------------

echo ""
if [[ -n "$GHCR_USERNAME" ]] && [[ -n "$GHCR_TOKEN" ]]; then
    echo "Logging in to GitHub Container Registry..."
    ssh $SSH_OPTS "$VPS_USER@$VPS_IP" \
        "echo '$GHCR_TOKEN' | docker login ghcr.io -u '$GHCR_USERNAME' --password-stdin"
    echo "[OK] GHCR login successful"
else
    echo "[SKIP] GHCR credentials not set (GHCR_USERNAME / GHCR_TOKEN)"
    echo "       Set them in config/inputs.sh to pull private images"
fi

# -----------------------------------------------------------------------------
# Create directories on VPS
# -----------------------------------------------------------------------------

echo ""
echo "Creating directories on VPS..."
ssh $SSH_OPTS "$VPS_USER@$VPS_IP" bash -s << 'REMOTE_SCRIPT'
set -euo pipefail

mkdir -p "$HOME/openclaw"
mkdir -p "$HOME/.openclaw"
mkdir -p "$HOME/.openclaw/workspace"
mkdir -p "$HOME/backups"
mkdir -p "$HOME/scripts"

# Set secure permissions on OpenClaw state directory
chmod 700 "$HOME/.openclaw"
chmod 700 "$HOME/.openclaw/workspace"

echo "[OK] Created ~/openclaw, ~/.openclaw, ~/backups, ~/scripts"
echo "[OK] Set secure permissions (700) on ~/.openclaw"
REMOTE_SCRIPT

# -----------------------------------------------------------------------------
# Copy docker-compose.yml to VPS
# -----------------------------------------------------------------------------

echo ""
echo "Copying docker-compose.yml to VPS..."
scp $SSH_OPTS "$CONFIG_DIR/docker/docker-compose.yml" "$VPS_USER@$VPS_IP:~/openclaw/docker-compose.yml"
echo "[OK] docker-compose.yml deployed to ~/openclaw/"

# -----------------------------------------------------------------------------
# Copy backup script to VPS
# -----------------------------------------------------------------------------

echo ""
echo "Copying backup script to VPS..."
scp $SSH_OPTS ./deploy/backup.sh "$VPS_USER@$VPS_IP:~/scripts/backup.sh"
ssh $SSH_OPTS "$VPS_USER@$VPS_IP" "chmod +x \$HOME/scripts/backup.sh"
echo "[OK] Backup script copied to ~/scripts/backup.sh"

# -----------------------------------------------------------------------------
# Set up systemd user timers for daily backups
# -----------------------------------------------------------------------------

echo ""
echo "Setting up systemd timers for daily backups..."

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" bash -s << 'REMOTE_SCRIPT'
set -euo pipefail

mkdir -p "$HOME/.config/systemd/user"

# Create backup service
cat > "$HOME/.config/systemd/user/openclaw-backup.service" << 'EOF'
[Unit]
Description=OpenClaw Daily Backup

[Service]
Type=oneshot
ExecStart=/home/openclaw/scripts/backup.sh
EOF

# Create backup timer (runs daily at 3 AM)
cat > "$HOME/.config/systemd/user/openclaw-backup.timer" << 'EOF'
[Unit]
Description=OpenClaw Daily Backup Timer

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload systemd and enable timer
systemctl --user daemon-reload
systemctl --user enable openclaw-backup.timer 2>/dev/null || true
systemctl --user start openclaw-backup.timer 2>/dev/null || true

# Enable lingering so timers run even when not logged in
loginctl enable-linger "$USER" 2>/dev/null || true

echo "[OK] Backup timer configured (daily at 3 AM)"
REMOTE_SCRIPT

# -----------------------------------------------------------------------------
# Push .env secrets to VPS
# -----------------------------------------------------------------------------

echo ""
if [[ -f "secrets/openclaw.env" ]]; then
    echo "Pushing secrets to VPS..."
    ./scripts/push-env.sh "$VPS_IP"
else
    echo "[SKIP] secrets/openclaw.env not found"
    echo "       Create it from the example and push manually:"
    echo "         cp secrets/openclaw.env.example secrets/openclaw.env"
    echo "         vim secrets/openclaw.env"
    echo "         make push-env"
fi

# -----------------------------------------------------------------------------
# Push config files to VPS
# -----------------------------------------------------------------------------

echo ""
if [[ -d "$CONFIG_DIR/config" ]]; then
    echo "Pushing config files to VPS..."
    ./scripts/push-config.sh "$VPS_IP"
else
    echo "[SKIP] No config directory found in $CONFIG_DIR"
fi

# -----------------------------------------------------------------------------
# Set up Claude subscription auth (optional)
# -----------------------------------------------------------------------------

echo ""
if [[ -n "${CLAUDE_SETUP_TOKEN:-}" ]]; then
    echo "Setting up Claude subscription auth..."
    ./scripts/setup-auth.sh "$VPS_IP"
else
    echo "[SKIP] CLAUDE_SETUP_TOKEN not set"
    echo "       To use your Claude subscription: run 'make setup-auth'"
fi

# -----------------------------------------------------------------------------
# Final summary
# -----------------------------------------------------------------------------

echo ""
echo "=== Bootstrap Complete ==="
echo ""
if [[ -f "secrets/openclaw.env" ]]; then
    echo "The VPS is configured and secrets are deployed."
    echo ""
    echo "To pull and start the containers:"
    echo "  make deploy"
else
    echo "The VPS is configured but secrets are NOT deployed yet."
    echo ""
    echo "  1. Create secrets/openclaw.env from the example"
    echo "  2. Run: make push-env"
    echo "  3. Deploy: make deploy"
fi
echo ""

read -p "Would you like to SSH in now? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Connecting to VPS..."
    ssh $SSH_OPTS "$VPS_USER@$VPS_IP"
fi
