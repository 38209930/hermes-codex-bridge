# 开发说明

## 环境要求

- macOS 或 Linux，用于运行 shell 脚本
- Node.js 22
- npm
- OpenClaw
- Codex CLI，用于 Codex 桥接流程
- Hermes Agent，用于 Telegram gateway 流程

使用仓库指定的 Node 版本：

```bash
nvm use
npm ci
```

## 脚本检查

提交前运行 shell 语法检查：

```bash
bash -n scripts/*.sh
```

如果本机可用 PowerShell：

```powershell
pwsh -NoProfile -File scripts/windows-codex-cli-bootstrap.ps1 -?
```

## OpenClaw 检查

```bash
npm run openclaw -- --version
```

## 项目模板流程

从模板创建项目：

```bash
cp -R projects/_template projects/my-project
```

每个项目维护自己的：

- 需求说明
- 交付计划
- 测试计划
- 变更记录
- 决策记录
- 已知风险
- 会议纪要

## 语言约定

- 默认使用中文编写对话、计划、执行说明、验收说明、测试报告和项目文档。
- 代码标识符、命令、API 字段、协议字段和错误原文保持原语言。
- 注释默认中文，但只在确实有助于理解时添加。
- commit message 默认中文；如果某个外部项目已有英文规范，则遵守该项目规范。

## 贡献规则

- 凭证不要进入 git。
- 生成的运行状态不要进入 git。
- 使用模板占位符，不提交真实租户、应用或用户标识。
- 桥接命令保持固定和显式，不从聊天文本直接执行 shell。
- 修改脚本参数、环境变量或命令名时，同步更新文档。
