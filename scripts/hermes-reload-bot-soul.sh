#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
PROFILES_ROOT="$HERMES_HOME/profiles"
VERIFY_PROMPT="请只用一句中文介绍你的角色定位，不要提Hermes、不要提AI助手。"
DEFAULT_BOTS=(feishu-bot1 feishu-bot2 feishu-bot3 feishu-bot4)

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME [feishu-bot1 ...] [--all] [--no-verify]

What it does:
  1. Checks that each target bot profile has a SOUL.md
  2. Restarts the target bot gateway
  3. Verifies the live persona with a one-line self-introduction

Examples:
  $SCRIPT_NAME feishu-bot1
  $SCRIPT_NAME feishu-bot1 feishu-bot3
  $SCRIPT_NAME --all
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

VERIFY=1
TARGETS=()

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        TARGETS=("${DEFAULT_BOTS[@]}")
        shift
        ;;
      --no-verify)
        VERIFY=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        TARGETS+=("$1")
        shift
        ;;
    esac
  done

  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    die "No bot specified. Use --all or pass one or more bot names."
  fi
}

check_profile() {
  local bot="$1"
  local profile_dir="$PROFILES_ROOT/$bot"
  [[ -d "$profile_dir" ]] || die "Profile not found: $profile_dir"
  [[ -f "$profile_dir/SOUL.md" ]] || die "SOUL.md not found for $bot"
  [[ -f "$profile_dir/config.yaml" ]] || die "config.yaml not found for $bot"
  [[ -f "$profile_dir/.env" ]] || die ".env not found for $bot"
}

restart_gateway() {
  local bot="$1"
  log "Reloading $bot"
  "$bot" gateway stop >/dev/null 2>&1 || true
  "$bot" gateway start
  "$bot" gateway status | sed -n '1,30p'
}

assert_gateway_loaded() {
  local bot="$1"
  local attempt
  for attempt in 1 2 3; do
    if "$bot" gateway status | rg -q "Gateway service is loaded"; then
      return 0
    fi
    if launchctl list | rg -q "ai\\.hermes\\.gateway-$bot"; then
      return 0
    fi
    sleep 2
  done
  die "$bot gateway did not stay loaded after reload"
}

verify_persona() {
  local bot="$1"
  log "Verifying live persona for $bot"
  "$bot" chat -q "$VERIFY_PROMPT" | sed -n '/╭─ ⚕ Hermes/,/Resume this session/p'
}

main() {
  parse_args "$@"
  export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

  require_cmd sed

  for bot in "${TARGETS[@]}"; do
    check_profile "$bot"
  done

  for bot in "${TARGETS[@]}"; do
    restart_gateway "$bot"
    if [[ "$VERIFY" -eq 1 ]]; then
      verify_persona "$bot"
    fi
    assert_gateway_loaded "$bot"
  done

  log "Done."
}

main "$@"
