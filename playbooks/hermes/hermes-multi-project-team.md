# Hermes 多项目虚拟团队使用规则

## 核心概念
- `profile` 是 bot 的人格、记忆、私人办公室
- `项目目录` 是 bot 临时进入执行任务的项目现场
- 不要让多个 bot 永久把同一个项目目录当默认老巢

## 推荐目录结构
```text
$HOME/Documents
├── projects
│   ├── app-alpha
│   ├── erp-backend
│   ├── feishu-openclaw-integration
│   └── design-system
└── .hermes
    └── profiles
        ├── feishu-bot1
        │   ├── memories
        │   ├── workspace
        │   ├── home
        │   └── state.db
        ├── feishu-bot2
        ├── feishu-bot3
        └── feishu-bot4
```

## 日常工作方式
- 平时让 4 个 bot 默认待在各自 profile 的 `workspace/`
- 只有在处理某个具体项目时，才把某个 bot 显式切到对应项目目录
- 做完项目任务后，可以把 bot 再切回自己的 profile-local `workspace/`

## 角色分工
- `feishu-bot1`：产品需求、任务拆解、优先级和推进
- `feishu-bot2`：后端实现、工程交付、重构
- `feishu-bot3`：架构裁决、代码 review、长期一致性
- `feishu-bot4`：前端实现、视觉还原、交互体验

## 常用命令
```bash
cd "$HOME/projects/hermes-codex-bridge"

# 团队隔离巡检
./scripts/hermes-team-audit.sh

# 改了 SOUL 后重载
./scripts/hermes-reload-bot-soul.sh feishu-bot3

# 切 bot 到某个项目目录
./scripts/hermes-switch-bot-project.sh feishu-bot2 "$HOME/projects/hermes-codex-bridge"

# 切回 bot 自己的 workspace
./scripts/hermes-switch-bot-project.sh feishu-bot2 --reset
```

## 纪律
- 不启用共享型 external memory provider
- 不把 4 个 bot 永久绑定到同一个项目目录
- 共享仓库可以进入，但必须是显式、按任务进入
- bot 的长期人格、memory、state 只留在各自 profile 中
