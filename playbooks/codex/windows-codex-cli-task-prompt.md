# Prompt for Windows-Side Codex

Copy this prompt into the Windows-side Codex conversation.

```text
请在 Windows 侧实施 Codex CLI 安装与入门方案。

目标：
- Windows 已有 Codex App，继续保留。
- 新增 Codex CLI，推荐安装在 WSL2 Ubuntu 内。
- V1 只安装 Codex CLI、完成登录、验证项目内运行、review、resume。
- 不安装 Hermes，不接飞书，不接 Telegram bot。

请执行：
1. 检查 Windows 是否已安装 WSL2 Ubuntu。
2. 如果没有，指导我在管理员 PowerShell 执行：
   wsl --install -d Ubuntu
   然后重启并创建 Ubuntu 用户。
3. 在 Ubuntu 内安装基础依赖：
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y git curl build-essential ca-certificates
4. 用 nvm 安装 Node.js 22：
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
   source ~/.bashrc
   nvm install 22
   nvm use 22
5. 安装 Codex CLI：
   npm install -g @openai/codex
   codex --version
6. 执行：
   codex login
   如果 WSL 浏览器授权不顺畅，指导我复制链接到 Windows 浏览器完成。
7. 建议项目放在 WSL 文件系统：
   mkdir -p ~/projects
   cd ~/projects
8. 验证：
   node -v
   npm -v
   codex --version
   codex exec "用一句话说明你已可用"
9. 在测试 repo 内验证：
   codex exec -C ~/projects/<repo> "列出这个项目的主要目录"
   codex exec review

请不要配置 Hermes、飞书或 Telegram。请不要尝试控制 Codex App 当前窗口。Codex App 和 Codex CLI 可以并存，但会话不是同一个。
```
