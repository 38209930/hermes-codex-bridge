# 部署说明

本文默认使用中文记录部署步骤。需要面向开源或外部协作时，可以提供英文版或英文摘要。命令、环境变量和第三方字段保持原样。

## Mac：Hermes + Telegram + Codex CLI

安装 Codex CLI：

```bash
npm install -g @openai/codex
codex login
codex --version
```

为 Telegram 桥接创建或克隆一个独立 Hermes profile：

```bash
hermes profile create telegram-codex --clone
```

在 profile 的 `.env` 中写入自己的配置：

```bash
TELEGRAM_BOT_TOKEN=<telegram_bot_token>
TELEGRAM_ALLOWED_USERS=<telegram_numeric_user_id>
TELEGRAM_HOME_CHANNEL=<telegram_numeric_user_id>
TELEGRAM_REQUIRE_MENTION=true
GATEWAY_ALLOW_ALL_USERS=false
TELEGRAM_ALLOW_ALL_USERS=false
```

如果默认工作目录不正确，用环境变量指定桥接工作目录：

```bash
MAC_CODEX_BRIDGE_WORKDIR=/path/to/your/repo
```

启动 gateway：

```bash
telegram-codex gateway start
telegram-codex gateway status
```

修改 quick commands 后重启：

```bash
telegram-codex gateway restart
```

## macOS launchd 注意事项

Telegram 任务 runner 使用 `launchctl submit` 启动后台 Codex 计划任务。为了避开 macOS 对用户文档目录的隐私限制，runner 会先把脚本快照复制到 Hermes profile 的任务目录，再启动后台任务。

运行态文件位于：

```text
~/.hermes/profiles/telegram-codex/workspace/tasks/
```

这些文件属于本机状态，不能提交到 git。

## Windows：WSL2 + Codex CLI

如果尚未安装 WSL2 Ubuntu，请用管理员模式运行 PowerShell：

```powershell
wsl --install -d Ubuntu
```

重启并创建 Ubuntu 用户后，运行：

```powershell
.\scripts\windows-codex-cli-bootstrap.ps1
```

也可以直接运行 Ubuntu 侧安装脚本：

```bash
bash scripts/wsl-install-codex-cli.sh
codex login
```

推荐把项目放在 WSL 内部文件系统：

```bash
mkdir -p ~/projects
cd ~/projects
git clone <repo-url>
```

不建议把高频开发项目放在 `/mnt/c/...` 下，因为性能和权限行为可能不稳定。

## GitHub 发布

安装 GitHub CLI：

```bash
brew install gh
gh auth login
```

创建并推送 public repo：

```bash
git add .
git commit -m "Prepare open source release"
gh repo create hermes-codex-bridge --public --source . --remote origin --push
```

## 本机推荐目录

Mac 侧推荐把仓库放在 SSD 工作目录：

```bash
cd "/Volumes/SSD/myot/AI-WORK/hermes-codex-bridge"
```

如果需要兼容旧 Codex App 会话，可以保留旧路径 symlink：

```bash
/Users/chaofengsong/Documents/New project -> /Volumes/SSD/myot/AI-WORK/hermes-codex-bridge
```

Hermes `telegram-codex` profile 中的 `terminal.cwd`、quick commands 和 `.env` 里的 `MAC_CODEX_BRIDGE_WORKDIR` 都应指向这个 SSD 目录。
