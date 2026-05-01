# Known Risks

- Date: 2026-03-08
- Risk: 飞书应用权限配置不完整导致机器人无法正常收发消息
- Severity: high
- Owner: Backend Engineer
- Mitigation: 严格按权限清单配置并在发布前做收发验证
- Status: open

- Date: 2026-03-08
- Risk: 未完成应用发布或管理员审批导致事件订阅不可用
- Severity: high
- Owner: Project Manager
- Mitigation: 在测试前确认发布状态
- Status: open

- Date: 2026-03-08
- Risk: 多项目混用同一飞书群导致上下文污染
- Severity: high
- Owner: Product Manager
- Mitigation: 坚持一项目一群一目录
- Status: open
