# New Project Startup

## 1. Create Project Folder

```bash
cp -R "projects/_template" "projects/<project-key>"
```

## 2. Fill Project Context

Update:

- `PROJECT_CONTEXT.md`
- `docs/PRD.md`
- `docs/DELIVERY_PLAN.md`

## 3. Create Feishu Group

Recommended group name:

- `[项目简称]-产品研发群`

Pin the kickoff message from:

- `playbooks/openclaw/project-kickoff-message.md`

## 4. Assign Team Roles

Use one prompt file per role:

- `roles/product-manager.md`
- `roles/project-manager.md`
- `roles/test-engineer.md`
- `roles/backend-engineer.md`
- `roles/frontend-engineer.md`
- `roles/general-collaboration.md`

## 5. Start First Cycle

The first cycle should produce:

- version goal
- scope
- milestones
- implementation approach
- test scope
- release condition
