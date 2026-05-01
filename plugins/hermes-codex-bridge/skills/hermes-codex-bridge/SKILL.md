---
name: hermes-codex-bridge
description: Deploy, verify, troubleshoot, and extend hermes-codex-bridge, a Telegram + Hermes approval bridge for Codex CLI tasks with read-only planning and explicit write/commit/push approvals. Use when the user asks to install the bridge, connect Telegram, configure Hermes quick commands, validate V3 approvals, package the project, or debug bridge behavior.
---

# Hermes Codex Bridge

Use this skill when helping a user operate `hermes-codex-bridge`.

The goal is convenience without weakening the safety model. The bridge is not a remote shell and must not become one.

## Hard Safety Rules

- Ordinary Telegram messages never enter the Codex task queue.
- Do not add Telegram ordinary-message auto-enqueue behavior.
- Do not execute arbitrary Telegram text as shell.
- Do not approve writes with vague commands like `/approve`.
- Do not write on `master`.
- Do not combine write, commit, push, and deploy into one approval.
- Do not enable deploy. `/deploy_prepare <task_id>` only explains that deploy is disabled.
- Do not expose or print token, secret, `.env`, API key, or provider credential values.

## What This Plugin Helps With

- Install Codex CLI and verify `codex exec`.
- Create or inspect a dedicated Hermes profile, usually `telegram-codex`.
- Configure Telegram bot token and allowed numeric user id in the profile `.env`.
- Configure Hermes quick commands that call `scripts/mac-codex-bridge.sh`.
- Apply and verify the Hermes quick command args patch.
- Validate the V2.5 read-only queue.
- Validate the V3 explicit approval flow.
- Explain safe extension points for Feishu, Slack, Discord, or team approval.

## Standard Deployment Flow

1. Confirm the repository path and Hermes profile.

   Default examples:

   ```text
   repo: /Volumes/SSD/myot/AI-WORK/hermes-codex-bridge
   profile: telegram-codex
   ```

2. Verify Codex CLI.

   ```bash
   codex --version
   codex exec "用一句话说明 Codex CLI 已可用"
   ```

3. Verify Hermes gateway.

   ```bash
   hermes --profile telegram-codex gateway status
   hermes --profile telegram-codex gateway restart
   ```

4. Apply quick command argument support when V3 commands need `<task_id>` or `<code>`.

   ```bash
   scripts/hermes-enable-quick-command-args.sh --check
   scripts/hermes-enable-quick-command-args.sh
   scripts/hermes-enable-quick-command-args.sh --check
   hermes --profile telegram-codex gateway restart
   ```

5. Verify quick commands are loaded.

   ```bash
   PYTHONPATH="$HOME/.hermes/hermes-agent" \
   HERMES_HOME="$HOME/.hermes/profiles/telegram-codex" \
   python3 -c "from gateway.config import load_gateway_config; print(sorted(load_gateway_config().quick_commands.keys()))"
   ```

## Read-Only Queue Flow

Use this path first for every task:

```text
/task_new
/task_plan
/task_show
/task_approve
/task_show
```

Expected state:

```text
waiting_approval -> approved -> running -> planned
```

`/task_approve` must run Codex CLI with:

```text
--sandbox read-only
--disable plugins
--disable apps
--disable general_analytics
-c notify=[]
```

## V3 Explicit Approval Flow

Only continue after a task reaches `planned`.

Write files:

```text
/write_prepare <task_id>
/write_approve <task_id> <code>
```

Commit:

```text
/commit_prepare <task_id>
/commit_approve <task_id> <code>
```

Push:

```text
/push_prepare <task_id>
/push_approve <task_id> <code>
```

Deploy:

```text
/deploy_prepare <task_id>
```

Deploy must remain disabled.

## Troubleshooting Checklist

If Telegram does not respond:

- Check `hermes --profile telegram-codex gateway status`.
- Check the profile `.env` exists and contains Telegram variables without printing their values.
- Check `TELEGRAM_ALLOWED_USERS` matches the Telegram numeric user id.
- Restart the gateway after config changes.
- Check gateway logs under the profile `logs/` directory.

If V3 commands do not receive arguments:

- Run `scripts/hermes-enable-quick-command-args.sh --check`.
- Re-apply the patch and restart gateway.
- Send a command with explicit args, for example `/write_prepare t20260501-130501`.
- Reject malformed task ids and codes instead of trying to interpret them.

If Codex CLI fails:

- Run `codex login`.
- Verify local proxy or network configuration.
- Re-run with a harmless read-only prompt.

## Safe Development Guidance

When changing bridge behavior:

- Keep ordinary Telegram chat out of the queue.
- Add tests or smoke checks for malformed args.
- Keep task storage append-only unless there is a documented migration.
- Log approvals, rejections, starts, completions, and failures.
- Keep write operations on `codex/<task_id>` branches.
- Keep `master` protected through PR workflow.

## Reference Docs

Prefer the repository docs for detailed steps:

- `README.md`
- `docs/deployment.md`
- `docs/telegram-codex.md`
- `docs/v3-explicit-approval.md`
- `docs/security.md`
- `docs/development.md`
