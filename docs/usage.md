# 使用说明

本文说明 `hermes-codex-bridge` 这套系统如何使用。中文为主版本，命令、环境变量和第三方字段保持原样。

## 系统定位

`hermes-codex-bridge` 的核心用途是把本机 Codex CLI 接入 Hermes gateway，让你可以在 Telegram 上查看状态、触发只读 review、创建任务、审批任务，并把结果返回到手机端。

当前版本默认只读：

- 不从 Telegram 文本直接执行 shell
- 不让 Codex CLI 写文件
- 不 commit、push、部署或运行迁移
- 审批后的任务只输出计划、风险、验收标准和建议命令

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

如果要进入写文件、commit、push 或部署能力，应另开版本设计，并加入明确 task id 审批、审计日志和回滚策略。
