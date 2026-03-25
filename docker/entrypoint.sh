#!/usr/bin/env bash
set -euo pipefail

MANIFEST="/opt/config/skills-manifest.txt"
WORKDIR="/home/node/.openclaw/workspace"

###############################################################################
# Seed workspace templates (no-clobber — won't overwrite existing files)
###############################################################################
TEMPLATES="/opt/workspace-templates"
if [[ -d "$TEMPLATES" ]]; then
  echo "[entrypoint] Seeding workspace templates ..."
  cp -rn "$TEMPLATES"/. "$WORKDIR"/
fi


###############################################################################
# Install ClawHub skills from the manifest (if present)
###############################################################################
if [[ -f "$MANIFEST" ]]; then
  echo "[entrypoint] Installing ClawHub skills from manifest ..."
  while IFS= read -r line; do
    # Skip blank lines and comments
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue

    # Skip if already installed
    if [[ -d "$WORKDIR/skills/$line" ]]; then
      echo "[entrypoint]   ✓ $line (already installed)"
      continue
    fi

    echo "[entrypoint]   → installing $line"
    clawhub install "$line" --workdir "$WORKDIR" || {
      echo "[entrypoint] WARNING: Failed to install $line — continuing"
    }
  done < "$MANIFEST"
  echo "[entrypoint] Skill installation complete."
else
  echo "[entrypoint] No skills manifest found — skipping skill install."
fi

###############################################################################
# Hand off to the real command (CMD from docker-compose)
###############################################################################
exec "$@"
