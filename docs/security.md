# Security

## Files That Must Not Be Committed

- `.env` and `.env.*`
- Hermes profile directories and state databases
- Telegram bot tokens
- Feishu/Lark App Secret values
- OpenAI, Ark, or other model provider API keys
- task queue runtime state
- logs, PID files, lock files
- `migration/` or other private data dumps
- `node_modules/`

## Pre-Publish Scan

Run:

```bash
rg -n --hidden \
  -g '!node_modules/**' \
  -g '!.git/**' \
  -g '!migration/**' \
  -i "(token|secret|password|appSecret|api_key|authorization|bearer|TELEGRAM_BOT_TOKEN|ARK_API_KEY|OPENAI_API_KEY)" .
```

Expected results should be templates, documentation warnings, or generic field names only.

Check ignored files:

```bash
git status --short --ignored
```

Before publishing, confirm that ignored private paths are not staged:

```bash
git diff --cached --name-only
```

## Runtime Safety

The Telegram bridge is intentionally fixed-command based:

- no raw shell execution from Telegram text
- no write access in Codex CLI planning mode
- no dependency install
- no commit, push, deploy, or migration

Any future write-capable version should require explicit task-id approval and a separate audit trail.

## Template Policy

Use placeholders such as:

```text
<telegram_bot_token>
<telegram_numeric_user_id>
REPLACE_WITH_FEISHU_APP_ID
REPLACE_WITH_FEISHU_APP_SECRET
```

Do not use real examples that look like production credentials.

