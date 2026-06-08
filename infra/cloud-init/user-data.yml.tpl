#cloud-config

# -----------------------------------------------------------------------------
# OpenClaw VPS Cloud-Init Configuration
# -----------------------------------------------------------------------------

package_update: true
package_upgrade: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - git
  - jq
  - ufw
  - software-properties-common

# -----------------------------------------------------------------------------
# Write Files
# -----------------------------------------------------------------------------

write_files:
  # Docker daemon configuration
  - path: /etc/docker/daemon.json
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "10m",
          "max-file": "3"
        }
      }
    permissions: '0644'

# -----------------------------------------------------------------------------
# Run Commands
# -----------------------------------------------------------------------------

runcmd:
  # -----------------------------------------------------------------------------
  # Create Application User
  # -----------------------------------------------------------------------------
  - useradd -m -s /bin/bash -u 1000 ${app_user}
  - usermod -aG sudo ${app_user}
  - echo '${app_user} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${app_user}
  - chmod 440 /etc/sudoers.d/${app_user}

  # Copy SSH authorized keys from root to application user
  - mkdir -p /home/${app_user}/.ssh
  - cp /root/.ssh/authorized_keys /home/${app_user}/.ssh/authorized_keys
  - chown -R ${app_user}:${app_user} /home/${app_user}/.ssh
  - chmod 700 /home/${app_user}/.ssh
  - chmod 600 /home/${app_user}/.ssh/authorized_keys

  # -----------------------------------------------------------------------------
  # Install Docker
  # -----------------------------------------------------------------------------
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Start and enable Docker
  - systemctl enable docker
  - systemctl start docker

  # Add user to docker group
  - usermod -aG docker ${app_user}

%{ if enable_tailscale ~}
  # -----------------------------------------------------------------------------
  # Install Tailscale VPN
  # -----------------------------------------------------------------------------
  - curl -fsSL https://tailscale.com/install.sh | sh
  - systemctl enable --now tailscaled
  - sleep 2

%{ if tailscale_auth_key != "" ~}
  # Authenticate Tailscale automatically
  - tailscale up --auth-key="${tailscale_auth_key}" --hostname="openclaw-prod"
%{ else ~}
  # Tailscale installed but not authenticated - run manually: sudo tailscale up
  - echo "[Tailscale] Auth key not provided. Run manually: sudo tailscale up"
%{ endif ~}
%{ endif ~}

  # -----------------------------------------------------------------------------
  # Configure UFW Firewall
  # -----------------------------------------------------------------------------
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow ssh
%{ for port in additional_tcp_ports ~}
  - ufw allow ${port}/tcp comment 'Additional TCP port ${port}'
%{ endfor ~}
%{ if enable_tailscale ~}
  - ufw allow 41641/udp comment 'Tailscale'
%{ endif ~}
  - ufw --force enable

  # -----------------------------------------------------------------------------
  # Create Application Directories
  # -----------------------------------------------------------------------------
  - mkdir -p ${app_directory}
  - mkdir -p ${app_directory}/workspace
  - chown -R 1000:1000 ${app_directory}
  - chmod 755 ${app_directory}
  - chmod 755 ${app_directory}/workspace

  # -----------------------------------------------------------------------------
  # Final cleanup
  # -----------------------------------------------------------------------------
  - apt-get autoremove -y
  - apt-get clean

# -----------------------------------------------------------------------------
# Final Message
# -----------------------------------------------------------------------------

final_message: "OpenClaw VPS initialization completed after $UPTIME seconds"
