# PRD

## Background

当前团队希望使用 OpenClaw 作为多项目协作中的智能执行层，并通过飞书作为统一沟通入口。为降低接入成本，第一期先完成飞书机器人接入和基本协作闭环。

## Problem Statement

- 团队尚未完成 OpenClaw 与飞书的正式连通
- 多角色协作需要统一入口和清晰规则
- 后续多个项目并行时，需要先验证单项目隔离协作模式

## Goals

- 完成 OpenClaw 与飞书机器人接入
- 完成私聊 pairing 与群聊消息响应验证
- 建立飞书群协作与项目记忆回写机制

## Users and Scenarios

- 用户在飞书私聊机器人，完成首轮 pairing
- 用户在项目飞书群中 @ 机器人获取协作支持
- 团队成员在飞书群讨论后，将正式结论同步回项目文档

## Scope

- 创建飞书企业应用
- 配置权限、Bot 能力、事件订阅
- 在 OpenClaw 中启用 Feishu channel
- 启动 gateway 并验证消息收发
- 建立项目群协作规则

## Out of Scope

- 自动化发布流水线
- 多环境配置切换平台
- 跨多个 IM 平台统一接入

## Acceptance Criteria

- 飞书应用成功创建并发布
- OpenClaw Feishu 插件安装完成
- `openclaw gateway status` 正常
- 私聊机器人可收到 pairing code 并完成 `openclaw pairing approve feishu <CODE>`
- 飞书群里 @ 机器人可得到响应
- 项目文档完成首轮落库

## Open Questions

- 当前将使用 Feishu 中国区还是 Lark 国际区租户
- 机器人是否需要默认允许所有群，还是只允许指定项目群
- 是否需要在首期就启用发送人 allowlist
