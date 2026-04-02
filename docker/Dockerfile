###############################################################################
# OpenClaw Gateway – Docker Image
#
# IMPORTANT: Runtime installs are lost on container restart. All binaries
# needed by skills MUST be installed here at build time. If you add a skill
# that needs a new binary, update this Dockerfile and rebuild.
###############################################################################

FROM node:22-bookworm-slim

# Install system dependencies as root
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    chromium \
    ca-certificates \
    gnupg \
    tini \
  && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (required by github skill)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

# Pin OpenClaw version for reproducible builds — bump explicitly when upgrading
ARG OPENCLAW_VERSION=2026.4.1
RUN npm install -g openclaw@${OPENCLAW_VERSION}

# Install ClawHub CLI for skill management
RUN npm install -g clawhub

# Install Readwise CLI to read
RUN npm install -g @readwise/cli

# Install mcporter via npm (Homebrew tap is arm64-only)
RUN npm install -g mcporter

RUN npm install -g obsidian-headless

# Create OpenClaw directories and Homebrew prefix owned by node
RUN mkdir -p /home/node/.openclaw/workspace /.clawhub /home/linuxbrew/.linuxbrew \
  && chown -R node:node /home/node/.openclaw /.clawhub /home/linuxbrew/.linuxbrew

# Copy skills manifest, workspace templates, and entrypoint
COPY config/skills-manifest.txt /opt/config/skills-manifest.txt
COPY workspace-templates/ /opt/workspace-templates/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

USER node

# Homebrew install and libraries (must run as non-root)
# RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# RUN /home/linuxbrew/.linuxbrew/bin/brew install gogcli

ENTRYPOINT ["tini", "--", "entrypoint.sh"]
