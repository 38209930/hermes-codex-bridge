# Codex Plugin 分发说明

`hermes-codex-bridge` 可以作为 Codex Plugin 安装。插件的目的不是替用户绕过安全审批，而是让 Codex 更稳定地指导部署、验证、排障和二次开发。

## 能带来什么

安装插件后，用户可以直接问 Codex：

```text
帮我部署 hermes-codex-bridge
检查 Telegram bridge 为什么没响应
验证 V3 显式审批是否安全
帮我排查 /write_prepare 没收到 task_id 的原因
```

Codex 会加载插件里的 skill，按项目约定执行：

- 创建或检查 `telegram-codex` Hermes profile
- 配置 Telegram bridge
- 应用 Hermes quick command 参数补丁
- 验证 `/task_*`、`/write_*`、`/commit_*`、`/push_*`
- 验证 Hermes gateway 已通过 launchd 自启动
- 保护“普通聊天永不入队”的安全边界

## GitHub 安装方式

当前官方 Plugin Directory 还没有开放通用自助发布入口，因此推荐先走 GitHub marketplace 分发。

从 GitHub 安装：

```bash
codex plugin marketplace add 38209930/hermes-codex-bridge --ref master
```

开发本仓库时，也可以从本地目录安装：

```bash
codex plugin marketplace add /Volumes/SSD/myot/AI-WORK/hermes-codex-bridge
```

升级：

```bash
codex plugin marketplace upgrade hermes-codex-bridge
```

移除：

```bash
codex plugin marketplace remove hermes-codex-bridge
```

## 仓库结构

```text
.agents/plugins/marketplace.json
plugins/hermes-codex-bridge/
  .codex-plugin/plugin.json
  assets/icon.svg
  skills/hermes-codex-bridge/SKILL.md
```

## Plugin Manifest

插件 manifest 位于：

```text
plugins/hermes-codex-bridge/.codex-plugin/plugin.json
```

它声明：

- 插件名：`hermes-codex-bridge`
- 版本：`0.1.0`
- skill 路径：`./skills/`
- GitHub 仓库、MIT license、安全说明和默认 prompt

## Skill 行为边界

插件 skill 会坚持以下规则：

- 普通 Telegram 消息永远不进入 Codex 队列
- 不把 Telegram 文本当 shell 执行
- 不允许模糊 `/approve`
- 不在 `master` 写文件
- write、commit、push 分阶段审批
- deploy 当前版本禁用
- 不输出 token、secret、`.env` 或 API key

## 自启动检查

插件引导部署时，应把自启动作为必查项。Telegram bridge 没有常驻进程，真正常驻的是 Hermes gateway：

```bash
hermes --profile telegram-codex gateway status
plutil -p ~/Library/LaunchAgents/ai.hermes.gateway-telegram-codex.plist
launchctl print gui/$(id -u)/ai.hermes.gateway-telegram-codex
```

期望：

```text
RunAtLoad => true
state = running
```

如果没有自启动，应先修复 Hermes gateway 的 launchd service，再验证 Telegram quick commands。

## 官方插件库准备

当 Codex 官方 Plugin Directory 开放自助发布后，需要准备：

- 完整 `plugin.json`
- logo 和截图
- README 英文摘要
- 安装 demo GIF 或短视频
- Privacy policy，可以暂指向 `docs/security.md`
- Terms，可以暂指向 `LICENSE`
- GitHub release，例如 `v0.1.0`

## 后续增强

- 增加英文版 skill 文档
- 增加截图或 demo GIF
- 增加 `docs/faq.md`
- 增加 issue templates
- 增加插件安装 smoke test
