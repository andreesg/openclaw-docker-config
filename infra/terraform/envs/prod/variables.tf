# ============================================
# Production Environment Variables
# ============================================

# ============================================
# Required: API Token
# ============================================

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

# ============================================
# Required: SSH Configuration
# ============================================

variable "ssh_key_fingerprint" {
  description = "Fingerprint of an existing Hetzner SSH key to use (avoids recreating shared keys)"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH (e.g., ['1.2.3.4/32'])"
  type        = list(string)
  default     = []
}

# ============================================
# Firewall Configuration
# ============================================

variable "additional_tcp_ports" {
  description = "Additional TCP ports to expose publicly through the Hetzner Cloud Firewall"
  type        = set(number)
  default     = []

  validation {
    condition     = alltrue([for port in var.additional_tcp_ports : port >= 1 && port <= 65535 && port != 22])
    error_message = "additional_tcp_ports must contain TCP port numbers from 1 to 65535, excluding 22 which is managed by ssh_allowed_cidrs."
  }
}

# ============================================
# Project Configuration
# ============================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "openclaw"
}

# ============================================
# Server Configuration
# ============================================

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx23"
}

variable "server_location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1"
}

variable "server_enable_ipv4" {
  description = "Enable a public IPv4 address on the server"
  type        = bool
  default     = true
  validation {
    condition     = var.server_enable_ipv4 || length(var.ssh_allowed_cidrs) == 0 || anytrue([for cidr in var.ssh_allowed_cidrs : strcontains(cidr, ":")])
    error_message = "If server_enable_ipv4 is false, ssh_allowed_cidrs must be empty (for Tailscale-only mode) or contain at least one IPv6 CIDR to ensure SSH access."
  }
}

# ============================================
# Application Configuration
# ============================================

variable "app_user" {
  description = "Non-root user to create on the server"
  type        = string
  default     = "openclaw"
}

variable "app_directory" {
  description = "Application directory path"
  type        = string
  default     = "/home/openclaw/.openclaw"
}

# ============================================
# Security Configuration
# ============================================

variable "enable_tailscale" {
  description = "Install and configure Tailscale VPN"
  type        = bool
  default     = false
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key for automatic registration (optional)"
  type        = string
  default     = ""
  sensitive   = true
}
