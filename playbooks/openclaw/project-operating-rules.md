# Project Operating Rules

These rules apply to every project handled by the OpenClaw team.

## 1. Project Isolation

- One project uses one dedicated project folder.
- One project uses one dedicated Feishu group.
- One project uses one dedicated release history.
- No requirement, task, bug, or decision may be stored only in chat.

## 2. Source of Truth

The project folder is the source of truth.

- `PROJECT_CONTEXT.md` stores owners, scope, status, and group info.
- `docs/PRD.md` stores product scope and acceptance criteria.
- `docs/DELIVERY_PLAN.md` stores milestones, dependencies, and risks.
- `docs/TEST_PLAN.md` stores test scope and evidence.
- `memory/DECISIONS.md` stores decisions that affect later work.
- `memory/CHANGELOG.md` stores version-by-version changes.
- `memory/MEETING_NOTES.md` stores major discussion outcomes.
- `memory/KNOWN_RISKS.md` stores unresolved or recurring risks.

## 3. Version Iteration Discipline

- Every iteration must have a version label.
- Every requirement change must name the affected version.
- Every release must update `CHANGELOG.md`.
- Every architectural or scope tradeoff must update `DECISIONS.md`.
- Every regression found after release must be linked to test updates.

## 4. Feishu Collaboration Rules

- Daily discussion can happen in Feishu.
- Effective decisions must be copied back into project memory on the same day.
- Bug reports must include version, environment, expected result, actual result, and evidence.
- Requirement changes must be acknowledged by Product Manager and Project Manager before development proceeds.

## 5. Role Handoffs

- Product Manager hands off a clear PRD and acceptance criteria.
- Project Manager hands off milestone plan, owners, and deadlines.
- Backend and Frontend hand off implementation notes and impact.
- Test Engineer hands off test evidence and release sign-off status.

## 6. Cross-Project Protection

- Do not reuse a mixed backlog across unrelated projects.
- Do not discuss project A decisions as if they apply to project B.
- If one reusable pattern affects multiple projects, write a separate summary and copy the relevant result into each impacted project.

## 7. Memory Update Minimum

Before a version is considered complete, the team must update:

- `PROJECT_CONTEXT.md`
- `memory/CHANGELOG.md`
- `memory/DECISIONS.md` if any tradeoff was made
- `docs/TEST_PLAN.md` with evidence or release sign-off
