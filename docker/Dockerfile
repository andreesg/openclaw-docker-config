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
    ffmpeg \
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

# Install gogcli (required by gog skill — Google Workspace CLI)
RUN curl -fsSL https://github.com/steipete/gogcli/releases/latest/download/gog-linux-amd64 \
      -o /usr/local/bin/gog && chmod +x /usr/local/bin/gog

# Install yt-dlp (YouTube downloader — works with ffmpeg for audio/video merge)
RUN curl -fsSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
      -o /usr/local/bin/yt-dlp && chmod +x /usr/local/bin/yt-dlp

# Pin OpenClaw version for reproducible builds — bump explicitly when upgrading
ARG OPENCLAW_VERSION=2026.3.13
RUN npm install -g openclaw@${OPENCLAW_VERSION}

# Install ClawHub CLI for skill management
RUN npm install -g clawhub

# Create OpenClaw directories owned by node
RUN mkdir -p /home/node/.openclaw/workspace /.clawhub \
  && chown -R node:node /home/node/.openclaw /.clawhub

# Copy skills manifest, workspace templates, and entrypoint
COPY config/skills-manifest.txt /opt/config/skills-manifest.txt
COPY workspace-templates/ /opt/workspace-templates/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

USER node

ENTRYPOINT ["tini", "--", "entrypoint.sh"]
