# Delivery Plan

## Milestones

- M1: 完成飞书应用创建、权限配置、Bot 能力开启
- M2: 完成 OpenClaw Feishu 插件安装与 channel 配置
- M3: 完成 gateway 启动与私聊 pairing 验证
- M4: 完成项目群 @ 机器人消息验证
- M5: 完成文档补齐与 v0.1.0 结项

## Owners

- 飞书应用配置: Product Manager + Backend Engineer
- OpenClaw 接入配置: Backend Engineer
- 验证与回归: Test Engineer
- 群内交互规范: Frontend Engineer
- 进度与风险控制: Project Manager

## Dependencies

- 可登录的飞书开放平台租户管理员权限
- 可用的 App ID / App Secret
- 本机 OpenClaw 与 Node 22 环境

## Risks

- 权限未配置完整导致机器人无法收发消息
- 未发布应用或未审批导致事件无法送达
- groupPolicy 设置不当导致机器人在错误群内响应
- 团队只在群聊决策、不回写文档，导致后续迭代失忆

## Decisions Needed

- 使用 `connectionMode: websocket` 还是 webhook
- 默认 groupPolicy 采用 `open` 还是 `allowlist`
- 首期是否启用 `requireMention: true`
