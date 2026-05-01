# 分支与主干保护

本仓库采用分支开发。`master` 是受保护主干，不作为日常开发分支。

## 规则

- 不直接 push 到 `master`。
- 每个任务创建独立分支。
- 修改完成后通过 Pull Request 合并。
- PR 合并前至少经过一次审核。
- 不 force push `master`。
- 不删除 `master`。

## 分支命名

推荐格式：

```text
codex/<short-task-name>
docs/<short-doc-name>
fix/<short-bug-name>
feature/<short-feature-name>
```

示例：

```bash
git checkout -b docs/add-usage-guide
git checkout -b fix/task-runner-timeout
```

## 开发流程

```bash
git checkout master
git pull --ff-only
git checkout -b codex/<task-name>

# 修改、测试、提交
git status
git add <files>
git commit -m "说明本次修改"

git push -u origin codex/<task-name>
```

然后在 GitHub 上创建 Pull Request。

## 本地保护建议

即使 GitHub 已配置主干保护，本地也应养成不在 `master` 上直接开发的习惯：

```bash
git branch --show-current
```

如果输出是 `master`，先创建任务分支再修改。

## 管理员说明

仓库管理员可以维护 branch protection 或 ruleset，要求 `master` 只能通过 Pull Request 更新。管理员不应绕过保护直接推送主干，除非是紧急修复并在事后补齐记录。
