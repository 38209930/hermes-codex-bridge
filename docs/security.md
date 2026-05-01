# 安全说明

本文默认使用中文记录安全边界、脱敏规则和发布前检查。需要面向开源或外部协作时，可以提供英文版或英文摘要。命令、环境变量和字段名保持原样。

## 不能提交的文件

- `.env` 和 `.env.*`
- Hermes profile 目录和状态数据库
- Telegram bot token
- 飞书/Lark App Secret
- OpenAI、Ark 或其他模型服务商 API key
- 任务队列运行状态
- 日志、PID 文件、lock 文件
- `migration/` 或其他私有数据导出
- `node_modules/`

## 发布前扫描

运行：

```bash
rg -n --hidden \
  -g '!node_modules/**' \
  -g '!.git/**' \
  -g '!migration/**' \
  -i "(token|secret|password|appSecret|api_key|authorization|bearer|TELEGRAM_BOT_TOKEN|ARK_API_KEY|OPENAI_API_KEY)" .
```

预期结果只能是模板占位符、文档警告或通用字段名。

检查 ignored 文件：

```bash
git status --short --ignored
```

发布前确认 ignored 私有路径没有进入暂存区：

```bash
git diff --cached --name-only
```

## 运行时安全

Telegram 桥接刻意采用固定命令模式：

- Telegram 普通聊天永远不自动进入 Codex 任务队列
- 不把 Telegram 文本直接当 shell 执行
- 任何 Codex CLI 调用必须由固定 quick command、本机脚本或明确审批动作触发
- Codex CLI 计划模式没有写权限
- 写文件、commit、push 拆分成不同审批阶段
- 每个写操作阶段都要求明确 `task_id` 和一次性确认码
- 写文件只允许在 `codex/<task_id>` 分支执行
- 不安装依赖
- deploy 和迁移仍然禁用

这条“普通聊天不入队”是长期安全边界，后续版本不得加入普通消息自动入队功能。

V3 已加入写文件、commit、push 的最低审批门槛，必须满足：

- 明确的 task id
- 显式审批命令
- 操作前计划与风险展示
- 操作后审计日志
- 每个阶段使用不同确认码
- 不在 `master` 写入
- 不自动合并 Pull Request

未来如要加入 deploy，必须另行设计，至少包含：

- 环境白名单
- 变更窗口
- 回滚命令
- 审批人与审批时间
- 禁止从普通 Telegram 消息触发

## 模板策略

使用这类占位符：

```text
<telegram_bot_token>
<telegram_numeric_user_id>
REPLACE_WITH_FEISHU_APP_ID
REPLACE_WITH_FEISHU_APP_SECRET
```

不要使用看起来像生产凭证的真实示例。
