#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
PROFILES_ROOT="$HERMES_HOME/profiles"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}"
export PATH="$LOCAL_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:$PATH"

BOTS=(feishu-bot1 feishu-bot2 feishu-bot3 feishu-bot4)
VERIFY_PERSONA=1
VERIFY_DOCTOR=1
VERIFY_GATEWAY=1

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME [--no-persona] [--no-doctor] [--no-gateway]

Checks:
  - profile-local config/env/state.db/memories/workspace/home/skills
  - built-in memory only
  - terminal.cwd pinned to profile-local workspace
  - workspace AGENTS.md exists
  - gateway loaded
  - persona matches the assigned team role
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

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-persona)
        VERIFY_PERSONA=0
        shift
        ;;
      --no-doctor)
        VERIFY_DOCTOR=0
        shift
        ;;
      --no-gateway)
        VERIFY_GATEWAY=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

expected_role_hint() {
  case "$1" in
    feishu-bot1) echo "数字幕僚长|Chief of Staff|产品|任务|推进" ;;
    feishu-bot2) echo "后端|全栈|工程|实现|backend" ;;
    feishu-bot3) echo "架构|review|裁决|一致性|风险" ;;
    feishu-bot4) echo "前端|视觉|交互|体验|frontend" ;;
    *) echo "." ;;
  esac
}

check_profile_layout() {
  local bot="$1"
  local base="$PROFILES_ROOT/$bot"
  local cfg="$base/config.yaml"
  local envf="$base/.env"
  local db="$base/state.db"
  local memories="$base/memories"
  local workspace="$base/workspace"
  local home="$base/home"
  local skills="$base/skills"
  local agents="$workspace/AGENTS.md"

  [[ -d "$base" ]] || die "$bot profile directory missing: $base"
  [[ -f "$cfg" ]] || die "$bot config missing: $cfg"
  [[ -f "$envf" ]] || die "$bot env missing: $envf"
  [[ -f "$db" ]] || die "$bot state.db missing: $db"
  [[ -d "$memories" ]] || die "$bot memories dir missing: $memories"
  [[ -d "$workspace" ]] || die "$bot workspace dir missing: $workspace"
  [[ -d "$home" ]] || die "$bot home dir missing: $home"
  [[ -d "$skills" ]] || die "$bot skills dir missing: $skills"
  [[ -f "$agents" ]] || die "$bot workspace guard missing: $agents"

  if ! rg -q "^memory:" "$cfg"; then
    :
  elif rg -q "provider:" "$cfg"; then
    die "$bot config declares an external memory provider: $cfg"
  fi

  rg -q "^terminal:" "$cfg" || die "$bot terminal block missing in $cfg"
  rg -q "cwd: $workspace$" "$cfg" || die "$bot terminal.cwd is not pinned to $workspace"
  rg -q "backend: local" "$cfg" || die "$bot terminal backend is not local"
}

check_doctor_memory() {
  local bot="$1"
  local out
  out="$("$bot" doctor)"
  grep -q "Built-in memory active" <<<"$out" || die "$bot is not using built-in memory only"
  if grep -q "memory.provider" <<<"$out"; then
    :
  fi
}

check_gateway() {
  local bot="$1"
  "$bot" gateway status | rg -q "Gateway service is loaded" || die "$bot gateway is not loaded"
}

check_persona() {
  local bot="$1"
  local hint
  local out
  hint="$(expected_role_hint "$bot")"
  out="$("$bot" chat -q "请只用一句中文介绍你的角色定位，不要提Hermes、不要提AI助手。")"
  printf '%s\n' "$out" | sed -n '/╭─ ⚕ Hermes/,/Resume this session/p'
  printf '%s\n' "$out" | rg -qi "$hint" || die "$bot persona check did not match expected role hint: $hint"
}

main() {
  parse_args "$@"
  require_cmd rg
  require_cmd sed

  for bot in "${BOTS[@]}"; do
    log "Auditing $bot"
    check_profile_layout "$bot"
    if [[ "$VERIFY_DOCTOR" -eq 1 ]]; then
      check_doctor_memory "$bot"
    fi
    if [[ "$VERIFY_GATEWAY" -eq 1 ]]; then
      check_gateway "$bot"
    fi
    if [[ "$VERIFY_PERSONA" -eq 1 ]]; then
      check_persona "$bot"
    fi
  done

  log "All four Hermes bots passed the team isolation audit."
}

main "$@"
