# 使用说明

本文说明 `hermes-codex-bridge` 这套系统如何使用。中文为主版本，命令、环境变量和第三方字段保持原样。

## 系统定位

`hermes-codex-bridge` 的核心用途是把本机 Codex CLI 接入 Hermes gateway，让你可以在 Telegram 上查看状态、触发只读 review、创建任务、审批任务，并把结果返回到手机端。

默认安全入口仍然是只读计划：

- Telegram 普通聊天永远不进入 Codex 任务队列
- 不从 Telegram 文本直接执行 shell
- `/task_approve` 只让 Codex CLI 输出计划、风险、验收标准和建议命令

V3 新增写文件、commit、push 的显式审批流程，但必须先有只读计划，并且每一步都要单独确认。deploy 仍然禁用。

## 启动前提

Telegram `/` 命令能够工作，是因为 Hermes `telegram-codex` gateway 已经启动并加载了 quick commands。使用前先检查 bridge 状态：

```bash
hermes --profile telegram-codex gateway status
```

启动或重启：

```bash
hermes --profile telegram-codex gateway start
hermes --profile telegram-codex gateway restart
```

在 macOS 上，Hermes gateway 使用 launchd service 运行。只要该服务处于 loaded 状态，bridge 就会随 Hermes gateway 启动方式恢复；修改 quick commands、脚本路径或 `.env` 后，应执行 `gateway restart`。

## 常用 Telegram 命令

```text
/codex_help
/codex_status
/diff
/codex_review
/codex_resume_last
/task_new
/task_plan
/task_list
/task_show
/task_approve
/task_retry
/task_cancel
/task_reject
/write_prepare <task_id>
/write_approve <task_id> <code>
/write_reject <task_id>
/commit_prepare <task_id>
/commit_approve <task_id> <code>
/push_prepare <task_id>
/push_approve <task_id> <code>
/deploy_prepare <task_id>
```

## 典型任务流程

1. 在 Telegram 发送：

   ```text
   /task_new
   ```

2. 在本机把任务内容写入：

   ```text
   ~/.hermes/profiles/telegram-codex/workspace/tasks/inbox.txt
   ```

3. 在 Telegram 发送：

   ```text
   /task_plan
   ```

4. 查看待审批任务：

   ```text
   /task_show
   ```

5. 批准只读 Codex 计划任务：

   ```text
   /task_approve
   ```

6. 再次查看结果：

   ```text
   /task_show
   ```

## V3 显式写入流程

只读计划完成后，任务状态会变成 `planned`。这时可以进入写文件审批：

```text
/write_prepare t20260501-130501
/write_approve t20260501-130501 ABC123
```

写入只会发生在自动创建的任务分支：

```text
codex/t20260501-130501
```

写入完成后，如果需要提交：

```text
/commit_prepare t20260501-130501
/commit_approve t20260501-130501 DEF456
```

如果需要推送任务分支：

```text
/push_prepare t20260501-130501
/push_approve t20260501-130501 GHI789
```

push 之后仍然需要通过 GitHub Pull Request 合并到 `master`。bridge 不会直接合并主干。

deploy 当前版本不开放：

```text
/deploy_prepare t20260501-130501
```

## 本机命令

在项目目录中运行：

```bash
cd "/Volumes/SSD/myot/AI-WORK/hermes-codex-bridge"
scripts/mac-codex-bridge.sh help
scripts/mac-codex-bridge.sh task-list
scripts/mac-codex-bridge.sh status
```

## 何时使用 Codex App，何时使用 Telegram

- Codex App：适合本机开发、代码修改、长任务执行和详细审核。
- Telegram：适合移动端查看状态、审批只读计划、查看任务队列和做轻量验收。
- Codex CLI：作为 Hermes/TG 桥接的执行入口，不接管 Codex App 当前窗口。

## 安全边界

普通 Telegram 聊天不会进入队列，这是一条长期安全规则，不是临时限制。任何 Codex CLI 调用都必须来自固定 quick command 或本地显式命令。

写文件、commit、push 已在 V3 中拆分成三个审批阶段；每个阶段都有独立一次性确认码和审计日志。部署能力必须另行设计，不能复用当前确认码或普通聊天入口。
