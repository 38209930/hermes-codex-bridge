# openclaw-codex-bridge

Open-source workspace templates and bridge scripts for running an OpenClaw/Hermes/Codex workflow across local development, Telegram review, and Feishu/Lark collaboration.

This repository is intentionally conservative: the Telegram/Codex bridge is read-only by default, Feishu credentials are represented as templates, and local runtime state is excluded from git.

## What Is Included

- OpenClaw multi-project workspace templates under `projects/`
- role and operating playbooks under `playbooks/`
- a Mac Hermes + Codex CLI Telegram bridge under `scripts/mac-codex-bridge.sh`
- Windows WSL2 Codex CLI bootstrap scripts under `scripts/`
- Feishu/OpenClaw configuration templates
- generic API framework hardening playbooks

## Quick Start

Use Node.js 22:

```bash
nvm use
npm ci
npm run openclaw -- --version
```

Create a project from the template:

```bash
cp -R projects/_template projects/my-project
```

Install and verify Codex CLI:

```bash
npm install -g @openai/codex
codex login
codex --version
```

## Documentation

- [Development](docs/development.md)
- [Deployment](docs/deployment.md)
- [Telegram + Codex Bridge](docs/telegram-codex.md)
- [Feishu/Lark + OpenClaw](docs/feishu-openclaw.md)
- [Security](docs/security.md)

## Directory Map

```text
projects/       Reusable project templates and sample project memory layout
playbooks/      Collaboration, role, Feishu, Codex, Hermes, and API playbooks
scripts/        Local helper scripts for Hermes, Codex CLI, Telegram, and WSL
docs/           User-facing setup, deployment, and security documentation
```

## Safety Model

The Telegram/Codex bridge does not execute arbitrary Telegram text as shell commands. Task prompts are queued through a local inbox file and approved through fixed Hermes quick commands. Approved tasks run Codex CLI with `--sandbox read-only` and are prompted to output only plans, risks, acceptance criteria, and suggested commands.

Write operations, dependency installation, commits, pushes, migrations, and deployments are intentionally out of scope for the current bridge.

## Telegram/Codex Bridge

The Mac bridge expects a dedicated Hermes profile, usually named `telegram-codex`.

Common commands:

```text
/codex_help
/codex_status
/diff
/codex_review
/task_new
/task_plan
/task_list
/task_show
/task_approve
/task_retry
/task_cancel
/task_reject
```

See [Telegram + Codex Bridge](docs/telegram-codex.md) for the full setup.

## Feishu/Lark

The Feishu integration is documented as an OpenClaw channel setup. Real `App ID`, `App Secret`, chat IDs, and tenant details must stay outside git.

See [Feishu/Lark + OpenClaw](docs/feishu-openclaw.md).

## Windows Codex CLI

Windows support is designed around WSL2 Ubuntu. The helper scripts install Node.js 22 through `nvm`, then install Codex CLI with:

```bash
npm install -g @openai/codex
```

See [Deployment](docs/deployment.md).

## Open Source Hygiene

Do not commit:

- `migration/`
- `node_modules/`
- `.env` or profile `.env` files
- Telegram bot tokens
- Feishu/Lark app secrets
- Hermes state databases
- task queue state, logs, PID files, or lock files

Run the security scan in [Security](docs/security.md) before publishing.

