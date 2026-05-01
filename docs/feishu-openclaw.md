# 飞书/Lark + OpenClaw

本文默认使用中文说明飞书/Lark 与 OpenClaw 的接入方式。需要面向开源或外部协作时，可以提供英文版或英文摘要。`App ID`、`App Secret`、事件名和配置字段保持原样。

## 目标

把飞书或 Lark 作为 OpenClaw 项目工作的协作入口。本仓库只提供模板和约定，不包含真实租户密钥。

## 创建应用

1. 打开飞书/Lark 开发者后台。
2. 为项目创建应用。
3. 启用 bot 能力。
4. 只把 `App ID` 和 `App Secret` 写入私有运行配置。
5. 按 OpenClaw 部署方式配置事件订阅或 websocket 模式。

## 配置模板

从这个模板开始：

```text
projects/feishu-openclaw-integration/config/openclaw.feishu.template.json5
```

在本地替换占位符：

```json5
appId: "REPLACE_WITH_FEISHU_APP_ID",
appSecret: "REPLACE_WITH_FEISHU_APP_SECRET"
```

中国区租户使用 `domain: "feishu"`，国际区租户使用 `domain: "lark"`。

## 配对流程

1. 启动或重启 OpenClaw gateway。
2. 私聊 bot。
3. 批准 pairing code：

   ```bash
   openclaw pairing list feishu
   openclaw pairing approve feishu <CODE>
   ```

4. 把 bot 加入项目群。
5. 在群里 mention bot，确认它可以回复。
6. 如果需要群白名单，把得到的 group chat id 记录到私有配置。

## 群协作规则

- 每个项目使用一个飞书群。
- 置顶项目目标、当前范围、项目目录、发布状态和需求变更流程。
- 把聊天里的决策同步到项目 memory 文件。
- 首次上线阶段保持 `requireMention` 开启。

## 密钥

不要提交：

- 绑定私有租户的 App ID
- App Secret
- verification token
- encrypt key
- 私有群 chat ID
- 导出的消息日志
