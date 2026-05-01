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
#   - runs Codex CLI with --sandbox read-only
#   - asks Codex to return plans, risks, acceptance criteria, and suggested commands only
#
# Optional environment variables:
#   MAC_CODEX_BRIDGE_PROFILE_HOME  default: ~/.hermes/profiles/telegram-codex
#   MAC_CODEX_BRIDGE_WORKDIR       default: current working directory
#   CODEX_BRIDGE_CODEX_BIN         default: first codex found on PATH
#   CODEX_BRIDGE_TIMEOUT_SECONDS   default: 120

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
AUDIT_LOG="$PROFILE_HOME/logs/codex-bridge-audit.log"
BACKGROUND_LOG="$PROFILE_HOME/logs/codex-bridge-background.log"
WORKDIR="${MAC_CODEX_BRIDGE_WORKDIR:-$PWD}"
CODEX_TIMEOUT_SECONDS="${CODEX_BRIDGE_TIMEOUT_SECONDS:-120}"
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
  mkdir -p "$TASK_DIR" "$ARCHIVE_DIR" "$RESULTS_DIR" "$PID_DIR" "$LOCK_DIR" "$CANCEL_DIR" "$(dirname "$AUDIT_LOG")"
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
elif status in ("planned", "failed", "stale", "canceled"):
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
    rm -f "$PID_DIR/$task_id.pid" "$PID_DIR/$task_id.child.pid" "$LOCK_DIR/$task_id.lock"
  done < <(all_task_ids_by_status planned failed rejected canceled || true)
}

print_status() {
  safe_cd
  log_section "Node"
  printf 'Host: %s\n' "$(hostname)"
  printf 'Working directory: %s\n' "$(pwd)"

  log_section "Versions"
  hermes --version 2>/dev/null | sed -n '1,4p' || true
  codex --version 2>/dev/null || true

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
    result = "result=yes" if (results_dir / f"{tid}.plan.txt").exists() else "result=no"
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

terminal = {"planned", "failed", "rejected", "canceled"}
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

print_help() {
  cat <<'EOF'
Mac Codex bridge commands:

  /codex_status       Show Hermes, Codex, cwd, and git status.
  /diff               Show git diff stat and status.
  /codex_review       Run `codex exec review` in the current worktree.
  /codex_resume_last  Resume the latest Codex CLI session with a planning prompt.
  /codex_help         Show this help.

V2.5 task queue commands:

  /task_new           Show where to write a task prompt.
  /task_plan          Create a waiting_approval task from inbox.txt.
  /task_list          List recent tasks with status, update time, and result flag.
  /task_show          Show the latest active task, or latest completed task.
  /task_approve       Approve the latest waiting task and start a background runner.
  /task_retry         Retry the latest failed or stale task.
  /task_cancel        Cancel the latest running task.
  /task_reject        Reject the latest waiting or stale task.

Safety:
  - Quick commands do not accept arbitrary shell text.
  - /task_approve runs Codex CLI in read-only mode and asks for a plan only.
  - File writes, commits, pushes, migrations, and deploys are not part of V2.5.
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
  run-plan)
    [[ -n "$ARG" ]] || {
      printf 'run-plan requires task_id\n' >&2
      exit 1
    }
    run_plan "$ARG"
    ;;
  help|*)
    print_help
    ;;
esac
