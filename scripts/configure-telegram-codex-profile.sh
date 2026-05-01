#!/usr/bin/env bash

set -Eeuo pipefail

PROFILE="${PROFILE:-telegram-codex}"
PROFILE_DIR="$HOME/.hermes/profiles/$PROFILE"
ENV_FILE="$PROFILE_DIR/.env"
WORKSPACE_DIR="$PROFILE_DIR/workspace"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ -d "$PROFILE_DIR" ]] || die "Hermes profile not found: $PROFILE_DIR"
[[ -f "$ENV_FILE" ]] || die "Profile .env not found: $ENV_FILE"

printf 'Configuring Hermes profile: %s\n' "$PROFILE"
printf 'Profile dir: %s\n\n' "$PROFILE_DIR"

read -r -s -p "Telegram bot token from @BotFather: " TELEGRAM_BOT_TOKEN
printf '\n'
read -r -p "Your Telegram numeric user id from @userinfobot: " TELEGRAM_USER_ID

[[ -n "$TELEGRAM_BOT_TOKEN" ]] || die "Telegram bot token is required"
[[ -n "$TELEGRAM_USER_ID" ]] || die "Telegram user id is required"

python3 - "$ENV_FILE" "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_USER_ID" "$WORKSPACE_DIR" <<'PY'
from pathlib import Path
import sys

env_path = Path(sys.argv[1])
token = sys.argv[2]
user_id = sys.argv[3]
workspace = sys.argv[4]

updates = {
    "GATEWAY_ALLOW_ALL_USERS": "false",
    "TELEGRAM_ALLOW_ALL_USERS": "false",
    "TELEGRAM_REQUIRE_MENTION": "true",
    "TELEGRAM_BOT_TOKEN": token,
    "TELEGRAM_ALLOWED_USERS": user_id,
    "TELEGRAM_HOME_CHANNEL": user_id,
    "TERMINAL_CWD": workspace,
}

lines = env_path.read_text(encoding="utf-8").splitlines()
seen = set()
out = []

for line in lines:
    raw = line.strip()
    key = None
    if raw and not raw.startswith("#") and "=" in raw:
        key = raw.split("=", 1)[0].strip()
    elif raw.startswith("#") and "=" in raw:
        maybe = raw[1:].strip().split("=", 1)[0].strip()
        if maybe in updates:
            key = maybe

    if key in updates:
        out.append(f"{key}={updates[key]}")
        seen.add(key)
    else:
        out.append(line)

for key, value in updates.items():
    if key not in seen:
        out.append(f"{key}={value}")

env_path.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
PY

telegram-codex config set terminal.cwd "$WORKSPACE_DIR"

printf '\nStarting gateway...\n'
telegram-codex gateway start
telegram-codex gateway status

printf '\nDone. Send /codex_help to your Telegram bot for available commands.\n'
