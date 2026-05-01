# Feishu Config Setup

Use this template:

- `openclaw.feishu.template.json5`

## How to apply

1. Open your Feishu app in Feishu Open Platform.
2. Copy the real `App ID` and `App Secret`.
3. Replace placeholders in `openclaw.feishu.template.json5`.
4. Copy the result into:

   - `~/.openclaw/openclaw.json`

5. Start or restart the gateway:

   ```bash
   openclaw gateway restart
   ```

6. Watch logs:

   ```bash
   openclaw logs --follow
   ```

## First test flow

1. Private-message the bot in Feishu.
2. Run:

   ```bash
   openclaw pairing list feishu
   openclaw pairing approve feishu <CODE>
   ```

3. Add the bot to the project group.
4. In the group, `@` mention the bot and send a test message.
5. After the first successful group message, record the `chat_id` and lock group rules if needed.

## Notes

- Feishu uses `App ID` and `App Secret`, not a generic bot token.
- If you are using Lark international, change `domain` to `"lark"`.
- The current template keeps `requireMention: true` for safer first rollout.
