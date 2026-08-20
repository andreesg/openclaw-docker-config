# Hetzner VPS Module
# ============================================
# Creates an OpenClaw VPS with:
# - SSH key authentication
# - Firewall (SSH-only inbound)
# - Cloud-init provisioning
# - Docker and Node.js pre-installed

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

# ============================================
# SSH Key (lookup existing key by fingerprint)
# ============================================

data "hcloud_ssh_key" "main" {
  fingerprint = var.ssh_key_fingerprint
}

# ============================================
# Firewall
# ============================================

resource "hcloud_firewall" "main" {
  name = "${var.project_name}-${var.environment}-firewall"

  # Allow SSH from specified CIDRs
  dynamic "rule" {
    for_each = var.ssh_allowed_cidrs
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "22"
      source_ips = [rule.value]
    }
  }

  # Allow additional public TCP ports
  dynamic "rule" {
    for_each = var.additional_tcp_ports
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = tostring(rule.value)
      source_ips = ["0.0.0.0/0", "::/0"]
    }
  }

  # Allow Tailscale UDP (if enabled)
  dynamic "rule" {
    for_each = var.enable_tailscale ? [1] : []
    content {
      direction  = "in"
      protocol   = "udp"
      port       = "41641"
      source_ips = ["0.0.0.0/0", "::/0"]
    }
  }
}

# ============================================
# Server
# ============================================

resource "hcloud_server" "main" {
  name        = "${var.project_name}-${var.environment}"
  server_type = var.server_type
  image       = var.server_image
  location    = var.server_location
  ssh_keys    = [data.hcloud_ssh_key.main.id]

  user_data = var.cloud_init_user_data

  labels = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }

  public_net {
    ipv4_enabled = var.server_enable_ipv4
    ipv6_enabled = true
  }

  lifecycle {
    ignore_changes = [
      user_data,
      ssh_keys,
    ]
  }
}

# ============================================
# Firewall Attachment
# ============================================

resource "hcloud_firewall_attachment" "main" {
  firewall_id = hcloud_firewall.main.id
  server_ids  = [hcloud_server.main.id]
}
