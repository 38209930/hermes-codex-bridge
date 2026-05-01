# Open Source Release Checklist

Use this before pushing a public release.

```bash
bash -n scripts/*.sh
npm ci
npm run openclaw -- --version
scripts/mac-codex-bridge.sh help
scripts/mac-codex-bridge.sh task-list
rg -n --hidden -g '!node_modules/**' -g '!.git/**' -g '!migration/**' -i "(token|secret|password|appSecret|api_key|authorization|bearer|TELEGRAM_BOT_TOKEN|ARK_API_KEY|OPENAI_API_KEY)" .
git status --short --ignored
```

Expected:

- no tracked `node_modules/`
- no tracked `migration/`
- no tracked `.env`
- no real tokens or secrets
- README and docs render cleanly on GitHub

