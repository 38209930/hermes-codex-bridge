# 安全说明

本文默认使用中文记录安全边界、脱敏规则和发布前检查。命令、环境变量和字段名保持原样。

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

- 不把 Telegram 文本直接当 shell 执行
- Codex CLI 计划模式没有写权限
- 不安装依赖
- 不 commit、push、部署或迁移

未来如果加入写文件能力，必须要求明确的 task id 审批，并保留独立审计日志。

## 模板策略

使用这类占位符：

```text
<telegram_bot_token>
<telegram_numeric_user_id>
REPLACE_WITH_FEISHU_APP_ID
REPLACE_WITH_FEISHU_APP_SECRET
```

不要使用看起来像生产凭证的真实示例。
