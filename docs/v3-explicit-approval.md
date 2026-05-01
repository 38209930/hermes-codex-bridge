# V3：Telegram 显式审批写操作

V3 让 Telegram 成为 Codex CLI 远程办公的安全审批入口。它不是普通聊天入口，也不会接管 Codex App 当前窗口。

## 永久安全边界

- 普通 Telegram 消息永远不进入 Codex 队列。
- 只有固定 `/` quick commands 可以触发 bridge。
- 写文件、commit、push 必须分别审批。
- 每个高风险动作都需要明确 `task_id` 和一次性确认码。
- Codex 写文件只允许在 `codex/<task_id>` 分支运行。
- `master` 不允许写入，继续通过 GitHub Pull Request 合并。
- deploy 当前版本禁用，只保留设计入口。

## 前置条件

先完成 V2/V2.5 的只读计划：

```text
/task_new
/task_plan
/task_approve
/task_show
```

任务状态必须到达 `planned` 后，才允许进入 V3 写文件流程。

## 写文件流程

准备写入审批：

```text
/write_prepare t20260501-130501
```

Telegram 会返回：

- 目标分支：`codex/<task_id>`
- 一次性确认码
- 过期时间
- 计划摘要
- 风险提示

批准写入：

```text
/write_approve t20260501-130501 ABC123
```

bridge 会执行：

1. 检查任务状态必须是 `waiting_write_approval`。
2. 校验确认码、阶段和过期时间。
3. 检查当前 repo 没有 tracked dirty changes。
4. 切回 `master`，拉取 `origin/master` 的 fast-forward 更新。
5. 创建 `codex/<task_id>` 分支。
6. 后台运行 Codex CLI `--sandbox workspace-write`。

写入阶段明确禁止：

- commit
- push
- deploy
- 安装依赖
- 数据库迁移
- 输出 token、secret 或 `.env`

拒绝写入：

```text
/write_reject t20260501-130501
```

## Commit 流程

准备 commit 审批：

```text
/commit_prepare t20260501-130501
```

Telegram 会返回：

- 当前任务分支
- `git status --short`
- `git diff --stat`
- 建议 commit message
- 一次性确认码

批准本地 commit：

```text
/commit_approve t20260501-130501 DEF456
```

commit 只发生在 `codex/<task_id>` 分支，不会 push。

## Push 流程

准备 push 审批：

```text
/push_prepare t20260501-130501
```

批准 push：

```text
/push_approve t20260501-130501 GHI789
```

push 只会推送 `codex/<task_id>` 到 `origin`。之后应在 GitHub 上创建 Pull Request，并按主干保护规则审核合并。

## Deploy

deploy 当前版本禁用：

```text
/deploy_prepare t20260501-130501
```

该命令只返回禁用说明和未来设计文档，不会执行部署。

## 本地参数补丁

Hermes 原生 `exec` quick command 默认不把 slash 参数传给脚本。本仓库提供幂等补丁：

```bash
scripts/hermes-enable-quick-command-args.sh --check
scripts/hermes-enable-quick-command-args.sh
scripts/hermes-enable-quick-command-args.sh --check
```

补丁只新增环境变量：

```text
HERMES_QUICK_COMMAND_NAME
HERMES_QUICK_COMMAND_ARGS
HERMES_QUICK_COMMAND_RAW
```

参数不会拼接到 shell command。bridge 只接受白名单格式：

```text
task_id: tYYYYMMDD-HHMMSS
code:    6 位大写字母或数字
```

## 状态流

```text
draft
-> waiting_approval
-> approved
-> running
-> planned
-> waiting_write_approval
-> writing
-> written
-> waiting_commit_approval
-> committing
-> committed
-> waiting_push_approval
-> pushing
-> pushed
```

失败或人工拒绝会进入：

```text
failed
rejected
canceled
stale
```
