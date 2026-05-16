#!/usr/bin/env bash
#
# Telegram/Codex bridge for a dedicated Hermes profile.
#
# Dependencies:
#   - Hermes Agent profile with Telegram gateway enabled
#   - Codex CLI logged in locally
#   - macOS launchctl for background task runners
#
# Safety:
#   - does not execute raw Telegram text as shell
#   - Telegram ordinary chat never enters the Codex task queue
#   - planning runs Codex CLI with --sandbox read-only
#   - write runs require explicit task_id + one-time approval code and use task branches
#   - commit and push are separate approval stages
#   - deploy remains disabled
#
# Optional environment variables:
#   MAC_CODEX_BRIDGE_PROFILE_HOME  default: ~/.hermes/profiles/telegram-codex
#   MAC_CODEX_BRIDGE_WORKDIR       default: current working directory
#   CODEX_BRIDGE_CODEX_BIN         default: first codex found on PATH
#   CODEX_BRIDGE_TIMEOUT_SECONDS   default: 120
#   CODEX_BRIDGE_WRITE_TIMEOUT_SECONDS default: 600
#   CODEX_BRIDGE_APPROVAL_TTL_SECONDS  default: 900

set -Eeuo pipefail

export PATH="$HOME/.nvm/versions/node/v22.15.1/bin:$HOME/.local/bin:/opt/homebrew/bin:/opt/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

ACTION="${1:-help}"
ARG="${2:-}"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

PROFILE_HOME="${MAC_CODEX_BRIDGE_PROFILE_HOME:-$HOME/.hermes/profiles/telegram-codex}"
TASK_DIR="$PROFILE_HOME/workspace/tasks"
TASKS_FILE="$TASK_DIR/tasks.jsonl"
INBOX_FILE="$TASK_DIR/inbox.txt"
ARCHIVE_DIR="$TASK_DIR/archive"
RESULTS_DIR="$TASK_DIR/results"
PID_DIR="$TASK_DIR/pids"
LOCK_DIR="$TASK_DIR/locks"
CANCEL_DIR="$TASK_DIR/cancel"
APPROVAL_DIR="$TASK_DIR/approvals"
AUDIT_LOG="$PROFILE_HOME/logs/codex-bridge-audit.log"
BACKGROUND_LOG="$PROFILE_HOME/logs/codex-bridge-background.log"
WORKDIR="${MAC_CODEX_BRIDGE_WORKDIR:-$PWD}"
CODEX_TIMEOUT_SECONDS="${CODEX_BRIDGE_TIMEOUT_SECONDS:-120}"
CODEX_WRITE_TIMEOUT_SECONDS="${CODEX_BRIDGE_WRITE_TIMEOUT_SECONDS:-600}"
APPROVAL_TTL_SECONDS="${CODEX_BRIDGE_APPROVAL_TTL_SECONDS:-900}"
CODEX_BIN="${CODEX_BRIDGE_CODEX_BIN:-$(command -v codex 2>/dev/null || true)}"

if [[ -z "${HTTPS_PROXY:-}" ]] && nc -z 127.0.0.1 7890 >/dev/null 2>&1; then
  export HTTPS_PROXY="http://127.0.0.1:7890"
  export HTTP_PROXY="http://127.0.0.1:7890"
  export ALL_PROXY="socks5://127.0.0.1:7890"
fi

log_section() {
  printf '\n## %s\n' "$*"
}

ensure_state() {
  mkdir -p "$TASK_DIR" "$ARCHIVE_DIR" "$RESULTS_DIR" "$PID_DIR" "$LOCK_DIR" "$CANCEL_DIR" "$APPROVAL_DIR" "$(dirname "$AUDIT_LOG")"
  touch "$TASKS_FILE" "$AUDIT_LOG" "$BACKGROUND_LOG"
}

safe_cd() {
  if [[ -d "$WORKDIR" ]]; then
    cd "$WORKDIR"
  fi
}

audit() {
  ensure_state
  local event="$1"
  local task_id="${2:-}"
  python3 - "$AUDIT_LOG" "$event" "$task_id" "$WORKDIR" <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import json
import sys

log_path, event, task_id, workdir = sys.argv[1:5]
record = {
    "ts": datetime.now(timezone.utc).isoformat(),
    "event": event,
    "task_id": task_id,
    "workdir": workdir,
}
with Path(log_path).open("a", encoding="utf-8") as fh:
    fh.write(json.dumps(record, ensure_ascii=False) + "\n")
PY
}

append_task_record() {
  ensure_state
  local task_id="$1"
  local status="$2"
  local prompt_file="$3"
  local result_path="${4:-}"
  local error="${5:-}"
  python3 - "$TASKS_FILE" "$task_id" "$status" "$prompt_file" "$WORKDIR" "$result_path" "$error" <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import json
import sys

tasks_path, task_id, status, prompt_file, workdir, result_path, error = sys.argv[1:8]
prompt = Path(prompt_file).read_text(encoding="utf-8") if prompt_file else ""
now = datetime.now(timezone.utc).isoformat()
record = {
    "task_id": task_id,
    "status": status,
    "prompt": prompt,
    "workdir": workdir,
    "result_path": result_path,
    "error": error,
    "updated_at": now,
}
if status == "waiting_approval":
    record["created_at"] = now
elif status == "approved":
    record["approved_at"] = now
elif status == "running":
    record["started_at"] = now
elif status in ("planned", "failed", "stale", "canceled", "written", "committed", "pushed", "rejected"):
    record["planned_at"] = now
with Path(tasks_path).open("a", encoding="utf-8") as fh:
    fh.write(json.dumps(record, ensure_ascii=False) + "\n")
PY
}

task_json() {
  ensure_state
  python3 - "$TASKS_FILE" <<'PY'
from pathlib import Path
import json
import sys

tasks_path = Path(sys.argv[1])
latest = {}
order = []
for line in tasks_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    rec = json.loads(line)
    tid = rec.get("task_id")
    if not tid:
        continue
    if tid not in latest:
        order.append(tid)
    latest[tid] = {**latest.get(tid, {}), **rec}

print(json.dumps({"order": order, "latest": latest}, ensure_ascii=False))
PY
}

latest_task_by_status() {
  ensure_state
  python3 - "$TASKS_FILE" "$@" <<'PY'
from pathlib import Path
import json
import sys

tasks_path = Path(sys.argv[1])
wanted = set(sys.argv[2:])
latest = {}
order = []
for line in tasks_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    rec = json.loads(line)
    tid = rec.get("task_id")
    if not tid:
        continue
    if tid not in latest:
        order.append(tid)
    latest[tid] = {**latest.get(tid, {}), **rec}

for tid in reversed(order):
    if latest[tid].get("status") in wanted:
        print(tid)
        raise SystemExit
raise SystemExit(1)
PY
}

task_status() {
  ensure_state
  local task_id="$1"
  python3 - "$TASKS_FILE" "$task_id" <<'PY'
from pathlib import Path
import json
import sys

tasks_path = Path(sys.argv[1])
task_id = sys.argv[2]
latest = {}
for line in tasks_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    rec = json.loads(line)
    tid = rec.get("task_id")
    if tid:
        latest[tid] = {**latest.get(tid, {}), **rec}
rec = latest.get(task_id)
if not rec:
    raise SystemExit(1)
print(rec.get("status", ""))
PY
}

task_field() {
  ensure_state
  local task_id="$1"
  local field="$2"
  python3 - "$TASKS_FILE" "$task_id" "$field" <<'PY'
from pathlib import Path
import json
import sys

tasks_path = Path(sys.argv[1])
task_id = sys.argv[2]
field = sys.argv[3]
latest = {}
for line in tasks_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    rec = json.loads(line)
    tid = rec.get("task_id")
    if tid:
        latest[tid] = {**latest.get(tid, {}), **rec}
rec = latest.get(task_id)
if not rec:
    raise SystemExit(1)
print(rec.get(field, ""))
PY
}

quick_args() {
  printf '%s\n' "${HERMES_QUICK_COMMAND_ARGS:-}"
}

validate_task_id() {
  [[ "$1" =~ ^t[0-9]{8}-[0-9]{6}$ ]]
}

validate_approval_code_format() {
  [[ "$1" =~ ^[A-Z0-9]{6}$ ]]
}

task_id_from_quick_args() {
  local args first rest
  args="$(quick_args)"
  read -r first rest <<<"$args"
  if ! validate_task_id "${first:-}"; then
    cat >&2 <<EOF
Invalid or missing task_id.

Usage examples:
  /write_prepare t20260501-130501
  /commit_prepare t20260501-130501
EOF
    return 1
  fi
  printf '%s\n' "$first"
}

task_id_and_code_from_quick_args() {
  local args task_id code rest
  args="$(quick_args)"
  read -r task_id code rest <<<"$args"
  if ! validate_task_id "${task_id:-}"; then
    printf 'Invalid or missing task_id.\n' >&2
    return 1
  fi
  if ! validate_approval_code_format "${code:-}"; then
    printf 'Invalid or missing approval code. Expected 6 uppercase letters/digits.\n' >&2
    return 1
  fi
  printf '%s %s\n' "$task_id" "$code"
}

approval_path() {
  local task_id="$1"
  local stage="$2"
  printf '%s/%s.%s.json\n' "$APPROVAL_DIR" "$task_id" "$stage"
}

create_approval_code() {
  ensure_state
  local task_id="$1"
  local stage="$2"
  local branch="${3:-}"
  local path
  path="$(approval_path "$task_id" "$stage")"
  python3 - "$path" "$task_id" "$stage" "$branch" "$APPROVAL_TTL_SECONDS" <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import json
import secrets
import string
import sys
import time

path, task_id, stage, branch, ttl_s = sys.argv[1:6]
alphabet = string.ascii_uppercase + string.digits
code = "".join(secrets.choice(alphabet) for _ in range(6))
now = int(time.time())
record = {
    "task_id": task_id,
    "stage": stage,
    "code": code,
    "branch": branch,
    "created_at": datetime.now(timezone.utc).isoformat(),
    "expires_at_epoch": now + int(ttl_s),
}
Path(path).write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"{code} {record['expires_at_epoch']}")
PY
}

validate_approval_code() {
  ensure_state
  local task_id="$1"
  local stage="$2"
  local code="$3"
  local path
  path="$(approval_path "$task_id" "$stage")"
  python3 - "$path" "$task_id" "$stage" "$code" <<'PY'
from pathlib import Path
import json
import sys
import time

path, task_id, stage, code = sys.argv[1:5]
approval_path = Path(path)
if not approval_path.exists():
    print("Approval code not found. Run the matching *_prepare command first.", file=sys.stderr)
    raise SystemExit(1)
record = json.loads(approval_path.read_text(encoding="utf-8"))
if record.get("task_id") != task_id or record.get("stage") != stage:
    print("Approval code does not match this task/stage.", file=sys.stderr)
    raise SystemExit(1)
if record.get("code") != code:
    print("Approval code is incorrect.", file=sys.stderr)
    raise SystemExit(1)
if int(time.time()) > int(record.get("expires_at_epoch", 0)):
    print("Approval code expired. Run the matching *_prepare command again.", file=sys.stderr)
    raise SystemExit(1)
print(record.get("branch", ""))
PY
}

consume_approval_code() {
  local task_id="$1"
  local stage="$2"
  rm -f "$(approval_path "$task_id" "$stage")"
}

task_branch() {
  local task_id="$1"
  printf 'codex/%s\n' "$task_id"
}

require_git_repo() {
  safe_cd
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Current workdir is not a git repo: %s\n' "$(pwd)"
    return 1
  fi
}

ensure_no_tracked_dirty() {
  require_git_repo || return 1
  local dirty
  dirty="$(git status --porcelain --untracked-files=no)"
  if [[ -n "$dirty" ]]; then
    cat <<EOF
Tracked working tree changes exist. Refusing to continue.

$dirty
EOF
    return 1
  fi
}

ensure_no_any_dirty_for_commit_stage() {
  require_git_repo || return 1
  if [[ -z "$(git status --porcelain)" ]]; then
    printf 'No working tree changes to commit.\n'
    return 1
  fi
}

sync_master_and_create_task_branch() {
  local task_id="$1"
  local branch
  branch="$(task_branch "$task_id")"
  ensure_no_tracked_dirty || return 1
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    printf 'Task branch already exists locally: %s\n' "$branch"
    return 1
  fi
  git switch master >/dev/null
  git fetch origin master >/dev/null 2>&1 || {
    printf 'Failed to fetch origin/master. Refusing to create write branch.\n'
    return 1
  }
  git pull --ff-only origin master >/dev/null || {
    printf 'master is not fast-forward clean with origin/master. Refusing to continue.\n'
    return 1
  }
  git switch -c "$branch" >/dev/null
  printf '%s\n' "$branch"
}

ensure_task_branch() {
  local task_id="$1"
  local branch current
  branch="$(task_branch "$task_id")"
  require_git_repo || return 1
  current="$(git branch --show-current)"
  if [[ "$current" != "$branch" ]]; then
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      git switch "$branch" >/dev/null
    else
      printf 'Task branch does not exist: %s\n' "$branch"
      return 1
    fi
  fi
  current="$(git branch --show-current)"
  if [[ "$current" == "master" ]]; then
    printf 'Refusing to run this action on master.\n'
    return 1
  fi
  [[ "$current" == "$branch" ]] || {
    printf 'Current branch mismatch. Expected %s, got %s\n' "$branch" "$current"
    return 1
  }
}

all_task_ids_by_status() {
  ensure_state
  python3 - "$TASKS_FILE" "$@" <<'PY'
from pathlib import Path
import json
import sys

tasks_path = Path(sys.argv[1])
wanted = set(sys.argv[2:])
latest = {}
order = []
for line in tasks_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    rec = json.loads(line)
    tid = rec.get("task_id")
    if not tid:
        continue
    if tid not in latest:
        order.append(tid)
    latest[tid] = {**latest.get(tid, {}), **rec}

for tid in order:
    if latest[tid].get("status") in wanted:
        print(tid)
PY
}

pid_is_running() {
  local pid_file="$1"
  [[ -s "$pid_file" ]] || return 1
  local pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

mark_stale_running_tasks() {
  ensure_state
  local task_id prompt_file pid_file result_file error_file
  while IFS= read -r task_id; do
    [[ -n "$task_id" ]] || continue
    pid_file="$PID_DIR/$task_id.pid"
    result_file="$RESULTS_DIR/$task_id.plan.txt"
    error_file="$RESULTS_DIR/$task_id.error.txt"
    if pid_is_running "$pid_file"; then
      continue
    fi
    prompt_file="$ARCHIVE_DIR/$task_id.txt"
    if [[ -s "$result_file" ]]; then
      append_task_record "$task_id" "planned" "$prompt_file" "$result_file"
      audit "task_planned_recovered" "$task_id"
    else
      local err="Runner is no longer active and no result was recorded. Use /task_retry."
      if [[ -s "$error_file" ]]; then
        err="$(tail -n 20 "$error_file" 2>/dev/null || true)"
      fi
      append_task_record "$task_id" "stale" "$prompt_file" "$result_file" "$err"
      audit "task_stale" "$task_id"
    fi
    launchctl remove "ai.hermes.codex-task.$task_id" >/dev/null 2>&1 || true
    rm -f "$pid_file" "$LOCK_DIR/$task_id.lock"
  done < <(all_task_ids_by_status running || true)
}

cleanup_terminal_task_artifacts() {
  ensure_state
  local task_id
  while IFS= read -r task_id; do
    [[ -n "$task_id" ]] || continue
    launchctl remove "ai.hermes.codex-task.$task_id" >/dev/null 2>&1 || true
    launchctl remove "ai.hermes.codex-write.$task_id" >/dev/null 2>&1 || true
    rm -f "$PID_DIR/$task_id.pid" "$PID_DIR/$task_id.child.pid" "$LOCK_DIR/$task_id.lock"
  done < <(all_task_ids_by_status planned failed rejected canceled written committed pushed || true)
}

print_status() {
  safe_cd
  log_section "Node"
  printf 'Host: %s\n' "$(hostname)"
  printf 'Working directory: %s\n' "$(pwd)"

  log_section "Versions"
  hermes --version 2>/dev/null | sed -n '1,4p' || true
  if [[ -n "$CODEX_BIN" ]]; then
    printf 'Codex CLI: %s\n' "$CODEX_BIN"
    "$CODEX_BIN" --version 2>/dev/null || true
  else
    printf 'Codex CLI: not found. Set CODEX_BRIDGE_CODEX_BIN or install codex on PATH.\n'
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_section "Git"
    printf 'Branch: %s\n' "$(git branch --show-current 2>/dev/null || true)"
    git status --short
  else
    log_section "Git"
    printf 'Not inside a git worktree.\n'
  fi
}

print_diff() {
  safe_cd
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Not inside a git worktree: %s\n' "$(pwd)"
    return 0
  fi

  log_section "Diff Stat"
  git diff --stat

  log_section "Status"
  git status --short
}

run_review() {
  safe_cd
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Codex review needs a git worktree. Current directory: %s\n' "$(pwd)"
    return 0
  fi

  codex exec review
}

resume_last() {
  safe_cd
  codex exec resume --last "继续最近的 CLI 会话，先给我下一步计划。不要写文件，除非我明确批准。"
}

task_new() {
  ensure_state
  cat <<EOF
Create a V2 task by writing the task prompt into:

  $INBOX_FILE

On this Mac you can run:

  open -e "$INBOX_FILE"

After saving the prompt, send this in Telegram:

  /task_plan

V2.5 safety: Telegram slash commands do not accept arbitrary task text yet.
EOF
}

task_plan() {
  ensure_state
  if [[ ! -s "$INBOX_FILE" ]]; then
    cat <<EOF
No task prompt found.

Write the task prompt into:

  $INBOX_FILE

Then send:

  /task_plan
EOF
    return 0
  fi

  local task_id
  task_id="t$(date '+%Y%m%d-%H%M%S')"
  local prompt_file="$ARCHIVE_DIR/$task_id.txt"
  cp "$INBOX_FILE" "$prompt_file"
  : > "$INBOX_FILE"
  append_task_record "$task_id" "waiting_approval" "$prompt_file"
  audit "task_plan_created" "$task_id"

  cat <<EOF
Task created: $task_id
Status: waiting_approval
Workdir: $WORKDIR

Next:
  /task_show
  /task_approve
  /task_reject

V2.5 approval only asks Codex CLI for a plan. It will not write files.
EOF
}

task_list() {
  ensure_state
  mark_stale_running_tasks
  cleanup_terminal_task_artifacts
  python3 - "$TASKS_FILE" "$RESULTS_DIR" <<'PY'
from pathlib import Path
import json
import sys

tasks_path = Path(sys.argv[1])
results_dir = Path(sys.argv[2])
latest = {}
order = []
for line in tasks_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    rec = json.loads(line)
    tid = rec.get("task_id")
    if not tid:
        continue
    if tid not in latest:
        order.append(tid)
    latest[tid] = {**latest.get(tid, {}), **rec}

if not order:
    print("No tasks yet. Use /task_new for instructions.")
    raise SystemExit

print("Recent tasks:")
for tid in order[-10:]:
    rec = latest[tid]
    prompt = " ".join((rec.get("prompt") or "").split())
    if len(prompt) > 60:
        prompt = prompt[:57] + "..."
    updated = rec.get("updated_at", "")
    result_exists = any((results_dir / f"{tid}.{suffix}").exists() for suffix in ("plan.txt", "write.txt", "commit.txt", "push.txt"))
    result = "result=yes" if result_exists else "result=no"
    print(f"- {tid} [{rec.get('status', 'unknown')}] {updated} {result} {prompt}")
PY
}

task_show() {
  ensure_state
  mark_stale_running_tasks
  cleanup_terminal_task_artifacts
  python3 - "$TASKS_FILE" "$RESULTS_DIR" <<'PY'
from pathlib import Path
import json
import sys

MAX_INLINE_CHARS = 3500

def compact(text, label):
    text = (text or "").strip()
    if "__cf_chl" in text or "challenge-platform" in text or "Cloudflare" in text:
        return label, (
            "Codex CLI reached a Cloudflare challenge while contacting chatgpt.com. "
            "Run `codex login` locally and verify Codex CLI network access, then retry the task."
        )
    if len(text) <= MAX_INLINE_CHARS:
        return label, text
    return f"{label} (last {MAX_INLINE_CHARS} chars)", text[-MAX_INLINE_CHARS:]

tasks_path = Path(sys.argv[1])
results_dir = Path(sys.argv[2])
latest = {}
order = []
for line in tasks_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    rec = json.loads(line)
    tid = rec.get("task_id")
    if not tid:
        continue
    if tid not in latest:
        order.append(tid)
    latest[tid] = {**latest.get(tid, {}), **rec}

if not order:
    print("No tasks yet. Use /task_new for instructions.")
    raise SystemExit

terminal = {"planned", "failed", "rejected", "canceled", "written", "committed", "pushed"}
selected = None
for tid in reversed(order):
    if latest[tid].get("status") not in terminal:
        selected = tid
        break
if selected is None:
    selected = order[-1]

rec = latest[selected]
tid = rec.get("task_id")
print(f"Task: {rec.get('task_id')}")
print(f"Status: {rec.get('status')}")
print(f"Workdir: {rec.get('workdir')}")
print(f"Updated: {rec.get('updated_at')}")
print("")
print("Prompt:")
print((rec.get("prompt") or "").strip() or "<empty>")

error = rec.get("error")
if error:
    label, error = compact(error, "Error")
    print("")
    print(f"{label}:")
    print(error)

result_path = rec.get("result_path") or str(results_dir / f"{tid}.plan.txt")
if result_path and Path(result_path).exists():
    result = Path(result_path).read_text(encoding="utf-8", errors="replace")
    label, result = compact(result, "Result")
    print("")
    print(f"{label}:")
    print(result.strip())
else:
    status = rec.get("status")
    if status == "approved":
        print("")
        print("Task is approved but runner has not started yet. Send /task_show again in a bit.")
    elif status == "running":
        print("")
        print("Planning job is running. Send /task_show again in a bit.")
    elif status == "writing":
        print("")
        print("Write job is running on the task branch. Send /task_show again in a bit.")
    elif status == "waiting_write_approval":
        print("")
        print("Next: /write_approve <task_id> <code> or /write_reject <task_id>")
    elif status == "waiting_commit_approval":
        print("")
        print("Next: /commit_approve <task_id> <code>")
    elif status == "waiting_push_approval":
        print("")
        print("Next: /push_approve <task_id> <code>")
    elif status == "committing":
        print("")
        print("Commit is running. Send /task_show again in a bit.")
    elif status == "pushing":
        print("")
        print("Push is running. Send /task_show again in a bit.")
    elif status == "stale":
        print("")
        print("Runner stopped before a final result was recorded. Next: /task_retry or /task_reject")
    elif status == "waiting_approval":
        print("")
        print("Next: /task_approve or /task_reject")
PY
}

latest_waiting_task() {
  latest_task_by_status waiting_approval
}

latest_retryable_task() {
  mark_stale_running_tasks
  latest_task_by_status failed stale
}

latest_running_task() {
  mark_stale_running_tasks
  latest_task_by_status running
}

start_task_runner() {
  ensure_state
  local task_id="$1"
  local prompt_file="$ARCHIVE_DIR/$task_id.txt"
  local pid_file="$PID_DIR/$task_id.pid"
  local child_pid_file="$PID_DIR/$task_id.child.pid"
  local lock_file="$LOCK_DIR/$task_id.lock"
  local result_file="$RESULTS_DIR/$task_id.plan.txt"
  local error_file="$RESULTS_DIR/$task_id.error.txt"
  local runner_script="$TASK_DIR/mac-codex-bridge-runner.sh"

  if [[ ! -s "$prompt_file" ]]; then
    append_task_record "$task_id" "failed" "$prompt_file" "" "Prompt file not found"
    audit "task_failed_missing_prompt" "$task_id"
    printf 'Task failed: %s\nPrompt file not found.\n' "$task_id"
    return 0
  fi

  if pid_is_running "$pid_file"; then
    printf 'Task is already running: %s\n' "$task_id"
    return 0
  fi

  rm -f "$lock_file" "$pid_file" "$child_pid_file" "$CANCEL_DIR/$task_id.flag" "$result_file" "$error_file"
  append_task_record "$task_id" "running" "$prompt_file" "$result_file"
  audit "task_running" "$task_id"

  local runner_pid=""
  local label="ai.hermes.codex-task.$task_id"
  if command -v launchctl >/dev/null 2>&1; then
    cp "$SCRIPT_PATH" "$runner_script"
    chmod 700 "$runner_script"
    launchctl remove "$label" >/dev/null 2>&1 || true
    local launch_cmd
    launch_cmd="exec /bin/bash \"$runner_script\" run-plan \"$task_id\" >>\"$BACKGROUND_LOG\" 2>&1"
    if launchctl submit -l "$label" -- /bin/bash -lc "$launch_cmd" >/dev/null 2>&1; then
      for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        if [[ -s "$pid_file" ]]; then
          runner_pid="$(cat "$pid_file")"
          break
        fi
        if [[ -s "$result_file" || -s "$error_file" ]]; then
          runner_pid="completed"
          break
        fi
        sleep 0.2
      done
      if [[ -z "$runner_pid" ]]; then
        append_task_record "$task_id" "failed" "$prompt_file" "" "Runner did not create a PID or result file after launchctl submit."
        audit "task_failed_runner_no_pid" "$task_id"
        printf 'Task failed: %s\nRunner did not create a PID or result file.\n' "$task_id"
        return 0
      fi
    else
      append_task_record "$task_id" "failed" "$prompt_file" "" "Failed to submit launchctl background runner."
      audit "task_failed_launchctl_submit" "$task_id"
      printf 'Task failed: %s\nCould not submit launchctl runner.\n' "$task_id"
      return 0
    fi
  else
    nohup bash "$SCRIPT_PATH" run-plan "$task_id" >>"$BACKGROUND_LOG" 2>&1 &
    runner_pid=$!
    printf '%s\n' "$runner_pid" > "$pid_file"
  fi

  cat <<EOF
Task runner started: $task_id
Status: running
PID: $runner_pid

Send this in a bit:
  /task_show

V2.5 safety: Codex CLI runs in read-only planning mode only.
EOF
}

task_reject() {
  ensure_state
  mark_stale_running_tasks
  local task_id
  if ! task_id="$(latest_task_by_status waiting_approval stale)"; then
    printf 'No waiting_approval or stale task to reject.\n'
    return 0
  fi
  local prompt_file="$ARCHIVE_DIR/$task_id.txt"
  append_task_record "$task_id" "rejected" "$prompt_file"
  audit "task_rejected" "$task_id"
  printf 'Task rejected: %s\n' "$task_id"
}

task_approve() {
  ensure_state
  local task_id
  if ! task_id="$(latest_waiting_task)"; then
    printf 'No waiting_approval task to approve.\n'
    return 0
  fi

  local prompt_file="$ARCHIVE_DIR/$task_id.txt"
  append_task_record "$task_id" "approved" "$prompt_file"
  audit "task_approved" "$task_id"

  cat <<EOF
Task approved: $task_id
Starting Codex CLI in the background.

V2.5 safety: this only asks Codex CLI for a plan in read-only mode. It will not write files.
EOF

  start_task_runner "$task_id"
}

task_retry() {
  ensure_state
  local task_id
  if ! task_id="$(latest_retryable_task)"; then
    printf 'No failed or stale task to retry.\n'
    return 0
  fi

  local prompt_file="$ARCHIVE_DIR/$task_id.txt"
  append_task_record "$task_id" "approved" "$prompt_file"
  audit "task_retry" "$task_id"
  printf 'Retrying task: %s\n' "$task_id"
  start_task_runner "$task_id"
}

task_cancel() {
  ensure_state
  local task_id
  if ! task_id="$(latest_running_task)"; then
    printf 'No running task to cancel.\n'
    return 0
  fi

  local prompt_file="$ARCHIVE_DIR/$task_id.txt"
  local pid_file="$PID_DIR/$task_id.pid"
  local child_pid_file="$PID_DIR/$task_id.child.pid"
  local lock_file="$LOCK_DIR/$task_id.lock"
  local pid
  local child_pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  child_pid="$(cat "$child_pid_file" 2>/dev/null || true)"
  touch "$CANCEL_DIR/$task_id.flag"
  if [[ "$child_pid" =~ ^[0-9]+$ ]] && kill -0 "$child_pid" >/dev/null 2>&1; then
    kill "$child_pid" >/dev/null 2>&1 || true
    sleep 1
    kill -9 "$child_pid" >/dev/null 2>&1 || true
  fi
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" >/dev/null 2>&1; then
    pkill -TERM -P "$pid" >/dev/null 2>&1 || true
    kill "$pid" >/dev/null 2>&1 || true
    sleep 1
    pkill -KILL -P "$pid" >/dev/null 2>&1 || true
    kill -9 "$pid" >/dev/null 2>&1 || true
  fi
  launchctl remove "ai.hermes.codex-task.$task_id" >/dev/null 2>&1 || true
  rm -f "$pid_file" "$child_pid_file" "$lock_file"
  append_task_record "$task_id" "canceled" "$prompt_file" "" "Canceled by user."
  audit "task_cancel" "$task_id"
  printf 'Task canceled: %s\n' "$task_id"
}

run_plan() {
  ensure_state
  local task_id="$1"
  local prompt_file="$ARCHIVE_DIR/$task_id.txt"
  local result_file="$RESULTS_DIR/$task_id.plan.txt"
  local error_file="$RESULTS_DIR/$task_id.error.txt"
  local pid_file="$PID_DIR/$task_id.pid"
  local child_pid_file="$PID_DIR/$task_id.child.pid"
  local lock_file="$LOCK_DIR/$task_id.lock"
  local cancel_file="$CANCEL_DIR/$task_id.flag"
  local launch_label="ai.hermes.codex-task.$task_id"

  if [[ ! -s "$prompt_file" ]]; then
    append_task_record "$task_id" "failed" "$prompt_file" "" "Prompt file not found"
    audit "task_failed_missing_prompt" "$task_id"
    return 0
  fi

  if [[ -z "$CODEX_BIN" || ! -x "$CODEX_BIN" ]]; then
    append_task_record "$task_id" "failed" "$prompt_file" "" "Codex CLI binary not found. Check Node/nvm PATH or set CODEX_BRIDGE_CODEX_BIN."
    audit "task_failed_codex_missing" "$task_id"
    return 0
  fi

  if [[ -e "$lock_file" ]]; then
    if pid_is_running "$pid_file"; then
      audit "task_run_skipped_locked" "$task_id"
      printf 'Task is already running: %s\n' "$task_id"
      return 0
    fi
    rm -f "$lock_file" "$pid_file"
  fi

  if ! (set -C; printf '%s\n' "$$" > "$lock_file") 2>/dev/null; then
    audit "task_run_skipped_lock_busy" "$task_id"
    printf 'Task lock is busy: %s\n' "$task_id"
    return 0
  fi
  printf '%s\n' "$$" > "$pid_file"

  cleanup_runner() {
    launchctl remove "$launch_label" >/dev/null 2>&1 || true
    rm -f "$lock_file" "$pid_file" "$child_pid_file"
  }
  trap cleanup_runner EXIT

  safe_cd
  local prompt
  prompt="$(cat "$prompt_file")"
  local codex_prompt
  codex_prompt=$(cat <<EOF
你正在通过 Telegram 审批层处理一个远程任务。

严格安全要求：
- 只输出计划、风险、验收标准和建议命令。
- 不要修改文件。
- 不要安装依赖。
- 不要提交、推送、部署或迁移数据。
- 如果任务需要写入，请明确列出需要用户后续批准的动作。

当前项目目录：
$WORKDIR

用户任务：
$prompt
EOF
)

  audit "task_plan_started" "$task_id"
  if python3 - "$WORKDIR" "$CODEX_TIMEOUT_SECONDS" "$result_file" "$error_file" "$codex_prompt" "$CODEX_BIN" "$child_pid_file" <<'PY'
import subprocess
import sys

workdir, timeout_s, result_file, error_file, prompt, codex_bin, child_pid_file = sys.argv[1:8]
cmd = [
    codex_bin,
    "exec",
    "-C",
    workdir,
    "--sandbox",
    "read-only",
    "--disable",
    "plugins",
    "--disable",
    "apps",
    "--disable",
    "general_analytics",
    "-c",
    "notify=[]",
    "--ephemeral",
    "-",
]
MAX_ERROR_CHARS = 6000

def normalize(value):
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return str(value)

def tail(value, max_chars=MAX_ERROR_CHARS):
    value = normalize(value)
    if "__cf_chl" in value or "challenge-platform" in value or "Cloudflare" in value:
        return (
            "Codex CLI reached a Cloudflare challenge while contacting chatgpt.com. "
            "Run `codex login` locally and verify Codex CLI network access, then retry the task."
        )
    if len(value) <= max_chars:
        return value
    return value[-max_chars:]

try:
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=workdir,
    )
    with open(child_pid_file, "w", encoding="utf-8") as fh:
        fh.write(str(proc.pid))
    stdout, stderr = proc.communicate(input=prompt, timeout=int(timeout_s))
except subprocess.TimeoutExpired as exc:
    try:
        proc.kill()
    except Exception:
        pass
    stdout, stderr = proc.communicate()
    with open(result_file, "w", encoding="utf-8") as fh:
        fh.write(normalize(stdout))
    with open(error_file, "w", encoding="utf-8") as fh:
        fh.write(f"Codex CLI timed out after {timeout_s} seconds. Check `codex login` and provider/network status.\n")
        stderr = tail(stderr)
        if stderr:
            fh.write("\n--- stderr tail ---\n")
            fh.write(stderr)
    raise SystemExit(124)

with open(result_file, "w", encoding="utf-8") as fh:
    fh.write(normalize(stdout))
with open(error_file, "w", encoding="utf-8") as fh:
    fh.write(tail(stderr))
raise SystemExit(proc.returncode)
PY
  then
    if [[ -e "$cancel_file" ]]; then
      audit "task_canceled_runner_exit" "$task_id"
      return 0
    fi
    append_task_record "$task_id" "planned" "$prompt_file" "$result_file"
    audit "task_planned" "$task_id"
  else
    if [[ -e "$cancel_file" ]]; then
      audit "task_canceled_runner_exit" "$task_id"
      return 0
    fi
    local err
    err="$(tail -n 40 "$error_file" 2>/dev/null || true)"
    append_task_record "$task_id" "failed" "$prompt_file" "$result_file" "$err"
    audit "task_failed" "$task_id"
  fi
}

write_prepare() {
  ensure_state
  local task_id status prompt_file result_path branch approval code expires_at
  task_id="$(task_id_from_quick_args)" || return 0
  status="$(task_status "$task_id" 2>/dev/null || true)"
  if [[ "$status" != "planned" ]]; then
    printf 'Task %s is not planned. Current status: %s\nRun /task_approve first and wait for a plan.\n' "$task_id" "${status:-missing}"
    return 0
  fi
  ensure_no_tracked_dirty || return 0
  prompt_file="$ARCHIVE_DIR/$task_id.txt"
  result_path="$(task_field "$task_id" result_path 2>/dev/null || true)"
  branch="$(task_branch "$task_id")"
  approval="$(create_approval_code "$task_id" "write" "$branch")"
  read -r code expires_at <<<"$approval"
  append_task_record "$task_id" "waiting_write_approval" "$prompt_file" "$result_path"
  audit "write_prepare" "$task_id"

  cat <<EOF
Write approval prepared: $task_id
Target branch: $branch
Approval code: $code
Expires at epoch: $expires_at

Approve with:
  /write_approve $task_id $code

Reject with:
  /write_reject $task_id

Safety:
  - write runs only on $branch
  - write runs do not commit, push, deploy, install dependencies, or run migrations
  - master is never used for Codex write operations
EOF
  if [[ -n "$result_path" && -s "$result_path" ]]; then
    log_section "Plan Tail"
    tail -n 40 "$result_path"
  fi
}

write_reject() {
  ensure_state
  local task_id status prompt_file result_path
  task_id="$(task_id_from_quick_args)" || return 0
  status="$(task_status "$task_id" 2>/dev/null || true)"
  if [[ "$status" != "waiting_write_approval" ]]; then
    printf 'Task %s is not waiting for write approval. Current status: %s\n' "$task_id" "${status:-missing}"
    return 0
  fi
  prompt_file="$ARCHIVE_DIR/$task_id.txt"
  result_path="$(task_field "$task_id" result_path 2>/dev/null || true)"
  consume_approval_code "$task_id" "write"
  append_task_record "$task_id" "rejected" "$prompt_file" "$result_path" "Write rejected by user."
  audit "write_reject" "$task_id"
  printf 'Write rejected: %s\n' "$task_id"
}

start_write_runner() {
  ensure_state
  local task_id="$1"
  local prompt_file="$ARCHIVE_DIR/$task_id.txt"
  local pid_file="$PID_DIR/$task_id.write.pid"
  local result_file="$RESULTS_DIR/$task_id.write.txt"
  local error_file="$RESULTS_DIR/$task_id.write.error.txt"
  local runner_script="$TASK_DIR/mac-codex-bridge-runner.sh"
  local label="ai.hermes.codex-write.$task_id"
  local runner_pid=""

  rm -f "$pid_file" "$result_file" "$error_file" "$LOCK_DIR/$task_id.write.lock"
  append_task_record "$task_id" "writing" "$prompt_file" "$result_file"
  audit "write_running" "$task_id"

  if command -v launchctl >/dev/null 2>&1; then
    cp "$SCRIPT_PATH" "$runner_script"
    chmod 700 "$runner_script"
    launchctl remove "$label" >/dev/null 2>&1 || true
    local launch_cmd
    launch_cmd="exec /bin/bash \"$runner_script\" run-write \"$task_id\" >>\"$BACKGROUND_LOG\" 2>&1"
    if ! launchctl submit -l "$label" -- /bin/bash -lc "$launch_cmd" >/dev/null 2>&1; then
      append_task_record "$task_id" "failed" "$prompt_file" "" "Failed to submit launchctl write runner."
      audit "write_failed_launchctl_submit" "$task_id"
      printf 'Write failed to start: %s\n' "$task_id"
      return 0
    fi
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
      if [[ -s "$pid_file" ]]; then
        runner_pid="$(cat "$pid_file")"
        break
      fi
      sleep 0.2
    done
  else
    nohup bash "$SCRIPT_PATH" run-write "$task_id" >>"$BACKGROUND_LOG" 2>&1 &
    runner_pid=$!
    printf '%s\n' "$runner_pid" > "$pid_file"
  fi

  cat <<EOF
Write runner started: $task_id
Status: writing
PID: ${runner_pid:-pending}

Send later:
  /task_show
  /commit_prepare $task_id
EOF
}

write_approve() {
  ensure_state
  local parsed task_id code status branch prompt_file result_path
  parsed="$(task_id_and_code_from_quick_args)" || return 0
  read -r task_id code <<<"$parsed"
  status="$(task_status "$task_id" 2>/dev/null || true)"
  if [[ "$status" != "waiting_write_approval" ]]; then
    printf 'Task %s is not waiting for write approval. Current status: %s\n' "$task_id" "${status:-missing}"
    return 0
  fi
  validate_approval_code "$task_id" "write" "$code" >/dev/null || return 0
  prompt_file="$ARCHIVE_DIR/$task_id.txt"
  result_path="$(task_field "$task_id" result_path 2>/dev/null || true)"
  if ! branch="$(sync_master_and_create_task_branch "$task_id")"; then
    append_task_record "$task_id" "failed" "$prompt_file" "$result_path" "Could not create a clean task branch."
    audit "write_failed_branch_prepare" "$task_id"
    return 0
  fi
  consume_approval_code "$task_id" "write"
  audit "write_approved" "$task_id"
  printf 'Write approved: %s\nBranch: %s\n' "$task_id" "$branch"
  start_write_runner "$task_id"
}

run_write() {
  ensure_state
  local task_id="$1"
  local prompt_file="$ARCHIVE_DIR/$task_id.txt"
  local plan_file="$RESULTS_DIR/$task_id.plan.txt"
  local result_file="$RESULTS_DIR/$task_id.write.txt"
  local error_file="$RESULTS_DIR/$task_id.write.error.txt"
  local pid_file="$PID_DIR/$task_id.write.pid"
  local child_pid_file="$PID_DIR/$task_id.write.child.pid"
  local lock_file="$LOCK_DIR/$task_id.write.lock"
  local launch_label="ai.hermes.codex-write.$task_id"

  if [[ -z "$CODEX_BIN" || ! -x "$CODEX_BIN" ]]; then
    append_task_record "$task_id" "failed" "$prompt_file" "" "Codex CLI binary not found."
    audit "write_failed_codex_missing" "$task_id"
    return 0
  fi
  if ! (set -C; printf '%s\n' "$$" > "$lock_file") 2>/dev/null; then
    audit "write_skipped_lock_busy" "$task_id"
    return 0
  fi
  printf '%s\n' "$$" > "$pid_file"
  cleanup_write_runner() {
    launchctl remove "$launch_label" >/dev/null 2>&1 || true
    rm -f "$lock_file" "$pid_file" "$child_pid_file"
  }
  trap cleanup_write_runner EXIT

  safe_cd
  ensure_task_branch "$task_id" || {
    append_task_record "$task_id" "failed" "$prompt_file" "" "Task branch is not available."
    audit "write_failed_branch_missing" "$task_id"
    return 0
  }

  local prompt plan codex_prompt
  prompt="$(cat "$prompt_file")"
  plan="$(cat "$plan_file" 2>/dev/null || true)"
  codex_prompt=$(cat <<EOF
你正在通过 Telegram 显式审批层执行一个已批准的 Codex 写文件任务。

严格安全要求：
- 只允许在当前 git 仓库和当前任务分支写文件。
- 当前分支必须是 $(task_branch "$task_id")。
- 可以修改工作区文件来完成任务。
- 不要 commit。
- 不要 push。
- 不要 deploy。
- 不要安装依赖。
- 不要运行数据库迁移、生产脚本或破坏性命令。
- 不要读取或输出 token、secret、.env 或其他敏感内容。
- 完成后只输出变更摘要、涉及文件、风险、建议验收步骤。

当前项目目录：
$WORKDIR

任务 ID：
$task_id

用户任务：
$prompt

只读计划：
$plan
EOF
)

  audit "write_started" "$task_id"
  if python3 - "$WORKDIR" "$CODEX_WRITE_TIMEOUT_SECONDS" "$result_file" "$error_file" "$codex_prompt" "$CODEX_BIN" "$child_pid_file" <<'PY'
import subprocess
import sys

workdir, timeout_s, result_file, error_file, prompt, codex_bin, child_pid_file = sys.argv[1:8]
cmd = [
    codex_bin,
    "exec",
    "-C",
    workdir,
    "--sandbox",
    "workspace-write",
    "--disable",
    "plugins",
    "--disable",
    "apps",
    "--disable",
    "general_analytics",
    "-c",
    "notify=[]",
    "--ephemeral",
    "-",
]

def tail(value, max_chars=6000):
    value = value or ""
    if len(value) <= max_chars:
        return value
    return value[-max_chars:]

try:
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=workdir,
    )
    with open(child_pid_file, "w", encoding="utf-8") as fh:
        fh.write(str(proc.pid))
    stdout, stderr = proc.communicate(input=prompt, timeout=int(timeout_s))
except subprocess.TimeoutExpired:
    try:
        proc.kill()
    except Exception:
        pass
    stdout, stderr = proc.communicate()
    with open(result_file, "w", encoding="utf-8") as fh:
        fh.write(stdout or "")
    with open(error_file, "w", encoding="utf-8") as fh:
        fh.write(f"Codex CLI write timed out after {timeout_s} seconds.\n")
        fh.write(tail(stderr or ""))
    raise SystemExit(124)

with open(result_file, "w", encoding="utf-8") as fh:
    fh.write(stdout or "")
with open(error_file, "w", encoding="utf-8") as fh:
    fh.write(tail(stderr or ""))
raise SystemExit(proc.returncode)
PY
  then
    if [[ -n "$(git status --porcelain)" ]]; then
      append_task_record "$task_id" "written" "$prompt_file" "$result_file"
      audit "write_written" "$task_id"
    else
      append_task_record "$task_id" "failed" "$prompt_file" "$result_file" "Codex write completed but no file changes were produced."
      audit "write_failed_no_changes" "$task_id"
    fi
  else
    local err
    err="$(tail -n 40 "$error_file" 2>/dev/null || true)"
    append_task_record "$task_id" "failed" "$prompt_file" "$result_file" "$err"
    audit "write_failed" "$task_id"
  fi
}

commit_prepare() {
  ensure_state
  local task_id status prompt_file result_path approval code expires_at
  task_id="$(task_id_from_quick_args)" || return 0
  status="$(task_status "$task_id" 2>/dev/null || true)"
  if [[ "$status" != "written" ]]; then
    printf 'Task %s is not written. Current status: %s\n' "$task_id" "${status:-missing}"
    return 0
  fi
  ensure_task_branch "$task_id" || return 0
  ensure_no_any_dirty_for_commit_stage || return 0
  prompt_file="$ARCHIVE_DIR/$task_id.txt"
  result_path="$RESULTS_DIR/$task_id.commit.txt"
  approval="$(create_approval_code "$task_id" "commit" "$(task_branch "$task_id")")"
  read -r code expires_at <<<"$approval"
  append_task_record "$task_id" "waiting_commit_approval" "$prompt_file" "$result_path"
  audit "commit_prepare" "$task_id"
  cat <<EOF
Commit approval prepared: $task_id
Branch: $(git branch --show-current)
Approval code: $code
Expires at epoch: $expires_at
Suggested message: V3 task $task_id

Approve with:
  /commit_approve $task_id $code
EOF
  log_section "Git Status"
  git status --short
  log_section "Diff Stat"
  git diff --stat
}

commit_approve() {
  ensure_state
  local parsed task_id code status prompt_file result_file commit_sha
  parsed="$(task_id_and_code_from_quick_args)" || return 0
  read -r task_id code <<<"$parsed"
  status="$(task_status "$task_id" 2>/dev/null || true)"
  if [[ "$status" != "waiting_commit_approval" ]]; then
    printf 'Task %s is not waiting for commit approval. Current status: %s\n' "$task_id" "${status:-missing}"
    return 0
  fi
  validate_approval_code "$task_id" "commit" "$code" >/dev/null || return 0
  ensure_task_branch "$task_id" || return 0
  ensure_no_any_dirty_for_commit_stage || return 0
  prompt_file="$ARCHIVE_DIR/$task_id.txt"
  result_file="$RESULTS_DIR/$task_id.commit.txt"
  append_task_record "$task_id" "committing" "$prompt_file" "$result_file"
  audit "commit_committing" "$task_id"
  git add -A -- .
  git commit -m "V3 task $task_id" >"$result_file" 2>&1 || {
    append_task_record "$task_id" "failed" "$prompt_file" "$result_file" "git commit failed."
    audit "commit_failed" "$task_id"
    cat "$result_file"
    return 0
  }
  commit_sha="$(git rev-parse --short HEAD)"
  consume_approval_code "$task_id" "commit"
  append_task_record "$task_id" "committed" "$prompt_file" "$result_file"
  audit "commit_committed" "$task_id"
  printf 'Committed task %s as %s on %s\n' "$task_id" "$commit_sha" "$(git branch --show-current)"
}

push_prepare() {
  ensure_state
  local task_id status prompt_file result_path approval code expires_at
  task_id="$(task_id_from_quick_args)" || return 0
  status="$(task_status "$task_id" 2>/dev/null || true)"
  if [[ "$status" != "committed" ]]; then
    printf 'Task %s is not committed. Current status: %s\n' "$task_id" "${status:-missing}"
    return 0
  fi
  ensure_task_branch "$task_id" || return 0
  prompt_file="$ARCHIVE_DIR/$task_id.txt"
  result_path="$RESULTS_DIR/$task_id.push.txt"
  approval="$(create_approval_code "$task_id" "push" "$(task_branch "$task_id")")"
  read -r code expires_at <<<"$approval"
  append_task_record "$task_id" "waiting_push_approval" "$prompt_file" "$result_path"
  audit "push_prepare" "$task_id"
  cat <<EOF
Push approval prepared: $task_id
Branch: $(git branch --show-current)
Remote: origin
Approval code: $code
Expires at epoch: $expires_at

Approve with:
  /push_approve $task_id $code

After push, open a GitHub Pull Request into master. Do not merge directly into master.
EOF
  log_section "Latest Commit"
  git log -1 --oneline
}

push_approve() {
  ensure_state
  local parsed task_id code status prompt_file result_file branch repo_url pr_url
  parsed="$(task_id_and_code_from_quick_args)" || return 0
  read -r task_id code <<<"$parsed"
  status="$(task_status "$task_id" 2>/dev/null || true)"
  if [[ "$status" != "waiting_push_approval" ]]; then
    printf 'Task %s is not waiting for push approval. Current status: %s\n' "$task_id" "${status:-missing}"
    return 0
  fi
  validate_approval_code "$task_id" "push" "$code" >/dev/null || return 0
  ensure_task_branch "$task_id" || return 0
  prompt_file="$ARCHIVE_DIR/$task_id.txt"
  result_file="$RESULTS_DIR/$task_id.push.txt"
  branch="$(task_branch "$task_id")"
  append_task_record "$task_id" "pushing" "$prompt_file" "$result_file"
  audit "push_pushing" "$task_id"
  git push -u origin "$branch" >"$result_file" 2>&1 || {
    append_task_record "$task_id" "failed" "$prompt_file" "$result_file" "git push failed."
    audit "push_failed" "$task_id"
    cat "$result_file"
    return 0
  }
  consume_approval_code "$task_id" "push"
  append_task_record "$task_id" "pushed" "$prompt_file" "$result_file"
  audit "push_pushed" "$task_id"
  repo_url="$(git config --get remote.origin.url | sed -E 's#git@github.com:#https://github.com/#; s#\\.git$##')"
  pr_url="$repo_url/pull/new/$branch"
  printf 'Pushed task %s branch: %s\nPR URL: %s\n' "$task_id" "$branch" "$pr_url"
}

deploy_prepare() {
  local task_id="" args first rest
  args="$(quick_args)"
  read -r first rest <<<"$args"
  if validate_task_id "${first:-}"; then
    task_id="$first"
  fi
  cat <<EOF
Deploy is disabled in this version.

Task: ${task_id:-<not provided>}

V3 only supports explicit approval for:
  - write files on a codex/<task_id> branch
  - commit on that task branch
  - push that task branch

Deploy requires a separate design, environment policy, rollback plan, and explicit approval workflow.
See:
  docs/future-write-capabilities.md
  docs/v3-explicit-approval.md
EOF
}

print_help() {
  cat <<'EOF'
Mac Codex bridge commands:

  /codex_status       Show Hermes, Codex, cwd, and git status.
  /diff               Show git diff stat and status.
  /codex_review       Run `codex exec review` in the current worktree.
  /codex_resume_last  Resume the latest Codex CLI session with a planning prompt.
  /codex_help         Show this help.

V2.5/V3 task queue commands:

  /task_new           Show where to write a task prompt.
  /task_plan          Create a waiting_approval task from inbox.txt.
  /task_list          List recent tasks with status, update time, and result flag.
  /task_show          Show the latest active task, or latest completed task.
  /task_approve       Approve the latest waiting task and start a background runner.
  /task_retry         Retry the latest failed or stale task.
  /task_cancel        Cancel the latest running task.
  /task_reject        Reject the latest waiting or stale task.

V3 explicit approval commands:

  /write_prepare <task_id>        Prepare a one-time code for writing files.
  /write_approve <task_id> <code> Create codex/<task_id> and run Codex write mode.
  /write_reject <task_id>         Reject a pending write approval.
  /commit_prepare <task_id>       Prepare a one-time code for committing branch changes.
  /commit_approve <task_id> <code> Commit the task branch locally.
  /push_prepare <task_id>         Prepare a one-time code for pushing the task branch.
  /push_approve <task_id> <code>  Push codex/<task_id> to origin only.
  /deploy_prepare <task_id>       Explain why deploy is disabled.

Safety:
  - Quick commands do not accept arbitrary shell text.
  - Ordinary Telegram messages never enter the Codex queue.
  - /task_approve runs Codex CLI in read-only mode and asks for a plan only.
  - write, commit, and push each require task_id plus a separate one-time code.
  - write mode only runs on codex/<task_id>; master is never used for writes.
  - deploy remains disabled.
EOF
}

case "$ACTION" in
  status)
    print_status
    ;;
  diff)
    print_diff
    ;;
  review)
    run_review
    ;;
  resume-last)
    resume_last
    ;;
  task-new)
    task_new
    ;;
  task-plan)
    task_plan
    ;;
  task-list)
    task_list
    ;;
  task-show)
    task_show
    ;;
  task-approve)
    task_approve
    ;;
  task-retry)
    task_retry
    ;;
  task-cancel)
    task_cancel
    ;;
  task-reject)
    task_reject
    ;;
  write-prepare)
    write_prepare
    ;;
  write-approve)
    write_approve
    ;;
  write-reject)
    write_reject
    ;;
  commit-prepare)
    commit_prepare
    ;;
  commit-approve)
    commit_approve
    ;;
  push-prepare)
    push_prepare
    ;;
  push-approve)
    push_approve
    ;;
  deploy-prepare)
    deploy_prepare
    ;;
  run-plan)
    [[ -n "$ARG" ]] || {
      printf 'run-plan requires task_id\n' >&2
      exit 1
    }
    run_plan "$ARG"
    ;;
  run-write)
    [[ -n "$ARG" ]] || {
      printf 'run-write requires task_id\n' >&2
      exit 1
    }
    run_write "$ARG"
    ;;
  help|*)
    print_help
    ;;
esac
