# ClawHub Skills Research

*Date: 2026-03-24*

## Overview

[ClawHub](https://clawhub.ai) is the open-source skill registry for OpenClaw agents.
As of this writing it hosts **~1,415 skills**. Skills are installed via `clawhub install <slug>`.

## Key Concepts

- **ClawHub skills** (SKILL.md instruction files) live in the volume-mounted workspace and
  **persist across container restarts**. They can be installed at runtime.
- **System binaries** that skills depend on are in the container filesystem and
  **lost on restart**. These must be baked into the Dockerfile.

## Top Skills by Downloads

| # | Slug | Downloads | Description | Needs binary? |
|---|------|-----------|-------------|---------------|
| 1 | `nano-pdf` | 71k | Edit PDFs with natural-language instructions | `nano-pdf` CLI |
| 2 | `sonoscli` | 65k | Control Sonos speakers | `sonos` (Go) |
| 3 | `notion` | 64k | Notion API (pages, databases, blocks) | No (API only) |
| 4 | `openai-whisper` | 55k | Local speech-to-text (no API key) | `whisper` CLI (Python+PyTorch) |
| 5 | `automation-workflows` | 49k | Zapier / Make / n8n workflow design | No |
| 6 | `agent-browser` | 41k | Headless browser with a11y snapshots | `chromium` |
| 7 | `video-frames` | 32k | Extract frames/clips from video | `ffmpeg` |
| 8 | `slack` | 31k | Control Slack from agent | No (API only) |
| 9 | `browser-automation` | 26k | Web browser interaction via CLI | Chromium-based |
| 10 | `excel-xlsx` | 26k | Create/edit Excel workbooks | Node-based |
| 11 | `pdf` | 23k | PDF manipulation toolkit | Node-based |
| 12 | `apple-notes` | 23k | Apple Notes via `memo` CLI | macOS only |
| 13 | `docker-essentials` | 22k | Docker commands and workflows | `docker` CLI |
| 14 | `git-essentials` | 19k | Essential Git commands | `git` |
| 15 | `tmux` | 18k | Remote-control tmux sessions | `tmux` |
| 16 | `spotify-player` | 18k | Spotify playback/search | `spogo` binary |
| 17 | `todoist` | 16k | Task management in Todoist | No (API only) |
| 18 | `home-assistant` | 13k | Smart home control | No (API only) |
| 19 | `linear` | 9k | Linear issue/project management | No (API only) |
| 20 | `git` | 9k | Git commits, branches, merges | `git` |

### Developer Tools

| Slug | Downloads | Description | Needs binary? |
|------|-----------|-------------|---------------|
| `gcloud` | 4k | Google Cloud Platform via `gcloud` | `gcloud` CLI |
| `sqlite` | 4k | SQLite with proper concurrency | `sqlite3` |
| `linux` | 2k | Linux system administration | System tools |
| `nginx` | 2k | Nginx configuration | `nginx` |
| `raycast` | 2k | Raycast extension dev | macOS only |
| `latex` | 2k | LaTeX document authoring | `pdflatex` |
| `azure` | 1k | Azure cloud management | `az` CLI |
| `ci-cd` | 1k | CI/CD pipeline design | Varies |
| `github-actions` | 400 | GitHub Actions workflows | No |

### Notable by Category

- **Google Workspace:** `gog` — Gmail, Calendar, Drive, etc. via `gog` binary
- **AI/ML:** `self-evolving-skill`, `mcp-adapter`, `openai-integration`
- **Skill Dev:** `skill-scaffold`, `skill-test`, `skill-template`

## Skills Currently in Our Image

From `config/skills-manifest.txt`:

| Skill | Binary dependency | Status |
|-------|-------------------|--------|
| `yt` | None | Installed |
| `agent-browser` | `chromium` | Installed (chromium in Dockerfile) |
| `system-monitor` | System tools | Installed |
| `conventional-commits` | `git` | Installed (git in Dockerfile) |
| `github` | `gh` | Installed (gh CLI in Dockerfile) |
| `gog` | `gog` | **Added** (binary in Dockerfile) |

## Whisper Alternatives for Docker (CPU-only VPS)

The `openai-whisper` skill requires a speech-to-text binary. The default Python Whisper
is impractically heavy for a slim Docker image. Here are the alternatives:

### Comparison

| | Python Whisper | faster-whisper | **whisper.cpp** |
|---|---|---|---|
| Runtime deps | Python + PyTorch | Python + CTranslate2 | **None (single binary)** |
| Added image size | ~3-6 GB | ~300-500 MB | **~5 MB binary + model** |
| CPU speed (vs Python) | 1x baseline | 2-4x faster | **4-8x faster** |
| RAM usage (base model) | ~2-3 GB | ~1-1.5 GB | **~300-500 MB** |
| CLI available? | Yes (`whisper`) | No (library only) | **Yes (`whisper-cli`)** |
| Needs Python? | Yes | Yes | **No** |
| Input format | Any (uses ffmpeg) | Any (uses ffmpeg) | **16kHz WAV only** |

### Recommendation: whisper.cpp

[whisper.cpp](https://github.com/ggerganov/whisper.cpp) is a C++ port of Whisper by
Georgi Gerganov (of llama.cpp fame). Single binary, no Python, 4-8x faster on CPU.

**Caveat:** Only accepts 16kHz mono WAV. Use `ffmpeg` to convert:
```bash
ffmpeg -i input.mp3 -ar 16000 -ac 1 -c:a pcm_s16le output.wav
whisper-cli -m /models/ggml-base.en.bin -f output.wav
```

**Model sizes:**

| Model | File size | Quality |
|-------|-----------|---------|
| `tiny.en` | 75 MB | Fast, lower accuracy |
| `base.en` | 142 MB | Good balance |
| `small.en` | 466 MB | Better accuracy, slower |

**Dockerfile pattern (multi-stage build):**
```dockerfile
FROM debian:bookworm-slim AS whisper-builder
RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential cmake git ca-certificates && \
    rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git /whisper.cpp
WORKDIR /whisper.cpp
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build --config Release -j$(nproc)
# Binary at: /whisper.cpp/build/bin/whisper-cli

# In the final stage:
COPY --from=whisper-builder /whisper.cpp/build/bin/whisper-cli /usr/local/bin/whisper-cli
```

**Pre-built binary alternative:**
```dockerfile
RUN curl -fsSL https://github.com/ggerganov/whisper.cpp/releases/download/v1.7.5/whisper-v1.7.5-bin-linux-x64.zip \
      -o /tmp/whisper.zip && unzip /tmp/whisper.zip -d /usr/local/bin/ && rm /tmp/whisper.zip
```

## ClawHub API

- **Search:** `GET https://wry-manatee-359.convex.site/api/v1/search?q=<query>&limit=<n>`
- **Skill detail:** `GET /api/v1/skills/<slug>`
- **Skill file:** `GET /api/v1/skills/<slug>/file?path=SKILL.md`
- **Download:** `GET /api/v1/download?slug=<slug>`
- **CLI:** `npx clawhub@latest search|explore|inspect|install`

## Prolific Authors

- **@steipete** (Peter Steinberger) — project creator; nano-pdf, notion, whisper, slack, tmux, spotify, etc.
- **@ivangdavila** — large catalog of reference skills: git, excel-xlsx, translate, sqlite, typescript, mysql, etc.
- **@arnarsson** — docker-essentials, git-essentials
