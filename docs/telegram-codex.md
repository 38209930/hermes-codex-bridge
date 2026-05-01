# Telegram + Codex Bridge

## Goal

Use Telegram as a mobile approval and review surface for local Codex CLI planning tasks. The bridge is designed to be safe first: Telegram does not execute arbitrary shell text, and Codex CLI runs in read-only mode.

## Architecture

```text
Telegram
  -> Hermes profile: telegram-codex
  -> fixed quick commands
  -> scripts/mac-codex-bridge.sh
  -> Codex CLI read-only planning
  -> task result back to Telegram
```

## Telegram Setup

1. Create a bot with `@BotFather`.
2. Get your numeric user id from `@userinfobot`.
3. Put the token and user id in the dedicated Hermes profile `.env`.

Example:

```bash
TELEGRAM_BOT_TOKEN=<telegram_bot_token>
TELEGRAM_ALLOWED_USERS=<telegram_numeric_user_id>
TELEGRAM_HOME_CHANNEL=<telegram_numeric_user_id>
TELEGRAM_REQUIRE_MENTION=true
```

Do not paste real tokens into shared chats or commit them to git.

## Hermes Quick Commands

Configure fixed quick commands in the `telegram-codex` profile:

```text
/codex_status
/diff
/codex_review
/codex_resume_last
/codex_help
/task_new
/task_plan
/task_list
/task_show
/task_approve
/task_retry
/task_cancel
/task_reject
```

Quick commands intentionally do not accept arbitrary task text. This avoids command injection and keeps all executable behavior in audited local scripts.

## Task Queue Flow

1. Ask for task input instructions:

   ```text
   /task_new
   ```

2. Write a task prompt into:

   ```text
   ~/.hermes/profiles/telegram-codex/workspace/tasks/inbox.txt
   ```

3. Create a queued task:

   ```text
   /task_plan
   ```

4. Approve a read-only Codex planning run:

   ```text
   /task_approve
   ```

5. Check the result:

   ```text
   /task_show
   ```

6. Retry or cancel when needed:

   ```text
   /task_retry
   /task_cancel
   ```

## Environment Variables

`scripts/mac-codex-bridge.sh` supports:

```bash
MAC_CODEX_BRIDGE_PROFILE_HOME=~/.hermes/profiles/telegram-codex
MAC_CODEX_BRIDGE_WORKDIR=/path/to/repo
CODEX_BRIDGE_CODEX_BIN=/path/to/codex
CODEX_BRIDGE_TIMEOUT_SECONDS=120
```

If a local proxy is listening on `127.0.0.1:7890`, the script automatically exports standard proxy variables for Codex CLI unless they are already set.

## Safety Boundary

Approved tasks run Codex CLI with:

```bash
--sandbox read-only
--disable plugins
--disable apps
--disable general_analytics
-c notify=[]
```

The prompt tells Codex to output only:

- plan
- risks
- acceptance criteria
- suggested commands

It must not modify files, install dependencies, commit, push, deploy, or run migrations.

