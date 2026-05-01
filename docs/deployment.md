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

也可以使用 Hermes 原生命令检查和管理 bridge：

```bash
hermes --profile telegram-codex gateway status
hermes --profile telegram-codex gateway start
hermes --profile telegram-codex gateway restart
```

部署验收标准：

- `gateway status` 显示 launchd service 已 loaded
- launchd plist 已设置 `RunAtLoad=true`
- `launchctl print gui/$(id -u)/ai.hermes.gateway-telegram-codex` 显示 service 正在 running
- quick commands 能加载 `/codex_status`、`/task_list`、`/task_approve` 和 V3 审批命令
- Telegram 普通聊天不会自动进入 Codex 任务队列
- Codex CLI 调用只能通过固定 quick command 或本机显式命令触发

## Hermes quick command 参数补丁

V3 的 `/write_prepare <task_id>`、`/write_approve <task_id> <code>` 等命令需要 Hermes 把 slash command 参数传给 bridge。当前本地补丁只通过环境变量传递参数，不把参数拼进 shell command：

```bash
cd "/Volumes/SSD/myot/AI-WORK/hermes-codex-bridge"
scripts/hermes-enable-quick-command-args.sh --check
scripts/hermes-enable-quick-command-args.sh
scripts/hermes-enable-quick-command-args.sh --check
hermes --profile telegram-codex gateway restart
```

可回滚：

```bash
scripts/hermes-enable-quick-command-args.sh --restore
hermes --profile telegram-codex gateway restart
```

补丁提供的环境变量：

```text
HERMES_QUICK_COMMAND_NAME
HERMES_QUICK_COMMAND_ARGS
HERMES_QUICK_COMMAND_RAW
```

bridge 只接受白名单格式的 `task_id` 和一次性确认码，特殊字符会被拒绝。

## macOS launchd 注意事项

Telegram 任务 runner 使用 `launchctl submit` 启动后台 Codex 计划任务。为了避开 macOS 对用户文档目录的隐私限制，runner 会先把脚本快照复制到 Hermes profile 的任务目录，再启动后台任务。

Hermes gateway 本身也通过 launchd service 管理。bridge 不需要单独常驻进程；只要 `telegram-codex` gateway loaded，Telegram quick commands 就会调用本仓库脚本。V3 写入 runner 也由 bridge 在审批后通过 launchd 临时启动。

### 开机自启动

Telegram 审批链路必须依赖 Hermes gateway 自启动，否则手机端 `/` 命令不会有 bridge 响应。Mac 侧应使用 Hermes gateway 的 launchd LaunchAgent：

```bash
hermes --profile telegram-codex gateway start
hermes --profile telegram-codex gateway status
```

检查 launchd：

```bash
plutil -p ~/Library/LaunchAgents/ai.hermes.gateway-telegram-codex.plist
launchctl print gui/$(id -u)/ai.hermes.gateway-telegram-codex
```

期望看到：

```text
RunAtLoad => true
state = running
```

如果服务未加载，重新启动 gateway：

```bash
hermes --profile telegram-codex gateway restart
```

注意：LaunchAgent 在当前 macOS 用户登录后自启动；机器重启但用户尚未登录时，用户级 Telegram gateway 通常不会运行。若需要无人值守开机即运行，需要另行设计系统级 LaunchDaemon，并单独处理密钥、用户环境、网络和文件权限。

运行态文件位于：

```text
~/.hermes/profiles/telegram-codex/workspace/tasks/
```

这些文件属于本机状态，不能提交到 git。

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
