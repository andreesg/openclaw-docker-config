# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Tailscale VPN Integration**: Optional Tailscale VPN support for secure private networking
  - New Terraform variables: `enable_tailscale`, `tailscale_auth_key`
  - Automatic Tailscale installation and authentication via cloud-init
  - UFW firewall rule for Tailscale UDP port (41641)
  - New Makefile targets: `tailscale-status`, `tailscale-ip`, `tailscale-up`
  - Tailscale documentation integrated into `README.md` and `SECURITY.md`

### Changed
- Cloud-init template updated with Tailscale installation logic
- Firewall rules updated to open Tailscale UDP port (41641)
- `config/inputs.example.sh` updated with Tailscale configuration

### Security
- Reduced attack surface: SSH and gateway can be accessed via private Tailscale VPN
- End-to-end WireGuard encryption for all Tailscale traffic
- Tailscale auth keys stored as sensitive Terraform variables
- Updated `SECURITY.md` with Tailscale threat model improvements

### Documentation
- Tailscale setup integrated into `README.md` (Firewall Rules section) and `SECURITY.md` (threat model)

## [1.0.0] - 2025-02-08

### Added
- Initial release of OpenClaw Terraform infrastructure for Hetzner Cloud
- Modular Terraform structure (globals, environments, modules)
- hetzner-vps module for VPS provisioning with cloud-init
- Deployment automation via Makefile
- Bootstrap script for initial OpenClaw setup
- Deploy script for pulling and restarting containers
- Backup and restore functionality
- Status monitoring and log streaming
- SSH tunneling support for gateway access
- Claude subscription auth setup via setup-token
- Environment variable management (inputs.sh, openclaw.env)
- Comprehensive documentation (README, CONTRIBUTING, SECURITY)
- GitHub Actions CI/CD (Terraform validation, ShellCheck)
- Issue and PR templates

### Security
- Firewall configuration (SSH-only by default)
- UFW setup via cloud-init
- Secrets externalized to environment variables
- .gitignore for sensitive files

[Unreleased]: https://github.com/andreesg/openclaw-terraform-hetzner/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/andreesg/openclaw-terraform-hetzner/releases/tag/v1.0.0
