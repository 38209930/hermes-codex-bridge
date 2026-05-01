# Test Plan

## Test Scope

- 飞书机器人基础连通
- 私聊 pairing 流程
- 项目群 @ 机器人响应
- 文档回写流程检查

## Entry Criteria

- 飞书应用已创建
- App ID / App Secret 已配置
- OpenClaw Feishu 插件已安装
- gateway 已启动

## Exit Criteria

- 私聊消息可达
- pairing 可完成
- 群聊消息可达
- 日志中可定位 chat_id / open_id
- 项目文档完成回写

## Functional Cases

- 私聊机器人，收到 pairing code
- 执行 `openclaw pairing list feishu`
- 执行 `openclaw pairing approve feishu <CODE>`
- 在飞书群中 @ 机器人并收到响应
- 发送 `/status` 并观察反馈

## Regression Scope

- 重新启动 gateway 后仍可收消息
- 已配对用户可继续会话
- 群策略调整后不影响目标项目群正常响应

## Evidence

- 待补充：飞书消息截图
- 待补充：gateway 日志片段
- 待补充：pairing 执行记录
