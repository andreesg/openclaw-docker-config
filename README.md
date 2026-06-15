# OpenClaw Terraform Hetzner

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple.svg)](https://www.terraform.io/)

Terraform modules for deploying [OpenClaw](https://github.com/openclaw/openclaw) on Hetzner Cloud. Includes VPS provisioning, firewall configuration, cloud-init automation, and deployment tooling.

## Overview

This repository provides infrastructure-as-code for deploying OpenClaw—an open-source AI coding assistant—on a Hetzner Cloud VPS. The setup includes:

- Modular Terraform structure with remote S3 state backend
- Automated server provisioning via cloud-init
- Firewall configuration (UFW + Hetzner Cloud Firewall)
- Deployment scripts for application lifecycle management
- Backup and restore functionality
- SSH tunneling for secure gateway access

For information about OpenClaw itself, see the [OpenClaw documentation](https://docs.openclaw.ai/).

## Prerequisites

1. **Terraform** >= 1.5 ([Installation Guide](https://developer.hashicorp.com/terraform/install))
2. **Hetzner Cloud Account** with API token ([Console](https://console.hetzner.cloud/))
3. **Hetzner Object Storage** for Terraform state (optional but recommended)
4. **SSH Key** at `~/.ssh/id_rsa.pub` or custom path (see [SSH Configuration](#ssh-configuration))
5. **Docker configuration repo**: [openclaw-docker-config](https://github.com/andreesg/openclaw-docker-config)

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/andreesg/openclaw-terraform-hetzner.git
cd openclaw-terraform-hetzner
```

### 2. Configure Secrets

```bash
cp config/inputs.example.sh config/inputs.sh
vim config/inputs.sh  # Add your Hetzner API token and configuration
```

Required variables in `config/inputs.sh`:
- `HCLOUD_TOKEN` - Hetzner Cloud API token
- `TF_VAR_ssh_key_fingerprint` - SSH key fingerprint from Hetzner
- `CONFIG_DIR` - Path to your openclaw-docker-config repository
- `SERVER_IP` - Address that scripts use to SSH into the VPS. Set to `openclaw-prod` when using Tailscale (MagicDNS hostname, stable across rebuilds). Leave unset to auto-detect from Terraform output (only works when public SSH is open).

> **Tailscale (optional, recommended):** Set `TF_VAR_enable_tailscale=true` and `TF_VAR_tailscale_auth_key` to install Tailscale automatically on first boot — it lets you remove SSH from the public internet entirely. See [Firewall Rules](#firewall-rules).

### 3. Deploy Infrastructure

```bash
source config/inputs.sh
make init
make plan
make apply
```

### 4. Bootstrap OpenClaw

```bash
make bootstrap
make deploy
```

### 5. Verify Deployment

```bash
make status
make logs
```

Access the gateway via SSH tunnel:
```bash
make tunnel  # Opens tunnel on localhost:18789
```

If you enabled Tailscale, confirm it connected before closing public SSH access:
```bash
make tailscale-status  # node should appear as connected
make tailscale-ip      # note your Tailscale IP (e.g. 100.x.x.x)
```

## Architecture

```
┌─────────────────┐
│   Your Laptop   │
│                 │
│  ┌───────────┐  │         ┌─────────────────────┐
│  │ Terraform │──┼────────>│  Hetzner Cloud VPS  │
│  └───────────┘  │         │                     │
│                 │         │  ┌──────────────┐   │
│  ┌───────────┐  │         │  │ Docker       │   │
│  │  Config   │──┼────────>│  │ OpenClaw     │   │
│  │   Repo    │  │         │  └──────────────┘   │
│  └───────────┘  │         │                     │
└─────────────────┘         │  Firewall: SSH only │
                            └─────────────────────┘
                                      │
                                      v
                            ┌─────────────────────┐
                            │ Hetzner Object      │
                            │ Storage (state)     │
                            └─────────────────────┘
```

### Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **infra/terraform/** | Infrastructure definitions | This repo |
| **deploy/** | Deployment automation | This repo |
| **docker/** | Container configuration | [openclaw-docker-config](https://github.com/andreesg/openclaw-docker-config) |
| **config/** | OpenClaw configuration | [openclaw-docker-config](https://github.com/andreesg/openclaw-docker-config) |

## Usage

### Makefile Targets

**Infrastructure:**
```bash
make init       # Initialize Terraform
make plan       # Show infrastructure changes
make apply      # Apply infrastructure changes
make destroy    # Destroy all infrastructure
make output     # Show Terraform outputs
```

**Deployment:**
```bash
make bootstrap  # Initial OpenClaw setup
make deploy     # Pull latest image and restart
make status     # Check deployment status
make logs       # Stream container logs
```

**Operations:**
```bash
make ssh        # SSH to VPS as openclaw user
make tunnel     # Create SSH tunnel to gateway
make backup-now # Trigger backup immediately
make restore    # Restore from backup (BACKUP=filename)
```

**Tailscale:**
```bash
make tailscale-status   # Check Tailscale status (uses public IP — run before closing port 22)
make tailscale-ip       # Get Tailscale IP (uses public IP — run before closing port 22)
make tailscale-up       # Manually authenticate Tailscale
```

**Configuration:**
```bash
make push-env    # Push environment variables
make push-config # Push OpenClaw configuration
make setup-auth  # Configure Claude subscription auth
```

## Configuration

### SSH Configuration

By default, scripts use your SSH agent or the default key names (`id_rsa`, `id_ed25519`). If your key has a different name, set `SSH_KEY` in `config/inputs.sh`:

```bash
export SSH_KEY="$HOME/.ssh/your_key_name"
```


### Server Sizing

Default: CX23 (2 vCPU, 4GB RAM)

To change server type, add to `config/inputs.sh`:
```bash
export TF_VAR_server_type="cx32"  # 4 vCPU, 8GB RAM
```

See [Hetzner server types](https://www.hetzner.com/cloud#pricing).

### Firewall Rules

By default SSH (port 22) is open to `0.0.0.0/0`. Restrict this before going to production.

To expose additional public TCP services through the Hetzner Cloud Firewall, set `TF_VAR_additional_tcp_ports`:

```bash
# In config/inputs.sh
export TF_VAR_additional_tcp_ports='[80,443]'
```

These ports are opened in both the Hetzner Cloud Firewall and the server's UFW firewall. They are exposed to `0.0.0.0/0` and `::/0`. Port 22 remains managed separately by `TF_VAR_ssh_allowed_cidrs`.

**Option A — Restrict to your IP:**
```bash
# In config/inputs.sh
export TF_VAR_ssh_allowed_cidrs='["203.0.113.50/32"]'
```

Then apply:
```bash
source config/inputs.sh && make plan && make apply
```

**Option B — Tailscale VPN (recommended):**

Tailscale creates a private WireGuard mesh so SSH is reachable only from devices on your tailnet — the public IP has no open SSH port.

1. Get an auth key at [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys) — use **reusable + pre-authorized** keys, not ephemeral.

   > **Auth key expiry:** Reusable Tailscale auth keys expire after 90 days by default.
   > Generate a fresh key at login.tailscale.com/admin/settings/keys
   > and update `TF_VAR_tailscale_auth_key` in `config/inputs.sh`.

2. Add to `config/inputs.sh`:
   ```bash
   export TF_VAR_enable_tailscale=true
   export TF_VAR_tailscale_auth_key="tskey-auth-xxxxxxxxxxxxx"
   ```

3. Deploy. Tailscale is installed automatically on first boot. Then verify it's working before closing public access:
   ```bash
   source config/inputs.sh && make plan && make apply
   make tailscale-status          # confirm node is connected
   make tailscale-ip              # note your Tailscale IP
   ssh openclaw@<tailscale-ip>  # confirm Tailscale SSH works
   ```

4. Remove public SSH and point scripts at the Tailscale hostname:
   ```bash
   # In config/inputs.sh
   export TF_VAR_ssh_allowed_cidrs='[]'
   export SERVER_IP="openclaw-prod"   # Tailscale MagicDNS — stable across rebuilds
   source config/inputs.sh && make plan && make apply
   ```

   > **Make sure to always source `config/inputs.sh` before running `make` commands so the updated `SERVER_IP` is used.**

5. **Update `openclaw.json`** in your openclaw-docker-config repo to enable Tailscale-based gateway auth:
   ```json
   {
     "gateway": {
       "auth": {
         "allowTailscale": true
       },
       "controlUi": {
         "allowInsecureAuth": true
       }
     }
   }
   ```
   Then push and restart:
   ```bash
   make push-config deploy
   ```

   > `allowTailscale` authenticates dashboard users via Tailscale identity headers.
   >
   > `allowInsecureAuth` lets the control UI authenticate over plain HTTP — safe because it's only availale in your private tailnet.

After step 5, all `make` commands (`make ssh`, `make deploy`, `make status`, etc.) connect via `openclaw-prod` on your tailnet — no IP to track down.

> **Recovery:** If Tailscale fails to connect, check status with `make tailscale-status`. 
> For persistent issues, you can delete the Hetzner Cloud Firewall via the console or re-run 
> `make apply` after fixing the configuration.

### Remote State Backend

The S3 backend configuration is commented out by default in `infra/terraform/envs/prod/main.tf`. To enable:

1. Create Hetzner Object Storage bucket
2. Set credentials in `config/inputs.sh`:
   ```bash
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   ```
3. Uncomment backend block in `main.tf` and update endpoint URL
4. Run `terraform init -migrate-state`

### Switching AI Providers

OpenClaw supports multiple AI providers. This setup defaults to Anthropic Claude, but you can switch to other providers by modifying the configuration in [openclaw-docker-config](https://github.com/andreesg/openclaw-docker-config).

**Supported providers:**
- Anthropic Claude (Opus, Sonnet, Haiku)
- OpenAI (GPT-4, GPT-3.5, o1)
- DeepSeek (V3, R1)
- Local models (via Ollama or LM Studio)

**To switch providers:**

1. Update `openclaw.json` in the config repo:
   ```json
   {
     "agents": {
       "defaults": {
         "model": {
           "primary": "openai/gpt-4"
         }
       }
     },
     "auth": {
       "profiles": {
         "openai:main": {
           "provider": "openai",
           "mode": "token"
         }
       }
     }
   }
   ```

2. Update `secrets/openclaw.env`:
   ```bash
   OPENAI_API_KEY=sk-...
   ```

3. Redeploy:
   ```bash
   make push-config deploy
   ```

See [OpenClaw provider documentation](https://docs.openclaw.ai/providers) for detailed configuration.

## Common Workflows

### Initial Deployment

```bash
# 1. Configure secrets
cp config/inputs.example.sh config/inputs.sh
vim config/inputs.sh

# 2. Deploy infrastructure
source config/inputs.sh
make init plan apply

# 3. Bootstrap application
make bootstrap

# 4. Deploy OpenClaw
make deploy

# 5. Verify
make status logs
```

### Updating OpenClaw

```bash
# Pull latest image and restart
make deploy

# Check logs
make logs
```

### Updating Configuration

```bash
# Edit openclaw.json in config repo
vim ~/path/to/openclaw-docker-config/config/openclaw.json

# Push and restart
make push-config deploy
```

### Backup and Restore

Backups run daily at 02:00 UTC via systemd timer.

```bash
# Manual backup
make backup-now

# List backups
make ssh
ls -lh ~/backups/

# Restore from backup
make restore BACKUP=openclaw-backup-2026-02-08.tar.gz
```

### Accessing the Gateway

OpenClaw gateway runs on `127.0.0.1:18789` (localhost only) for security.

**Access via SSH tunnel:**
```bash
make tunnel  # Creates tunnel: localhost:18789 -> VPS:18789
```

Then open `http://localhost:18789` in your browser. The gateway will ask for your **Gateway Token** — paste your `OPENCLAW_GATEWAY_TOKEN` value (from `secrets/openclaw.env`) into the settings field to authenticate.

**Access via Tailscale Serve** (if Tailscale is enabled):
```bash
ssh openclaw@<tailscale-ip>
sudo tailscale serve --bg 18789
sudo tailscale serve status  # prints your HTTPS URL
```

Dashboard is then available at `https://openclaw-prod.<tailnet>.ts.net` from any device on your tailnet — no tunnel needed.

> **Note:** Use Serve, not Funnel. Funnel makes the service publicly accessible on the internet.
> See [OpenClaw Tailscale gateway docs](https://docs.openclaw.ai/gateway/tailscale)
> for full configuration options including the `allowTailscale` setting.

## Troubleshooting

### Terraform Init Fails

**Cause:** S3 backend credentials not set

**Solution:**
```bash
source config/inputs.sh
make init
```

Or use local state by commenting out the backend block in `infra/terraform/envs/prod/main.tf`.

### Container Won't Start

**Check logs:**
```bash
make logs
make ssh
docker compose -f ~/openclaw/docker-compose.yml ps
```

**Common causes:**

- Missing environment variables in `.env`
- Invalid OpenClaw configuration
- API key issues

**Fix:**
```bash
make push-env    # Re-push environment variables
make push-config # Re-push OpenClaw config
make deploy      # Restart
```

### Can't SSH to VPS

**Check firewall rules:**
```bash
grep TF_VAR_ssh_allowed_cidrs config/inputs.sh
# Check actual firewall
make ssh-root
ufw status
```

If `ssh_allowed_cidrs='[]'` (Tailscale-only mode), `make ssh` connects via the public IP and will time out, that's expected. SSH via your Tailscale IP instead:
```bash
ssh openclaw@<tailscale-ip>
```

Or - as stated above - use the `SERVER_IP` variable to point `make ssh` at the Tailscale hostname:
```bash
# In config/inputs.sh
export TF_VAR_ssh_allowed_cidrs='[]'
export SERVER_IP="openclaw-prod"   # Tailscale MagicDNS — stable across rebuilds
source config/inputs.sh && make plan && make apply
```

Emergency access: [Hetzner web console](https://console.hetzner.cloud/) → server → Console.

### Permission Denied on ~/.openclaw

If you see `Permission denied` when creating directories under `~/.openclaw` (e.g. during `make setup-auth`), Docker likely took ownership of the directory via the volume mount. This can happen if you ran `make deploy` before bootstrap finished, or if you're re-running bootstrap after a previous deploy.

**Fix:**
```bash
ssh openclaw@VPS_IP "sudo chown -R openclaw:openclaw ~/.openclaw"
```

Then re-run `make bootstrap` or `make setup-auth`.

### Bootstrap Fails

**Verify prerequisites:**
```bash
# Check CONFIG_DIR is set and exists
echo $CONFIG_DIR
ls $CONFIG_DIR/docker/docker-compose.yml

# Verify GHCR credentials
docker login ghcr.io -u YOUR_GITHUB_USERNAME
```

### SSH Host Key Changed

**Cause:** Destroyed and re-provisioned the VPS — new server has a different
host key at the same public IP.

**Error:** `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`

**Fix:**

```bash
ssh-keygen -R <old_vps_ip>
# Then retry — SSH will prompt you to accept the new key.
```

### API Billing Error

**Anthropic API key issues:**

If using API key (not subscription):
```bash
# Check key is set
make ssh
grep ANTHROPIC_API_KEY ~/openclaw/.env

# Verify key has credits at console.anthropic.com
```

If using Claude subscription:
```bash
# Re-run setup-auth
make setup-auth

# Verify auth profile exists
make ssh
cat ~/.openclaw/agents/main/agent/auth-profiles.json
```

## Security Considerations

See [SECURITY.md](SECURITY.md) for the full security policy and threat model.

### SSH Access

- Default allows SSH from anywhere (`0.0.0.0/0`) — restrict before production
- **Option A:** Restrict to your IP via `TF_VAR_ssh_allowed_cidrs`
- **Option B:** Enable Tailscale and set `ssh_allowed_cidrs='[]'` — zero public SSH exposure
- Use SSH keys, not passwords
- Rotate keys regularly
- See [Firewall Rules](#firewall-rules) for setup steps

### Secrets Management

- Never commit `config/inputs.sh` or `secrets/openclaw.env`
- Use environment variables for all credentials
- Rotate API tokens periodically
- Review `.gitignore` before committing

### Firewall

- Gateway binds to `127.0.0.1` (localhost only) — never exposed directly
- Access via SSH tunnel or Tailscale Serve
- `TF_VAR_additional_tcp_ports` opens ports in both the Hetzner Cloud Firewall and UFW on the VPS
- Use `TF_VAR_additional_tcp_ports` only for services that should be publicly reachable
- Review `infra/terraform/modules/hetzner-vps/main.tf` for the full firewall rule set

### API Keys

- Monitor API usage and costs
- Set spending limits at provider dashboards
- Prefer subscription auth over API keys when available
- Never expose keys in logs or errors

### Updates

- Keep Terraform providers updated
- Update OpenClaw regularly for security patches
- Monitor security advisories for dependencies
- Review cloud-init script before changes

## Project Structure

```
.
├── infra/
│   ├── terraform/
│   │   ├── globals/          # Shared configuration
│   │   ├── envs/prod/        # Production environment
│   │   └── modules/          # Reusable modules
│   │       └── hetzner-vps/  # VPS module
│   └── cloud-init/
│       └── user-data.yml.tpl # Server initialization
├── deploy/                   # Deployment scripts
│   ├── bootstrap.sh          # Initial setup
│   ├── deploy.sh             # Deploy/update
│   ├── backup.sh             # Backup script
│   └── restore.sh            # Restore script
├── scripts/                  # Utility scripts
│   ├── push-env.sh           # Push secrets to VPS
│   ├── push-config.sh        # Push config to VPS
│   └── setup-auth.sh         # Setup subscription auth
├── config/
│   └── inputs.example.sh     # Configuration template
└── secrets/
    └── openclaw.env.example  # Secrets template
```

## Infrastructure Costs

See [Hetzner Cloud pricing](https://www.hetzner.com/cloud#pricing) for current rates. This setup uses a small shared VPS (default: CX23) plus minimal object storage for Terraform state.

> **Note:** Prices exclude Anthropic/OpenAI API costs.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Ways to contribute:**
- Report bugs via [GitHub Issues](https://github.com/andreesg/openclaw-terraform-hetzner/issues)
- Submit feature requests
- Improve documentation
- Submit pull requests
- Share your deployment experiences

## Related Projects

- **[OpenClaw](https://github.com/openclaw/openclaw)** — The AI coding assistant this infrastructure deploys
- **[openclaw-docker-config](https://github.com/andreesg/openclaw-docker-config)** — Docker and OpenClaw configuration (companion repo)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues:** [GitHub Issues](https://github.com/andreesg/openclaw-terraform-hetzner/issues)
- **Discussions:** [GitHub Discussions](https://github.com/andreesg/openclaw-terraform-hetzner/discussions)
- **OpenClaw Docs:** [docs.openclaw.ai](https://docs.openclaw.ai/)
