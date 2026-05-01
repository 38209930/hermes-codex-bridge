# Feishu/Lark + OpenClaw

## Goal

Use Feishu or Lark as the collaboration surface for OpenClaw project work. This repository provides templates and conventions; it does not include real tenant secrets.

## Create The App

1. Open the Feishu/Lark developer console.
2. Create an app for the project.
3. Enable the bot capability.
4. Copy the App ID and App Secret into your private runtime config only.
5. Configure event subscription or websocket mode according to your OpenClaw deployment.

## Configuration Template

Start from:

```text
projects/feishu-openclaw-integration/config/openclaw.feishu.template.json5
```

Replace placeholders locally:

```json5
appId: "REPLACE_WITH_FEISHU_APP_ID",
appSecret: "REPLACE_WITH_FEISHU_APP_SECRET"
```

Use `domain: "feishu"` for China tenants and `domain: "lark"` for international tenants.

## Pairing Flow

1. Start or restart OpenClaw gateway.
2. Private-message the bot.
3. Approve the pairing code:

   ```bash
   openclaw pairing list feishu
   openclaw pairing approve feishu <CODE>
   ```

4. Add the bot to a project group.
5. Mention the bot in the group to verify replies.
6. Record the resulting group chat id in your private config if you need group allow rules.

## Group Operating Rules

- Use one Feishu group per project.
- Pin project goal, current scope, project folder path, release status, and requirement change process.
- Copy decisions from chat into project memory files.
- Keep `requireMention` enabled during first rollout.

## Secrets

Never commit:

- App ID when tied to a private tenant
- App Secret
- verification tokens
- encrypt keys
- chat IDs for private groups
- exported message logs

