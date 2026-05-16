# 运行维护原则

本文记录 Hermes、Telegram、飞书/Lark 与 Codex bridge 的运行维护硬规则。目标是避免一次局部改动影响已有机器人、已有 gateway 或普通聊天体验。

## 核心原则

- Hermes 本体源码补丁必须最小化，只修改完成目标所需的最小代码块。
- 所有 Hermes 本体补丁必须通过脚本管理，脚本必须支持 `--check` 和 `--restore`。
- 补丁不得改变普通聊天语义。Telegram 和飞书普通聊天不进入 Codex 队列，这是长期安全边界。
- quick command 参数只能通过环境变量传递，不得拼接进 shell command。
- 任意写文件、commit、push、deploy 能力必须另行设计，并要求显式审批。
- deploy 默认禁用；开放 deploy 前必须有独立设计、环境白名单、回滚方案和审批记录。
- 修改 Hermes、profile `.env`、quick commands、代理或 Codex CLI 路径后，必须重启所有受影响 gateway。
- 不只检查进程是否存在；必须验证平台 API、gateway 日志、quick commands 和 bridge 实际输出。

## 补丁纪律

修改 Hermes 本体前，必须先确认是否可以只改本仓库脚本、profile 配置或文档。确实需要 patch Hermes 时，必须满足：

- 先备份原文件。
- patch 脚本幂等，多次执行不会重复插入代码。
- patch 脚本提供 `--check` 检查当前状态。
- patch 脚本提供 `--restore` 回滚最近备份。
- patch 不引入函数级别的隐式作用域风险，例如在已使用全局模块的函数内部再 `import os`。
- patch 后运行 Python 编译检查。

当前 quick command 参数补丁使用：

```bash
scripts/hermes-enable-quick-command-args.sh --check
scripts/hermes-enable-quick-command-args.sh
scripts/hermes-enable-quick-command-args.sh --check
python -m py_compile ~/.hermes/hermes-agent/gateway/run.py
```

## 重启纪律

Hermes gateway 是 launchd 常驻进程。文件或配置改完后，正在运行的 gateway 不会自动加载新代码。

涉及 Telegram bridge 时：

```bash
hermes --profile telegram-codex gateway restart
hermes --profile telegram-codex gateway status
```

涉及飞书机器人时，必须逐个重启相关 profile：

```bash
for p in feishu-bot1 feishu-bot2 feishu-bot3 feishu-bot4; do
  hermes --profile "$p" gateway restart
  hermes --profile "$p" gateway status
done
```

涉及默认 gateway 时：

```bash
hermes gateway restart
hermes gateway status
```

## 验证纪律

每次修复后至少验证以下项目：

- `gateway status` 显示 service loaded 且有 PID。
- fresh `gateway.error.log` 没有新的 traceback。
- Telegram 或 Feishu 平台 API 凭证有效。
- 相关 websocket 或 bot API 已连接。
- quick commands 能加载。
- bridge `status` 使用正确的 Codex CLI 路径。
- 普通聊天不会写入任务队列。
- `FEISHU_HOME_CHANNEL`、`TELEGRAM_HOME_CHANNEL` 等 home channel 已配置，避免提示污染正常回复。

不要只看旧日志。排查时应轮转旧日志或明确使用 fresh log，避免把历史错误误判为当前故障。

## 代理纪律

本机代理端口可能变化。当前环境中曾出现旧端口 `127.0.0.1:7890` 失效，而可用端口为 `127.0.0.1:4780/4781` 的情况。

修改或排查网络时，必须同时检查：

```bash
nc -z 127.0.0.1 4780
nc -z 127.0.0.1 4781
nc -z 127.0.0.1 7890
git config --show-origin --list | rg -i 'proxy|github'
```

profile `.env`、launchd 环境和 GitHub proxy 配置应保持一致，避免 Telegram、飞书、GitHub 三者状态不一致。

## Home Channel 纪律

飞书和 Telegram 正常聊天不等于 home channel 已配置。home channel 缺失会导致 Hermes 在正常回复前插入提示。

Feishu profile 应配置：

```text
FEISHU_HOME_CHANNEL=<open_chat_id>
FEISHU_HOME_CHANNEL_NAME=Home
```

Telegram profile 应配置：

```text
TELEGRAM_HOME_CHANNEL=<telegram_numeric_user_id_or_chat_id>
TELEGRAM_HOME_CHANNEL_NAME=Home
```

如果重建 profile、迁移目录或更换 bot，必须重新确认 home channel。

## 安全边界

长期不可破坏的边界：

- 普通聊天永远不入 Codex 队列。
- 远程触发 Codex 只能来自固定 quick command。
- 任务创建、计划、写文件、commit、push 必须分阶段。
- 写文件必须在任务分支。
- commit 和 push 必须独立审批。
- deploy 禁用，直到另行设计。
- 主干保护不得因自动化便利被永久关闭。

这些规则优先级高于功能便利性。
