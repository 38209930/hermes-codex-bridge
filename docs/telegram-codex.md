# Telegram + Codex 桥接

本文默认使用中文说明 Telegram 与 Codex 的接入方式。需要面向开源或外部协作时，可以提供英文版或英文摘要。命令、环境变量和 Telegram 原始返回保持原样。

## 目标

把 Telegram 作为本地 Codex CLI 计划任务的移动审批和审核入口。桥接设计以安全优先：Telegram 不执行任意 shell 文本，Codex CLI 以只读模式运行。

## 架构

```text
Telegram
  -> Hermes profile: telegram-codex
  -> fixed quick commands
  -> scripts/mac-codex-bridge.sh
  -> Codex CLI read-only planning
  -> task result back to Telegram
```

## Telegram 配置

1. 用 `@BotFather` 创建 bot。
2. 用 `@userinfobot` 获取 Telegram numeric user id。
3. 把 token 和 user id 写入独立 Hermes profile 的 `.env`。

示例：

```bash
TELEGRAM_BOT_TOKEN=<telegram_bot_token>
TELEGRAM_ALLOWED_USERS=<telegram_numeric_user_id>
TELEGRAM_HOME_CHANNEL=<telegram_numeric_user_id>
TELEGRAM_REQUIRE_MENTION=true
```

不要把真实 token 粘贴到共享聊天里，也不要提交到 git。

## Hermes Quick Commands

在 `telegram-codex` profile 中配置固定 quick commands：

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

quick commands 刻意不接收任意任务文本。这样可以避免命令注入，并把所有可执行行为收敛到可审计的本地脚本里。

## 任务队列流程

1. 查看任务输入说明：

   ```text
   /task_new
   ```

2. 把任务 prompt 写入：

   ```text
   ~/.hermes/profiles/telegram-codex/workspace/tasks/inbox.txt
   ```

3. 创建排队任务：

   ```text
   /task_plan
   ```

4. 审批一次只读 Codex 计划运行：

   ```text
   /task_approve
   ```

5. 查看结果：

   ```text
   /task_show
   ```

6. 必要时重试或取消：

   ```text
   /task_retry
   /task_cancel
   ```

## 环境变量

`scripts/mac-codex-bridge.sh` 支持：

```bash
MAC_CODEX_BRIDGE_PROFILE_HOME=~/.hermes/profiles/telegram-codex
MAC_CODEX_BRIDGE_WORKDIR=/path/to/repo
CODEX_BRIDGE_CODEX_BIN=/path/to/codex
CODEX_BRIDGE_TIMEOUT_SECONDS=120
```

如果本机代理监听在 `127.0.0.1:7890`，且相关代理变量尚未设置，脚本会自动为 Codex CLI 导出标准代理变量。

## 安全边界

已审批任务使用以下参数运行 Codex CLI：

```bash
--sandbox read-only
--disable plugins
--disable apps
--disable general_analytics
-c notify=[]
```

prompt 要求 Codex 只输出：

- 计划
- 风险
- 验收标准
- 建议命令

不得修改文件、安装依赖、commit、push、部署或运行迁移。
