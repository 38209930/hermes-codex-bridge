# 未来写操作能力设计原则

当前版本不提供写文件、commit、push、deploy 或迁移能力。任何类似能力都必须另行设计，不得直接复用普通 Telegram 聊天入口。

## 不允许的做法

- 不允许普通 Telegram 消息自动进入 Codex 队列。
- 不允许 Telegram 文本直接作为 shell 命令执行。
- 不允许 `/approve` 这类模糊命令批准最近任意写操作。
- 不允许跳过计划、风险和审计直接修改文件。

## 最低安全门槛

未来如需加入写操作，必须至少具备：

- 明确 task id，例如 `/approve_write t20260501-123456`
- 操作前展示计划、影响文件、风险和回滚方式
- 审批人与审批时间进入审计日志
- 写操作与只读计划使用不同命令
- commit、push、deploy 分别审批，不合并成一个总开关
- 默认拒绝未知目录、未知 repo 和未受信任务

## 推荐状态流

```text
draft
-> waiting_plan_approval
-> planned
-> waiting_write_approval
-> writing
-> waiting_commit_approval
-> committed
-> waiting_push_approval
-> pushed
```

deploy 应作为独立能力设计，不应默认跟随 push。
