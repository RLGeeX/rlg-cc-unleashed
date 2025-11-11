---
description: List all feature plans with status summary
---

# List All Plans

Invoke the plan manager skill to display all feature plans in the workspace.

Load the skill from: `skills/planning/plan-manager.md` with action: "list"

**Usage:** `/rlg-plan-list`

This displays a table of all plans with:
- Feature name
- Status (not started, in progress, completed)
- Current chunk / total chunks
- Tasks completed / total tasks
- Last updated timestamp
- Location (worktree branch if applicable)

Use this to:
- See all active and completed plans
- Choose which plan to resume
- Track progress across multiple features
- Identify stale or abandoned plans

**Example output:**
```
Feature Plans:
┌─────────────────┬──────────────┬────────┬───────┬─────────────┐
│ Feature         │ Status       │ Chunks │ Tasks │ Last Update │
├─────────────────┼──────────────┼────────┼───────┼─────────────┤
│ add-oauth-login │ In Progress  │ 2/4    │ 12/35 │ 2 hours ago │
│ refactor-api    │ Completed    │ 3/3    │ 18/18 │ 1 day ago   │
│ add-webhooks    │ Not Started  │ 0/5    │ 0/42  │ 3 days ago  │
└─────────────────┴──────────────┴────────┴───────┴─────────────┘
```
