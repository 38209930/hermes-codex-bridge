#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
INSTALL_DIR="${INSTALL_DIR:-$HERMES_HOME/hermes-agent}"
ROLLBACK_DIR="${ROLLBACK_DIR:-$HERMES_HOME/hermes-agent-preupgrade-rollback-$TIMESTAMP}"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME}"
PROFILE_DIR="${PROFILE_DIR:-$HERMES_HOME/profiles}"
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}"
HERMES_BIN="${HERMES_BIN:-$LOCAL_BIN_DIR/hermes}"

TARGET_TAG=""
KEEP_ROLLBACK_COPY=1
SKIP_DOCTOR=0
DRY_RUN=0

TMP_DIR=""
DOWNLOAD_PATH=""
EXTRACT_PARENT=""
MOVED_OLD_INSTALL=0
RUNNING_PROFILES=()
STOPPED_PROFILES=()

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME [--tag v2026.4.13] [--backup-root /path] [--no-doctor] [--delete-rollback-copy] [--dry-run]

What it does:
  1. Detects currently running Hermes Feishu gateway services
  2. Creates pre-upgrade backups
  3. Stops running gateway services
  4. Downloads the official Hermes source for the requested tag, or the latest tag if omitted
  5. Installs the new version with the official setup script
  6. Restarts previously running gateway services
  7. Runs a post-upgrade health check

Options:
  --tag TAG                 Upgrade to a specific Hermes tag, for example: v2026.4.13
  --backup-root PATH        Where backups should be written. Default: \$HOME
  --no-doctor               Skip the final 'hermes doctor'
  --delete-rollback-copy    Remove the old code directory after a successful upgrade
  --dry-run                 Show the steps without making changes
  -h, --help                Show this help
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

warn() {
  printf '[%s] WARNING: %s\n' "$(date '+%H:%M:%S')" "$*" >&2
}

die() {
  printf '[%s] ERROR: %s\n' "$(date '+%H:%M:%S')" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

rollback() {
  local exit_code="$1"
  trap - EXIT

  if [[ "$exit_code" -eq 0 ]]; then
    cleanup
    exit 0
  fi

  warn "Upgrade failed. Starting rollback."

  if [[ "$DRY_RUN" -eq 0 && "$MOVED_OLD_INSTALL" -eq 1 && -d "$ROLLBACK_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    mv "$ROLLBACK_DIR" "$INSTALL_DIR"
    warn "Restored previous Hermes install from $ROLLBACK_DIR"
  fi

  if [[ "$DRY_RUN" -eq 0 && ${#RUNNING_PROFILES[@]} -gt 0 ]]; then
    for profile in "${RUNNING_PROFILES[@]}"; do
      if "$HERMES_BIN" --profile "$profile" gateway start >/dev/null 2>&1; then
        warn "Restarted $profile after rollback"
      else
        warn "Could not restart $profile automatically after rollback"
      fi
    done
  fi

  cleanup
  exit "$exit_code"
}

trap 'rollback $?' EXIT

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag)
        [[ $# -ge 2 ]] || die "--tag requires a value"
        TARGET_TAG="$2"
        shift 2
        ;;
      --backup-root)
        [[ $# -ge 2 ]] || die "--backup-root requires a value"
        BACKUP_ROOT="$2"
        shift 2
        ;;
      --no-doctor)
        SKIP_DOCTOR=1
        shift
        ;;
      --delete-rollback-copy)
        KEEP_ROLLBACK_COPY=0
        shift
        ;;
      --dry-run)
        DRY_RUN=1
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

resolve_latest_tag() {
  git ls-remote --tags --refs https://github.com/NousResearch/hermes-agent.git 'v*' \
    | awk '{print $2}' \
    | sed 's#refs/tags/##' \
    | sort -V \
    | tail -n 1
}

detect_running_profiles() {
  RUNNING_PROFILES=()

  if [[ ! -d "$PROFILE_DIR" ]]; then
    return 0
  fi

  local profile
  while IFS= read -r profile; do
    if launchctl list | grep -q "ai.hermes.gateway-$profile"; then
      RUNNING_PROFILES+=("$profile")
    fi
  done < <(find "$PROFILE_DIR" -mindepth 1 -maxdepth 1 -type d -name 'feishu-bot*' -exec basename {} \; | sort)
}

print_plan() {
  log "Hermes home: $HERMES_HOME"
  log "Install dir:  $INSTALL_DIR"
  log "Backup root:  $BACKUP_ROOT"
  log "Target tag:   ${TARGET_TAG:-<latest>}"

  if [[ ${#RUNNING_PROFILES[@]} -eq 0 ]]; then
    log "Running gateways detected: none"
  else
    log "Running gateways detected: ${RUNNING_PROFILES[*]}"
  fi
}

create_backups() {
  mkdir -p "$BACKUP_ROOT"

  local data_backup="$BACKUP_ROOT/hermes-data-preupgrade-$TIMESTAMP.tgz"
  local code_backup="$BACKUP_ROOT/hermes-code-preupgrade-$TIMESTAMP.tgz"

  log "Creating Hermes data backup: $data_backup"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    tar --exclude='.hermes/hermes-agent' --exclude='.hermes/hermes-agent-preupgrade-rollback*' \
      -czf "$data_backup" -C "$HOME" .hermes
  fi

  if [[ -d "$INSTALL_DIR" ]]; then
    log "Creating Hermes code backup: $code_backup"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      tar -czf "$code_backup" -C "$HERMES_HOME" "$(basename "$INSTALL_DIR")"
    fi
  fi
}

stop_running_gateways() {
  STOPPED_PROFILES=()

  for profile in "${RUNNING_PROFILES[@]}"; do
    log "Stopping gateway: $profile"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      "$HERMES_BIN" --profile "$profile" gateway stop
    fi
    STOPPED_PROFILES+=("$profile")
  done
}

download_and_extract() {
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hermes-upgrade.XXXXXX")"
  DOWNLOAD_PATH="$TMP_DIR/hermes.tar.gz"
  EXTRACT_PARENT="$TMP_DIR/extracted"

  mkdir -p "$EXTRACT_PARENT"

  local url="https://codeload.github.com/NousResearch/hermes-agent/tar.gz/refs/tags/$TARGET_TAG"
  log "Downloading official Hermes source: $url"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    curl -fsSL "$url" -o "$DOWNLOAD_PATH"
    tar -xzf "$DOWNLOAD_PATH" -C "$EXTRACT_PARENT"
  fi
}

install_new_version() {
  local extracted_dir=""
  if [[ "$DRY_RUN" -eq 0 ]]; then
    extracted_dir="$(find "$EXTRACT_PARENT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [[ -n "$extracted_dir" && -d "$extracted_dir" ]] || die "Could not locate the extracted Hermes directory"
  fi

  if [[ -d "$INSTALL_DIR" ]]; then
    log "Moving current install aside: $ROLLBACK_DIR"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      mv "$INSTALL_DIR" "$ROLLBACK_DIR"
      MOVED_OLD_INSTALL=1
    fi
  fi

  log "Installing new Hermes code to: $INSTALL_DIR"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    mv "$extracted_dir" "$INSTALL_DIR"
    printf 'n\n' | "$INSTALL_DIR/setup-hermes.sh"
  fi
}

restart_gateways() {
  for profile in "${STOPPED_PROFILES[@]}"; do
    log "Restarting gateway: $profile"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      "$HERMES_BIN" --profile "$profile" gateway start
    fi
  done
}

post_checks() {
  log "Post-upgrade check: hermes version"
  [[ "$DRY_RUN" -eq 1 ]] || "$HERMES_BIN" version

  log "Post-upgrade check: hermes config show"
  [[ "$DRY_RUN" -eq 1 ]] || "$HERMES_BIN" config show | sed -n '1,60p'

  if [[ "$SKIP_DOCTOR" -eq 0 ]]; then
    log "Post-upgrade check: hermes doctor"
    [[ "$DRY_RUN" -eq 1 ]] || "$HERMES_BIN" doctor
  fi

  log "Post-upgrade check: launchd Hermes gateways"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    launchctl list | grep 'ai\.hermes\.gateway' || true
  fi
}

main() {
  parse_args "$@"

  export PATH="$LOCAL_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:$PATH"

  require_cmd git
  require_cmd curl
  require_cmd tar
  require_cmd launchctl

  [[ -x "$HERMES_BIN" ]] || die "Hermes binary not found or not executable: $HERMES_BIN"
  [[ -d "$HERMES_HOME" ]] || die "Hermes home directory not found: $HERMES_HOME"

  if [[ -z "$TARGET_TAG" ]]; then
    log "Resolving latest Hermes tag from the official repository"
    TARGET_TAG="$(resolve_latest_tag)"
    [[ -n "$TARGET_TAG" ]] || die "Could not resolve the latest Hermes tag"
  fi

  detect_running_profiles
  print_plan
  create_backups
  stop_running_gateways
  download_and_extract
  install_new_version
  restart_gateways
  post_checks

  if [[ "$KEEP_ROLLBACK_COPY" -eq 0 && "$DRY_RUN" -eq 0 && -d "$ROLLBACK_DIR" ]]; then
    log "Removing rollback copy: $ROLLBACK_DIR"
    rm -rf "$ROLLBACK_DIR"
  elif [[ "$MOVED_OLD_INSTALL" -eq 1 ]]; then
    log "Rollback copy kept at: $ROLLBACK_DIR"
  fi

  log "Hermes upgrade finished successfully."
  if [[ "$DRY_RUN" -eq 0 ]]; then
    log "You can roll back manually with:"
    log "  rm -rf '$INSTALL_DIR' && mv '$ROLLBACK_DIR' '$INSTALL_DIR'"
  fi
}

main "$@"
