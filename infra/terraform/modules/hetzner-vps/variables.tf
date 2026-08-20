# ============================================
# Required Variables
# ============================================

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "ssh_key_fingerprint" {
  description = "Fingerprint of an existing Hetzner SSH key to use"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "List of CIDR blocks allowed to SSH into the server"
  type        = list(string)
  default     = []
}

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
# Server Configuration
# ============================================

variable "server_type" {
  description = "Hetzner server type (e.g., cx23, cx33)"
  type        = string
  default     = "cx23"
}

variable "server_image" {
  description = "Operating system image for the server"
  type        = string
  default     = "ubuntu-24.04"
}

variable "server_location" {
  description = "Hetzner Cloud datacenter location"
  type        = string
  default     = "nbg1"
  validation {
    condition     = contains(["fsn1", "nbg1", "hel1", "ash", "hil"], var.server_location)
    error_message = "Location must be a valid Hetzner datacenter."
  }
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

variable "cloud_init_user_data" {
  description = "Rendered cloud-init user data content"
  type        = string
}

# ============================================
# Security Configuration
# ============================================

variable "enable_tailscale" {
  description = "Install and configure Tailscale VPN"
  type        = bool
  default     = false
}
