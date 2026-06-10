#!/bin/bash
# ============================================
# OpenClaw - Input Configuration Example
# ============================================
# Copy this file to inputs.sh and fill in your values:
#   cp config/inputs.example.sh config/inputs.sh
#
# Source before running Terraform:
#   source config/inputs.sh
#
# NEVER commit inputs.sh to version control

# ============================================
# REQUIRED: Hetzner Cloud API Token
# ============================================
# Generate at: https://console.hetzner.cloud/ -> Projects -> API Tokens
export HCLOUD_TOKEN="CHANGE_ME_your-hcloud-token-here"

# Terraform reads this as var.hcloud_token
export TF_VAR_hcloud_token="$HCLOUD_TOKEN"

# ============================================
# REQUIRED: Hetzner Object Storage (S3-compatible)
# ============================================
# For Terraform remote state storage
# Create bucket at: https://console.hetzner.cloud/ -> Object Storage
export S3_ENDPOINT="https://nbg1.your-objectstorage.com"
export S3_ACCESS_KEY="CHANGE_ME_your-s3-access-key"
export S3_SECRET_KEY="CHANGE_ME_your-s3-secret-key"
export S3_BUCKET="openclaw-tfstate"

# Terraform S3 backend uses AWS_ env vars
export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"

# ============================================
# REQUIRED: SSH Configuration
# ============================================
# Allowed CIDRs for SSH access (use YOUR_IP/32 for single IPs)
# Find your IP: curl -s ifconfig.me
# After confirming Tailscale SSH works, set this to '[]' and set SERVER_IP="openclaw-prod"
# below, then re-run: make apply
export TF_VAR_ssh_allowed_cidrs='["0.0.0.0/0", "::/0"]'

# Fingerprint of your existing Hetzner SSH key (avoids recreating shared keys)
# List yours: curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" https://api.hetzner.cloud/v1/ssh_keys | jq '.ssh_keys[] | {name, fingerprint}'
export TF_VAR_ssh_key_fingerprint="CHANGE_ME_your-ssh-key-fingerprint"

# Path to your SSH private key (optional — defaults to SSH agent / default key names)
# Set this if your key is not named id_rsa / id_ed25519 or not loaded in your agent.
# export SSH_KEY="$HOME/.ssh/your_key_name"

# ============================================
# FIREWALL CONFIGURATION
# ============================================

# Additional public TCP ports to open in the Hetzner Cloud Firewall.
# Examples: [80,443] for HTTP/HTTPS, [3978] for Microsoft Teams bot callbacks.
# Port 22 is managed separately by TF_VAR_ssh_allowed_cidrs.
export TF_VAR_additional_tcp_ports='[]'

# ============================================
# SERVER CONNECTION
# ============================================
# When using Tailscale (ssh_allowed_cidrs='[]'), scripts can't reach the public
# IP. Set SERVER_IP to the Tailscale MagicDNS hostname — stable across rebuilds
# because cloud-init always registers the node as 'openclaw-prod'.
# Leave empty to auto-detect from terraform output (only works with public SSH).
# export SERVER_IP=""

# ============================================
# REQUIRED: Config Directory
# ============================================
# Local path to your openclaw-config repository (used by bootstrap, push-config)
export CONFIG_DIR="/path/to/your/openclaw-config"

# ============================================
# REQUIRED: GitHub Container Registry
# ============================================
# For pulling private Docker images during bootstrap and deploy
# Create a PAT at: https://github.com/settings/tokens with read:packages scope
export GHCR_USERNAME="your-github-username"
export GHCR_TOKEN="CHANGE_ME_your-github-pat-with-read-packages-scope"

# ============================================
# OPTIONAL: Claude Setup Token (for Claude Max/Pro subscription)
# ============================================
# Use your Claude subscription instead of paying for API credits.
# Generate with: claude setup-token
# Then run: make setup-auth
export CLAUDE_SETUP_TOKEN=""

# ============================================
# OPTIONAL: Tailscale VPN
# ============================================
# Enable Tailscale for private networking. When enabled:
# - Tailscale is installed on first boot via cloud-init
# - UFW and Hetzner firewall open UDP 41641 for WireGuard
# - Set ssh_allowed_cidrs='[]' to remove all public SSH exposure
#   (SSH over Tailscale goes through WireGuard, not port 22)
export TF_VAR_enable_tailscale=false

# Tailscale auth key (generate at https://login.tailscale.com/admin/settings/keys)
# Leave empty to authenticate manually after deployment with: make tailscale-up
# Recommended: reusable + pre-authorized key (not ephemeral)
export TF_VAR_tailscale_auth_key=""

# ============================================
# Server Configuration (Optional Overrides)
# ============================================
# export TF_VAR_server_type="cx23"
# export TF_VAR_server_location="nbg1"

# Enable/disable public IPv4 on the Hetzner server.
# Set to false for ipv6-only access.
# Note: IPv6-only is not plug-and-play for image pulls because ghcr.io does not
# provide IPv6 out of the box. Use a NAT64-capable DNS service when disabling IPv4.
# export TF_VAR_server_enable_ipv4=true
