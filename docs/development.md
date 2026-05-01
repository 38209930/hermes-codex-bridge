# Development

## Requirements

- macOS or Linux for the shell scripts
- Node.js 22
- npm
- OpenClaw
- Codex CLI for Codex bridge workflows
- Hermes Agent for Telegram gateway workflows

Use the included Node version:

```bash
nvm use
npm ci
```

## Script Checks

Run shell syntax checks before committing:

```bash
bash -n scripts/*.sh
```

If PowerShell is available:

```powershell
pwsh -NoProfile -File scripts/windows-codex-cli-bootstrap.ps1 -?
```

## OpenClaw Check

```bash
npm run openclaw -- --version
```

## Project Template Flow

Create a project from the template:

```bash
cp -R projects/_template projects/my-project
```

Each project keeps its own:

- requirements
- delivery plan
- test plan
- change log
- decisions
- known risks
- meeting notes

## Contribution Rules

- Keep credentials out of git.
- Keep generated runtime state out of git.
- Prefer templates over real tenant, app, or user identifiers.
- Keep bridge commands fixed and explicit; do not add raw shell execution from chat text.
- Update the docs when changing script flags, environment variables, or command names.

