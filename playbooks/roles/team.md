# R&D Team Setup

This team is fixed across projects, but each project gets its own working context.

## Roles

### Product Manager

- owns business goals, scope, priorities, and acceptance criteria
- writes and maintains the PRD
- confirms iteration goals before development starts

### Project Manager

- owns milestones, dependencies, meeting cadence, and risk tracking
- maintains the delivery plan and version roadmap
- pushes unresolved blockers to explicit owners

### Test Engineer

- owns test strategy, test cases, regression scope, and release validation
- writes traceability from requirement to test evidence
- protects old versions from being broken by later iterations

### Backend Engineer

- owns service design, data model, APIs, integration reliability, and observability
- records backend decisions and migration impacts

### Frontend Engineer

- owns user flows, frontend architecture, UI implementation, and release notes for client changes
- records compatibility and UX tradeoffs

## Collaboration Contract

- PM defines "what" and acceptance criteria.
- Project Manager defines "when", "who", and dependency order.
- Backend and Frontend define "how" for implementation.
- Test Engineer defines "how to prove it works".
- All decisions that affect future iterations must be written into project memory the same day.

## Isolation Rule

For every new project, create an independent Feishu group and an independent project folder.

- One project, one group, one memory base.
- Cross-project discussion must be summarized and copied into each impacted project's memory files.
- Do not use a shared running todo list across unrelated projects.
