# ============================================
# Server Outputs
# ============================================

output "server_id" {
  description = "The ID of the created server"
  value       = hcloud_server.main.id
}

output "server_name" {
  description = "The name of the created server"
  value       = hcloud_server.main.name
}

output "server_ip" {
  description = "The primary IP address for the server (IPv4 if available, otherwise IPv6)"
  value       = coalesce(hcloud_server.main.ipv4_address, hcloud_server.main.ipv6_address)
}

output "server_ipv4" {
  description = "The public IPv4 address of the server"
  value       = var.server_enable_ipv4 ? hcloud_server.main.ipv4_address : null
}

output "server_ipv6" {
  description = "The public IPv6 address of the server"
  value       = hcloud_server.main.ipv6_address
}

output "server_status" {
  description = "The status of the server"
  value       = hcloud_server.main.status
}

# ============================================
# SSH Outputs
# ============================================

output "ssh_key_id" {
  description = "The ID of the SSH key"
  value       = data.hcloud_ssh_key.main.id
}

output "firewall_id" {
  description = "The ID of the firewall"
  value       = hcloud_firewall.main.id
}

# ============================================
# Connection Outputs
# ============================================

output "ssh_command" {
  description = "SSH command to connect as the application user"
  value       = "ssh ${var.app_user}@${coalesce(hcloud_server.main.ipv4_address, hcloud_server.main.ipv6_address)}"
}

output "ssh_command_root" {
  description = "SSH command to connect as root"
  value       = "ssh root@${coalesce(hcloud_server.main.ipv4_address, hcloud_server.main.ipv6_address)}"
}

output "tailscale_enabled" {
  description = "Whether Tailscale is enabled"
  value       = var.enable_tailscale
}
