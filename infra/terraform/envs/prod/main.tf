# ============================================
# Production Environment - Terraform Configuration
# ============================================
# This configuration creates the production OpenClaw VPS on Hetzner Cloud

terraform {
  required_version = ">= 1.5"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }

  # Remote state backend (optional) - credentials via AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env vars
  #
  # Uncomment to use Hetzner Object Storage for remote state:
  # 1. Create a bucket at https://console.hetzner.cloud/ -> Object Storage
  # 2. Get endpoint URL (e.g., https://nbg1.your-objectstorage.com)
  # 3. Create access keys
  # 4. Set environment variables:
  #    export AWS_ACCESS_KEY_ID="your-access-key"
  #    export AWS_SECRET_ACCESS_KEY="your-secret-key"
  # 5. Uncomment the backend block below
  #
  # For first-time setup, local state (default) is fine. Migrate to remote state later.
  #
  # backend "s3" {
  #   endpoints = {
  #     s3 = "https://REGION.your-objectstorage.com"  # Replace with your endpoint
  #   }
  #   bucket                      = "openclaw-tfstate"
  #   key                         = "prod/terraform.tfstate"
  #   region                      = "main"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   skip_requesting_account_id  = true
  #   skip_s3_checksum            = true
  #   use_path_style              = true
  # }
}

# ============================================
# Provider
# ============================================

provider "hcloud" {
  token = var.hcloud_token
}

# ============================================
# VPS Module
# ============================================

module "vps" {
  source = "../../modules/hetzner-vps"

  project_name         = var.project_name
  environment          = "prod"
  ssh_key_fingerprint  = var.ssh_key_fingerprint
  ssh_allowed_cidrs    = var.ssh_allowed_cidrs
  additional_tcp_ports = var.additional_tcp_ports
  server_type          = var.server_type
  server_location      = var.server_location
  server_enable_ipv4   = var.server_enable_ipv4
  app_user             = var.app_user
  app_directory        = var.app_directory

  # Security configuration
  enable_tailscale = var.enable_tailscale

  cloud_init_user_data = templatefile("${path.module}/../../../cloud-init/user-data.yml.tpl", {
    app_user             = var.app_user
    app_directory        = var.app_directory
    enable_tailscale     = var.enable_tailscale
    tailscale_auth_key   = var.tailscale_auth_key
    additional_tcp_ports = var.additional_tcp_ports
  })
}

# ============================================
# Outputs
# ============================================

output "server_ip" {
  description = "Primary IP address of the OpenClaw server (IPv4 if available, otherwise IPv6)"
  value       = module.vps.server_ip
}

output "server_ipv4" {
  description = "Public IPv4 address of the OpenClaw server (null when server_enable_ipv4=false)"
  value       = module.vps.server_ipv4
}

output "server_ipv6" {
  description = "Public IPv6 address of the OpenClaw server"
  value       = module.vps.server_ipv6
}

output "server_id" {
  description = "Hetzner Cloud server ID"
  value       = module.vps.server_id
}

output "server_status" {
  description = "Current status of the server"
  value       = module.vps.server_status
}

output "ssh_command" {
  description = "SSH command to connect as the application user"
  value       = module.vps.ssh_command
}

output "ssh_command_root" {
  description = "SSH command to connect as root"
  value       = module.vps.ssh_command_root
}

output "ssh_key_id" {
  description = "Hetzner Cloud SSH key ID"
  value       = module.vps.ssh_key_id
}

output "firewall_id" {
  description = "Hetzner Cloud firewall ID"
  value       = module.vps.firewall_id
}

output "tailscale_enabled" {
  description = "Whether Tailscale VPN is enabled"
  value       = module.vps.tailscale_enabled
}
