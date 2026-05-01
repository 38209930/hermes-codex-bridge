#!/usr/bin/env bash

set -Eeuo pipefail

NODE_MAJOR="${NODE_MAJOR:-22}"
NVM_VERSION="${NVM_VERSION:-v0.40.1}"

log() {
  printf '\n==> %s\n' "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

log "Updating Ubuntu packages"
sudo apt update
sudo apt upgrade -y
sudo apt install -y git curl build-essential ca-certificates

export NVM_DIR="$HOME/.nvm"

if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  log "Installing nvm $NVM_VERSION"
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash
else
  log "nvm already installed"
fi

# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

log "Installing Node.js $NODE_MAJOR"
nvm install "$NODE_MAJOR"
nvm use "$NODE_MAJOR"
nvm alias default "$NODE_MAJOR"

log "Installing Codex CLI"
npm install -g @openai/codex

log "Versions"
node -v
npm -v
codex --version

cat <<'EOF'

Codex CLI is installed.

Next steps:
  codex login
  mkdir -p ~/projects
  cd ~/projects
  git clone <repo-url>
  cd <repo>
  codex exec -C "$PWD" "总结这个项目的结构和启动方式"

EOF
