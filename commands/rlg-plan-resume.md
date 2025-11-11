---
description: Resume an interrupted plan from where it left off
---

# Resume Plan

Invoke the plan manager skill to resume an interrupted implementation plan.

Load the skill from: `skills/planning/plan-manager.md` with action: "resume"

**Usage:** `/rlg-plan-resume [feature-name]`

This will:
- Load the specified plan's metadata
- Identify the last incomplete task in the current chunk
- Display context of where the plan was interrupted
- Resume execution from that point

Use this when:
- Returning to a plan after a break
- Context was lost due to session end
- Switching between multiple active plans

**Example:** `/rlg-plan-resume add-oauth-login`

The skill will restore:
- Current chunk position
- Task completion state
- Relevant context for continuing work
