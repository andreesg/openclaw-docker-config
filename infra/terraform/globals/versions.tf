# Shared Provider Version Constraints
# ============================================
# Reference file for provider versions used across environments.
# Each environment's main.tf declares its own required_providers block.

terraform {
  required_version = ">= 1.5"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}
