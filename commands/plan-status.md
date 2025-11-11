---
description: Show current plan progress and status
---

# Plan Status

Invoke the plan manager skill to display progress on the current or specified plan.

Load the skill from: `skills/planning/plan-manager.md` with action: "status"

**Usage:**
- `/rlg-plan-status` - Show status of current plan (if in feature worktree)
- `/rlg-plan-status [feature-name]` - Show status of specific plan

This displays:
- Feature name and description
- Total chunks and current chunk
- Completed tasks vs remaining tasks
- Chunk-by-chunk progress breakdown
- Estimated time remaining

**Example:** `/rlg-plan-status add-oauth-login`
