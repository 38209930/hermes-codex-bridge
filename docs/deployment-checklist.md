# 开源发布检查清单

推送 public release 之前使用这份清单。

```bash
bash -n scripts/*.sh
npm ci
npm run openclaw -- --version
scripts/mac-codex-bridge.sh help
scripts/mac-codex-bridge.sh task-list
rg -n --hidden -g '!node_modules/**' -g '!.git/**' -g '!migration/**' -i "(token|secret|password|appSecret|api_key|authorization|bearer|TELEGRAM_BOT_TOKEN|ARK_API_KEY|OPENAI_API_KEY)" .
git status --short --ignored
```

预期结果：

- 没有 tracked `node_modules/`
- 没有 tracked `migration/`
- 没有 tracked `.env`
- 没有真实 token 或 secret
- README 和 docs 在 GitHub 上能正常渲染
