---
description: Create new chunked implementation plan for a feature
---

# Create New Plan

Invoke the plan writing skill to create a structured, chunked implementation plan.

Load the skill from: `skills/planning/write-plan.md`

**Usage:** `/rlg-plan-new [feature-name]`

This will:
- Create a new plan directory: `.claude/plans/[feature-name]/`
- Generate plan metadata: `plan-meta.json`
- Break down the feature into manageable chunks (5-10 tasks each)
- Create separate chunk files: `chunk-001.md`, `chunk-002.md`, etc.
- Provide implementation roadmap

**Example:** `/rlg-plan-new add-oauth-login`

The plan will be context-efficient, loading only the current chunk during execution to minimize token usage.
