# 项目传播计划

本文用于帮助更多人理解、试用和贡献 `hermes-codex-bridge`。中文为主，面向国际社区时可以把核心文案翻译成英文。

## 一句话定位

中文：

> hermes-codex-bridge：用 Telegram 安全审批 Codex CLI 任务，支持只读计划、显式确认写文件、commit、push，普通聊天永不入队。

英文：

> hermes-codex-bridge lets you approve Codex CLI tasks from Telegram with read-only planning, explicit write/commit/push approvals, and a hard rule that normal chat never enters the task queue.

## 核心卖点

- 安全优先：普通 Telegram 消息永远不进入 Codex 队列。
- 固定命令入口：只通过 `/task_*`、`/write_*`、`/commit_*`、`/push_*` 触发。
- 先计划再写入：写文件前必须已有只读计划。
- 一次性确认码：write、commit、push 分别确认。
- 分支隔离：Codex 写文件只发生在 `codex/<task_id>` 分支。
- 主干保护：不直接写 `master`，通过 GitHub Pull Request 合并。
- deploy 禁用：当前版本不执行部署，只保留未来设计入口。
- 可自托管：Hermes profile、Telegram bot token、任务状态和日志都在本机。

## 目标用户

- Codex CLI 用户，希望在手机上查看、审核和批准任务。
- 使用 Hermes gateway 的开发者。
- 正在把 AI agent 接入 Telegram、飞书或团队协作工具的人。
- 关心 agent 安全边界、审批链路和主干保护的工程团队。
- 想学习“远程 agent 审批层”实现方式的开源用户。

## 推荐 GitHub 设置

仓库 description：

```text
Approve Codex CLI tasks from Telegram with read-only planning, explicit write/commit/push approvals, and safe task branches.
```

推荐 topics：

```text
codex-cli
telegram-bot
hermes
ai-agent
developer-tools
approval-workflow
agent-safety
remote-work
github-pr
automation
```

建议开启：

- GitHub Discussions：用于答疑和收集使用场景。
- Issues templates：区分 bug、feature request、deployment help。
- 第一个 release：`v0.1.0`，说明当前能力和安全边界。

## Codex Plugin 分发

本项目已经提供 repo-local Codex Plugin：

```text
plugins/hermes-codex-bridge/
```

GitHub 安装命令：

```bash
codex plugin marketplace add 38209930/hermes-codex-bridge --ref master
```

传播时可以这样说：

```text
你可以把 hermes-codex-bridge 作为 Codex Plugin 安装。安装后，Codex 会自动知道如何部署 Hermes + Telegram bridge、验证 V3 显式审批、排查 quick command 参数和保护“普通聊天永不入队”的安全边界。
```

## 发布顺序

1. GitHub 仓库首页
   - README 顶部定位清楚。
   - topics 配齐。
   - release 发布。
   - Discussions 开启。

2. 中文开发者社区
   - V2EX：适合发“我做了一个...”的工程分享。
   - 掘金：适合写部署教程和技术细节。
   - 知乎：适合写“为什么 AI agent 需要审批层”。
   - Telegram / 飞书 / AI agent 社群：适合直接找早期用户。

3. 国际社区
   - X / Twitter：短 demo、截图、线程。
   - Hacker News：`Show HN: Approve Codex CLI tasks from Telegram safely`
   - Product Hunt：等 demo GIF、安装文档和常见问题稳定后再发布。

## 中文发布文案

短版：

```text
我开源了 hermes-codex-bridge：一个 Telegram + Hermes + Codex CLI 的安全审批桥。

它不是远程 shell。普通 Telegram 聊天永远不会进入 Codex 队列。

核心流程是：
1. /task_approve 先让 Codex CLI 输出只读计划
2. /write_prepare 生成一次性确认码
3. /write_approve 才允许在 codex/<task_id> 分支写文件
4. commit 和 push 继续单独审批
5. master 仍然走 GitHub PR

适合想在手机上审核 Codex 任务，又不想把 bot 做成危险远程入口的人。

GitHub: https://github.com/38209930/hermes-codex-bridge
```

长版标题建议：

```text
我为什么给 Codex CLI 做了一个 Telegram 显式审批层
```

长文结构：

1. 背景：Codex CLI 很适合本机自动化，但移动端审核不方便。
2. 风险：Telegram bot 如果设计不好，很容易变成远程 shell。
3. 原则：普通聊天永不入队，所有高风险动作都要固定命令和确认码。
4. 架构：Telegram -> Hermes gateway -> quick commands -> bridge -> Codex CLI。
5. V2.5：只读任务队列、后台 runner、结果文件和审计日志。
6. V3：write、commit、push 分阶段审批。
7. 安全边界：任务分支、主干保护、deploy 禁用。
8. 使用方式：快速部署和常用命令。
9. 后续计划：demo、更多平台接入、PR 保护体验、团队协作。

## 英文发布文案

Short version:

```text
I open-sourced hermes-codex-bridge, a Telegram + Hermes + Codex CLI approval bridge.

It is not a remote shell. Normal Telegram chat never enters the Codex task queue.

Workflow:
1. /task_approve asks Codex CLI for a read-only plan
2. /write_prepare creates a one-time approval code
3. /write_approve writes only on codex/<task_id>
4. commit and push require separate approvals
5. master still goes through GitHub PRs

GitHub: https://github.com/38209930/hermes-codex-bridge
```

Hacker News 标题：

```text
Show HN: Approve Codex CLI tasks from Telegram safely
```

Product Hunt tagline：

```text
Safe Telegram approvals for Codex CLI tasks
```

## Demo 脚本

短视频或 GIF 可以按这个顺序录：

```text
1. Telegram 发送 /codex_status
2. 本机写入 inbox.txt
3. Telegram 发送 /task_plan
4. Telegram 发送 /task_approve
5. Telegram 发送 /task_show 查看只读计划
6. Telegram 发送 /write_prepare <task_id>
7. 展示一次性确认码和 codex/<task_id> 分支
8. 不实际 deploy，展示 /deploy_prepare <task_id> 返回禁用说明
```

录屏重点：

- 展示“普通聊天不入队”的规则。
- 展示 task id 和确认码。
- 展示写入只发生在任务分支。
- 展示 GitHub PR 而不是直接合并主干。

## 早期用户反馈问题

可以主动问：

- 你现在如何远程查看 Codex CLI 或其他 agent 的任务？
- 你最担心 Telegram bot 控制开发环境的哪类风险？
- 只读计划、写文件、commit、push 分开审批是否符合你的工作流？
- 你希望支持 Slack、飞书、Discord，还是继续专注 Telegram？
- 你是否需要团队模式，例如多人 approve 或 code owner approve？

## 传播节奏

第一周：

- 完成 README、release、topics、Discussions。
- 发中文短文到社群和朋友圈。
- 找 3-5 个真实开发者试用。

第二周：

- 根据反馈补 FAQ。
- 录 60 秒 demo。
- 发 V2EX / 掘金技术文章。

第三周：

- 整理英文 README 摘要。
- 发 X / Hacker News。
- 如果安装体验稳定，再准备 Product Hunt。

## 不要这样宣传

- 不要说“Telegram 远程控制 Codex”，这会误导成远程 shell。
- 不要弱化普通聊天不入队这条边界。
- 不要承诺 deploy 能力，当前版本明确禁用。
- 不要宣传能接管 Codex App 当前窗口。
- 不要鼓励绕过 GitHub PR 和主干保护。

## 下一步可做

- 增加 README demo GIF。
- 增加 `docs/faq.md`。
- 增加 issue templates。
- 增加 release note 模板。
- 增加英文摘要或 `docs/en/`。
