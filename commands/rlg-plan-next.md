---
description: Load and execute the next chunk in the current plan
---

# Execute Next Plan Chunk

Invoke the plan execution skill to load and work on the next chunk of tasks.

Load the skill from: `skills/planning/execute-plan.md`

**Usage:** `/rlg-plan-next`

This will:
- Identify the current plan (from worktree context or last active plan)
- Load the next incomplete chunk
- Display chunk tasks and context
- Begin execution of tasks in the chunk
- Update progress tracking

The plan execution is context-efficient, loading only:
- Plan metadata
- Current chunk tasks
- Relevant agent(s) for the tasks

Previous and future chunks remain unloaded to conserve context.

**Workflow:**
1. `/rlg-plan-new feature` - Create plan
2. `/rlg-plan-next` - Start chunk 1
3. [Complete tasks in chunk 1]
4. `/rlg-plan-next` - Move to chunk 2
5. [Continue until all chunks complete]
