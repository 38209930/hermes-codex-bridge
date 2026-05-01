# Deployment

## Mac: Hermes + Telegram + Codex CLI

Install Codex CLI:

```bash
npm install -g @openai/codex
codex login
codex --version
```

Create or clone a dedicated Hermes profile for the Telegram bridge:

```bash
hermes profile create telegram-codex --clone
```

Configure the profile `.env` with your own values:

```bash
TELEGRAM_BOT_TOKEN=<telegram_bot_token>
TELEGRAM_ALLOWED_USERS=<telegram_numeric_user_id>
TELEGRAM_HOME_CHANNEL=<telegram_numeric_user_id>
TELEGRAM_REQUIRE_MENTION=true
GATEWAY_ALLOW_ALL_USERS=false
TELEGRAM_ALLOW_ALL_USERS=false
```

Set the bridge work directory with an environment variable when the default is not correct:

```bash
MAC_CODEX_BRIDGE_WORKDIR=/path/to/your/repo
```

Start the gateway:

```bash
telegram-codex gateway start
telegram-codex gateway status
```

After changing quick commands:

```bash
telegram-codex gateway restart
```

## macOS launchd Notes

The Telegram task runner uses `launchctl submit` for background Codex planning jobs. To avoid macOS privacy restrictions on user document folders, the runner copies a script snapshot into the Hermes profile task directory before launching.

Runtime files live under:

```text
~/.hermes/profiles/telegram-codex/workspace/tasks/
```

These files are local state and must not be committed.

## Windows: WSL2 + Codex CLI

Run PowerShell as Administrator if WSL2 Ubuntu is not installed:

```powershell
wsl --install -d Ubuntu
```

After reboot and Ubuntu user creation, run:

```powershell
.\scripts\windows-codex-cli-bootstrap.ps1
```

Or run the Ubuntu-side installer directly:

```bash
bash scripts/wsl-install-codex-cli.sh
codex login
```

Recommended project location inside WSL:

```bash
mkdir -p ~/projects
cd ~/projects
git clone <repo-url>
```

Avoid high-frequency development under `/mnt/c/...` because performance and permission behavior can be uneven.

## GitHub Publication

Install GitHub CLI:

```bash
brew install gh
gh auth login
```

Create and push the public repo:

```bash
git add .
git commit -m "Prepare open source release"
gh repo create openclaw-codex-bridge --public --source . --remote origin --push
```

