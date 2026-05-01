#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
PROFILES_ROOT="$HERMES_HOME/profiles"
TEAM_ROOT_DEFAULT="${TEAM_ROOT_DEFAULT:-$HOME/Documents}"
DEFAULT_BOTS=(feishu-bot1 feishu-bot2 feishu-bot3 feishu-bot4)

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME <bot> <project_dir>
  $SCRIPT_NAME <bot> --reset

Examples:
  $SCRIPT_NAME feishu-bot2 "$HOME/projects/my-project"
  $SCRIPT_NAME feishu-bot4 "$HOME/Documents/projects/app-alpha"
  $SCRIPT_NAME feishu-bot1 --reset

What it does:
  1. Updates the bot profile's terminal.cwd
  2. Reloads that bot's gateway
  3. Prints the active working directory

Notes:
  - Only the selected bot is changed.
  - --reset switches the bot back to its profile-local workspace.
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

die() {
  printf '[%s] ERROR: %s\n' "$(date '+%H:%M:%S')" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

is_valid_bot() {
  local bot="$1"
  local candidate
  for candidate in "${DEFAULT_BOTS[@]}"; do
    [[ "$candidate" == "$bot" ]] && return 0
  done
  return 1
}

update_terminal_cwd() {
  local config_file="$1"
  local target_cwd="$2"
  local tmp_file
  tmp_file="$(mktemp)"

  python3 - "$config_file" "$target_cwd" >"$tmp_file" <<'PY'
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
target_cwd = sys.argv[2]
lines = config_path.read_text(encoding="utf-8").splitlines()
updated = False

for i, line in enumerate(lines):
    if line.startswith("  cwd: "):
        lines[i] = f"  cwd: {target_cwd}"
        updated = True
        break

if not updated:
    raise SystemExit("terminal.cwd entry not found in config")

print("\n".join(lines) + "\n")
PY

  mv "$tmp_file" "$config_file"
}

main() {
  export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

  [[ $# -ge 2 ]] || {
    usage
    exit 1
  }

  local bot="$1"
  local target="$2"
  local profile_dir="$PROFILES_ROOT/$bot"
  local config_file="$profile_dir/config.yaml"
  local workspace_dir="$profile_dir/workspace"
  local target_cwd=""

  is_valid_bot "$bot" || die "Unsupported bot: $bot"
  [[ -d "$profile_dir" ]] || die "Profile directory not found: $profile_dir"
  [[ -f "$config_file" ]] || die "Config file not found: $config_file"

  if [[ "$target" == "--reset" ]]; then
    target_cwd="$workspace_dir"
  else
    [[ -d "$target" ]] || die "Project directory does not exist: $target"
    case "$target" in
      "$HOME"/*) ;;
      "$TEAM_ROOT_DEFAULT"/*) ;;
      *)
        die "Project directory must stay under your home or team documents path: $target"
        ;;
    esac
    target_cwd="$(cd "$target" && pwd)"
  fi

  require_cmd python3

  log "Switching $bot working directory to $target_cwd"
  update_terminal_cwd "$config_file" "$target_cwd"

  "$SCRIPT_DIR/hermes-reload-bot-soul.sh" "$bot" --no-verify

  log "$bot terminal.cwd is now:"
  sed -n '1,80p' "$config_file" | sed -n '/^terminal:/,/^[^ ]/p'
}

main "$@"
