#!/usr/bin/env bash
#
# 为本机 Hermes quick command 的 exec 类型补充安全参数传递。
#
# 这个补丁只通过环境变量传递 Telegram slash command 参数：
#   HERMES_QUICK_COMMAND_NAME
#   HERMES_QUICK_COMMAND_ARGS
#   HERMES_QUICK_COMMAND_RAW
#
# 它不会把参数拼进 shell command，因此 bridge 脚本仍必须自行做白名单解析。

set -Eeuo pipefail

HERMES_AGENT_HOME="${HERMES_AGENT_HOME:-$HOME/.hermes/hermes-agent}"
GATEWAY_RUN="$HERMES_AGENT_HOME/gateway/run.py"
CLI_PY="$HERMES_AGENT_HOME/cli.py"
MARKER="hermes-codex-bridge quick command args env patch"

usage() {
  cat <<EOF
Usage:
  $0            Apply the local Hermes quick command args patch.
  $0 --check    Check whether the patch is present.
  $0 --restore  Restore the latest backups created by this script.

Environment:
  HERMES_AGENT_HOME  default: $HOME/.hermes/hermes-agent
EOF
}

require_files() {
  [[ -f "$GATEWAY_RUN" ]] || {
    printf 'Hermes gateway file not found: %s\n' "$GATEWAY_RUN" >&2
    exit 1
  }
  [[ -f "$CLI_PY" ]] || {
    printf 'Hermes CLI file not found: %s\n' "$CLI_PY" >&2
    exit 1
  }
}

is_patched_file() {
  local file="$1"
  grep -q "HERMES_QUICK_COMMAND_ARGS" "$file" && grep -q "$MARKER" "$file"
}

check_patch() {
  require_files
  local ok=0
  if is_patched_file "$GATEWAY_RUN"; then
    printf 'OK: gateway quick command args patch is present.\n'
  else
    printf 'MISSING: gateway quick command args patch is not present.\n'
    ok=1
  fi
  if is_patched_file "$CLI_PY"; then
    printf 'OK: CLI quick command args patch is present.\n'
  else
    printf 'MISSING: CLI quick command args patch is not present.\n'
    ok=1
  fi
  return "$ok"
}

backup_file() {
  local file="$1"
  local stamp
  stamp="$(date '+%Y%m%d-%H%M%S')"
  cp "$file" "$file.hermes-codex-bridge.bak.$stamp"
  printf 'Backup: %s.hermes-codex-bridge.bak.%s\n' "$file" "$stamp"
}

restore_latest() {
  require_files
  local file backup
  for file in "$GATEWAY_RUN" "$CLI_PY"; do
    backup="$(ls -t "$file".hermes-codex-bridge.bak.* 2>/dev/null | head -n 1 || true)"
    if [[ -z "$backup" ]]; then
      printf 'No backup found for %s\n' "$file"
      continue
    fi
    cp "$backup" "$file"
    printf 'Restored %s from %s\n' "$file" "$backup"
  done
}

apply_patch_with_python() {
  require_files
  python3 - "$GATEWAY_RUN" "$CLI_PY" "$MARKER" <<'PY'
from pathlib import Path
import shutil
import sys
from datetime import datetime

gateway_run = Path(sys.argv[1])
cli_py = Path(sys.argv[2])
marker = sys.argv[3]
stamp = datetime.now().strftime("%Y%m%d-%H%M%S")

def backup(path: Path):
    dst = path.with_name(path.name + f".hermes-codex-bridge.bak.{stamp}")
    shutil.copy2(path, dst)
    print(f"Backup: {dst}")

def patch_gateway(path: Path):
    text = path.read_text(encoding="utf-8")
    if "HERMES_QUICK_COMMAND_ARGS" in text and marker in text:
        print(f"Already patched: {path}")
        return
    old = """                            proc = await asyncio.create_subprocess_shell(
                                exec_cmd,
                                stdout=asyncio.subprocess.PIPE,
                                stderr=asyncio.subprocess.PIPE,
                            )
"""
    new = f"""                            # {marker}
                            import os
                            quick_env = os.environ.copy()
                            quick_env["HERMES_QUICK_COMMAND_NAME"] = command
                            quick_env["HERMES_QUICK_COMMAND_ARGS"] = event.get_command_args().strip()
                            quick_env["HERMES_QUICK_COMMAND_RAW"] = event.text or ""
                            proc = await asyncio.create_subprocess_shell(
                                exec_cmd,
                                stdout=asyncio.subprocess.PIPE,
                                stderr=asyncio.subprocess.PIPE,
                                env=quick_env,
                            )
"""
    if old not in text:
        raise SystemExit(f"Gateway patch anchor not found: {path}")
    backup(path)
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print(f"Patched: {path}")

def patch_cli(path: Path):
    text = path.read_text(encoding="utf-8")
    if "HERMES_QUICK_COMMAND_ARGS" in text and marker in text:
        print(f"Already patched: {path}")
        return
    old = """                            result = subprocess.run(
                                exec_cmd, shell=True, capture_output=True,
                                text=True, timeout=30
                            )
"""
    new = f"""                            # {marker}
                            import os
                            user_args = cmd_original[len(base_cmd):].strip()
                            quick_env = os.environ.copy()
                            quick_env["HERMES_QUICK_COMMAND_NAME"] = base_cmd.lstrip("/")
                            quick_env["HERMES_QUICK_COMMAND_ARGS"] = user_args
                            quick_env["HERMES_QUICK_COMMAND_RAW"] = cmd_original
                            result = subprocess.run(
                                exec_cmd, shell=True, capture_output=True,
                                text=True, timeout=30, env=quick_env
                            )
"""
    if old not in text:
        raise SystemExit(f"CLI patch anchor not found: {path}")
    backup(path)
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print(f"Patched: {path}")

patch_gateway(gateway_run)
patch_cli(cli_py)
PY
}

case "${1:-}" in
  --help|-h)
    usage
    ;;
  --check)
    check_patch
    ;;
  --restore)
    restore_latest
    ;;
  "")
    apply_patch_with_python
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
