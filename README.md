# openclaw-codex-bridge

这是一个开源工作台模板与桥接脚本集合，用于把 OpenClaw、Hermes、Codex、本地开发、Telegram 审核和飞书/Lark 协作串成一套可复用流程。

本仓库默认走保守路线：Telegram/Codex 桥接只读执行，飞书凭证只提供模板，本机运行状态不进入 git。

## 语言约定

- 默认使用中文编写对话、计划、执行说明、验收说明、README、使用文档、部署文档和项目管理文档。
- 代码保留字、包名、命令、API 字段、协议字段、错误原文保持原语言，避免破坏工程语义。
- 变量名、函数名、类名、文件名沿用项目既有风格，不强行中文化。
- 注释默认中文，但只在确实有助于理解时添加。

## 包含内容

- `projects/`：OpenClaw 多项目工作区模板
- `playbooks/`：角色、协作、Codex、Hermes、飞书和 API 改造手册
- `scripts/mac-codex-bridge.sh`：Mac Hermes + Codex CLI 的 Telegram 桥接脚本
- `scripts/`：Windows WSL2 Codex CLI 启动脚本
- 飞书/OpenClaw 配置模板
- 通用 API 框架加固与改造手册

## 快速开始

使用 Node.js 22：

```bash
nvm use
npm ci
npm run openclaw -- --version
```

从模板创建项目：

```bash
cp -R projects/_template projects/my-project
```

安装并验证 Codex CLI：

```bash
npm install -g @openai/codex
codex login
codex --version
```

## 文档

- [开发说明](docs/development.md)
- [部署说明](docs/deployment.md)
- [Telegram + Codex 桥接](docs/telegram-codex.md)
- [飞书/Lark + OpenClaw](docs/feishu-openclaw.md)
- [安全说明](docs/security.md)

## 目录结构

```text
projects/       可复用项目模板与项目记忆结构
playbooks/      协作、角色、飞书、Codex、Hermes 和 API 手册
scripts/        Hermes、Codex CLI、Telegram 和 WSL 本地辅助脚本
docs/           安装、部署、使用和安全文档
```

## 安全模型

Telegram/Codex 桥接不会把 Telegram 任意文本当作 shell 命令执行。任务内容先进入本地 inbox 文件，再通过固定 Hermes quick commands 审批。审批后的任务使用 `--sandbox read-only` 运行 Codex CLI，并要求只输出计划、风险、验收标准和建议命令。

当前桥接明确不做写文件、安装依赖、commit、push、迁移和部署。

## Telegram/Codex 桥接

Mac 桥接建议使用独立 Hermes profile，通常命名为 `telegram-codex`。

常用命令：

```text
/codex_help
/codex_status
/diff
/codex_review
/task_new
/task_plan
/task_list
/task_show
/task_approve
/task_retry
/task_cancel
/task_reject
```

完整配置见 [Telegram + Codex 桥接](docs/telegram-codex.md)。

## 飞书/Lark

飞书接入按 OpenClaw 协作通道记录。真实 `App ID`、`App Secret`、群 ID 和租户信息必须保留在 git 之外。

详见 [飞书/Lark + OpenClaw](docs/feishu-openclaw.md)。

## Windows Codex CLI

Windows 侧推荐使用 WSL2 Ubuntu。辅助脚本会通过 `nvm` 安装 Node.js 22，然后安装 Codex CLI：

```bash
npm install -g @openai/codex
```

详见 [部署说明](docs/deployment.md)。

## 开源卫生

不要提交：

- `migration/`
- `node_modules/`
- `.env` or profile `.env` files
- Telegram bot token
- 飞书/Lark app secret
- Hermes state databases
- 任务队列状态、日志、PID 文件或 lock 文件

发布前请运行 [安全说明](docs/security.md) 中的敏感信息扫描。
