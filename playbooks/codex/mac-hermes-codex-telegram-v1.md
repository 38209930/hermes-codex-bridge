# Mac Hermes + Codex CLI Telegram Bridge V1

This plan uses the existing Mac Hermes installation as the Telegram entrypoint and routes approved coding tasks to Codex CLI.

Current local facts:

- Hermes is already installed: `Hermes Agent v0.9.0`.
- Hermes is already configured with GLM/Ark: `glm-5.1` via `ark`.
- Codex CLI is already installed: `codex-cli 0.125.0`.
- Existing Feishu Hermes profiles must remain isolated and untouched.
- Codex App remains the main desktop workspace; v1 does not control the current Codex App conversation.

## V1 Goal

- Add a Mac Telegram bot for remote status, review, and approval workflows.
- Use Hermes/GLM as the conversational router and approval layer.
- Use Codex CLI as the execution layer for coding tasks.
- Keep high-risk actions behind explicit approval.

## Non-Goals

- Do not replace the existing Hermes model configuration.
- Do not modify `feishu-bot1` through `feishu-bot4`.
- Do not install Windows tooling.
- Do not connect Feishu in this v1.
- Do not attempt to control the current Codex App window or thread.

## Recommended Architecture

```text
Telegram
  -> Mac Hermes profile: telegram-codex
  -> guarded command router
  -> Codex CLI
  -> project repo
  -> result summary back to Telegram
```

## Profile Strategy

Create a dedicated Hermes profile:

```text
~/.hermes/profiles/telegram-codex
```

The profile should have:

- its own `.env`
- its own `config.yaml`
- its own `state.db`
- its own `workspace`
- Telegram credentials only for the Mac Codex bot

This keeps the Telegram/Codex bridge separate from existing Feishu team profiles.

## Telegram Setup

Create a Telegram bot through BotFather:

- Bot name: `mac-codex-bot`
- Keep the token private.
- Get your numeric Telegram user id from `@userinfobot`.

Configure the `telegram-codex` profile environment:

```bash
TELEGRAM_BOT_TOKEN=<mac bot token>
TELEGRAM_ALLOWED_USERS=<your telegram numeric user id>
TELEGRAM_HOME_CHANNEL=<your telegram numeric user id>
TELEGRAM_REQUIRE_MENTION=true
```

For first rollout, use direct messages only. If adding the bot to a group later, keep mention-required behavior enabled.

## Command Contract

Supported v1 quick commands:

```text
/codex_status
/codex_help
/codex_review
/codex_resume_last
/diff
```

Command behavior:

- `/codex_status`: returns node name, current project, current branch, dirty state, Hermes version, Codex CLI version.
- `/codex_help`: lists the available bridge commands.
- `/codex_review`: runs Codex review in the current project and returns findings.
- `/codex_resume_last`: resumes the latest Codex CLI session with a planning prompt, not Codex App.
- `/diff`: returns `git diff --stat` plus a short summary.

Custom `/codex ask <task>` style commands are intentionally not implemented in the quick-command layer because Hermes quick commands do not safely receive arbitrary user arguments. For custom work, send a normal message first and ask Hermes for a plan.

## Safety Rules

Default allowed without extra approval:

- `git status --short`
- `git branch --show-current`
- `git diff --stat`
- `git diff`
- `codex --version`
- `hermes --version`
- project test commands explicitly added to the allowlist

Requires `/approve <task_id>`:

- file writes
- dependency installation
- `git add`
- `git commit`
- `git push`
- migrations
- deployment
- any command outside the allowlist

Always forbidden in v1:

- `rm -rf`
- `git reset --hard`
- force push
- credential printing
- arbitrary shell command execution from Telegram text

Approval defaults:

- approvals expire after 30 minutes
- approvals are single-use
- approvals are valid only for the matching `task_id`
- non-allowlisted Telegram users cannot approve anything

## Implementation Steps

1. Create the `telegram-codex` Hermes profile.

   Use Hermes profile tooling if available; otherwise create an isolated profile folder matching the existing profile layout.

2. Configure the profile with the existing GLM/Ark model settings.

   Copy model/provider settings from the global Hermes config, but do not copy Feishu credentials or existing profile state.

3. Set Telegram environment variables in the new profile `.env`.

4. Set the profile `terminal.cwd`.

   Start with:

   ```text
   ~/.hermes/profiles/telegram-codex/workspace
   ```

   Switch into a project only when handling a specific task.

5. Start the profile gateway.

   ```bash
   ./scripts/configure-telegram-codex-profile.sh
   ```

6. Verify Telegram direct message access.

   - white-listed user gets a response
   - unknown user is denied or ignored

7. Add the guarded Codex command router.

   The router must map Telegram commands to fixed local functions. It must never execute raw Telegram text as shell.

8. Add task state storage.

   Store task id, command type, requested action, approval status, expiration time, and result summary in the profile-local workspace or state directory.

9. Add audit logging.

   Log incoming command, Telegram user id, task id, approval action, executed local command, exit code, and short result.

10. Run the acceptance tests below.

## Acceptance Tests

Mac local checks:

```bash
hermes --version
codex --version
hermes --profile telegram-codex gateway status
```

Telegram checks:

- DM `/codex_status` returns Mac/Hermes/Codex status.
- DM `/codex_help` returns command help.
- DM `/diff` returns repo diff summary.
- DM `/codex_review` runs Codex CLI review and returns a short report.
- DM `/codex_resume_last` resumes the latest Codex CLI session with a planning prompt.
- non-allowlisted user cannot run or approve commands.

Codex boundary checks:

- `/codex_resume_last` resumes the latest Codex CLI session.
- Codex App remains usable separately.
- No test claims to control the current Codex App conversation.

## Rollback

Stop the dedicated gateway:

```bash
hermes --profile telegram-codex gateway stop
```

Disable Telegram access by removing or blanking:

```bash
TELEGRAM_BOT_TOKEN
TELEGRAM_ALLOWED_USERS
TELEGRAM_HOME_CHANNEL
```

Existing Feishu profiles and the global Hermes installation should remain unaffected.
