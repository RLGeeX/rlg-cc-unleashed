---
name: plan-manager
description: Manages chunked plan lifecycle - listing plans, checking status, resuming interrupted plans, cleaning up completed plans
---

# Plan Manager

## Overview

Helper skill for managing chunked plans throughout their lifecycle. Provides status checking, resumption, and cleanup operations.

**Plans directory:** `.claude/plans/[feature-name]/`

## Operations

### List All Plans

Command: `/rlg:plan-list`

**Process:**
1. Scan `.claude/plans/` directory
2. Read each `plan-meta.json`
3. Display summary table:

```
Feature Plans:
--------------
1. add-oauth-login
   Status: in-progress
   Progress: Chunk 2 of 4
   Last Updated: 2025-11-11 15:45

2. refactor-api
   Status: pending
   Progress: Chunk 1 of 3
   Created: 2025-11-10 09:30

3. add-metrics
   Status: completed
   Completed: 2025-11-09 18:20
```

### Check Plan Status

Command: `/rlg:plan-status [feature-name]`

**Process:**
1. Load `plan-meta.json` for specified feature (or current if in worktree)
2. Load current chunk file
3. Display detailed status:

```
Plan: add-oauth-login
Status: in-progress

Overall Progress: 2 of 4 chunks complete (50%)
Current Chunk: chunk-003 (User Integration)
  - 6 tasks total
  - 2 tasks completed
  - 4 tasks remaining

Completed Chunks:
  ✓ chunk-001: Setup (7 tasks)
  ✓ chunk-002: Auth Flow (8 tasks)

Remaining Chunks:
  → chunk-003: User Integration (6 tasks) - IN PROGRESS
    chunk-004: Testing & Docs (9 tasks)

Next Steps:
  - Use /rlg:plan-next to continue chunk-003
  - 4 tasks remaining in current chunk
```

### Resume Plan

Command: `/rlg:plan-resume [feature-name]`

**Process:**
1. Load `plan-meta.json`
2. Determine current state:
   - If status = "pending": Start chunk-001
   - If status = "in-progress": Resume currentChunk
   - If status = "completed": Offer to archive or restart
3. Load appropriate chunk
4. Use execute-plan skill to continue
5. Start from first incomplete task

**Handling interruptions:**
- Check TodoWrite for partial task completion
- Review last git commits to determine progress
- Verify tests still passing before resuming
- Offer summary of what's been done

### Mark Chunk Complete

Called by execute-plan skill after chunk completion.

**Process:**
1. Load `plan-meta.json`
2. Add current chunk to completedChunks array
3. Increment currentChunk
4. Update lastUpdated timestamp
5. If all chunks complete: Set status to "completed"
6. Save `plan-meta.json`

### Archive Completed Plan

Command: `/rlg:plan-archive [feature-name]`

**Process:**
1. Verify plan status is "completed"
2. Move plan to `.claude/plans/archive/[feature-name]/`
3. Add completion metadata
4. Report: "Plan archived. Use /rlg:plan-list to see active plans."

### Delete Plan

Command: `/rlg:plan-delete [feature-name]`

**Process:**
1. Confirm with user (show plan status first)
2. Delete `.claude/plans/[feature-name]/` directory
3. Report deletion
4. **Use with caution** - cannot be undone

## Plan Metadata Management

### Structure

```json
{
  "feature": "feature-name",
  "created": "2025-11-11T14:30:00Z",
  "totalChunks": 4,
  "currentChunk": 2,
  "status": "in-progress",
  "completedChunks": [1],
  "lastUpdated": "2025-11-11T15:45:00Z",
  "description": "Brief description",
  "contextTokens": 1200,
  "worktree": "worktrees/feature-name"
}
```

### Status Values

- **pending**: Plan created, not started
- **in-progress**: Currently executing chunks
- **blocked**: Hit a blocker, needs intervention
- **paused**: Manually paused between chunks
- **completed**: All chunks done, ready for merge/PR
- **archived**: Completed and archived

### Updating Metadata

Always update these fields:
- **lastUpdated**: On any change
- **currentChunk**: When chunk completes
- **completedChunks**: When chunk finishes
- **status**: When state changes

## Helper Functions

### Calculate Progress

```python
progress_percent = (len(completedChunks) / totalChunks) * 100
tasks_complete = sum(count_tasks(f"chunk-{i:03d}.md") for i in completedChunks)
```

### Find Current Task

1. Load current chunk
2. Read TodoWrite state
3. Return first task not marked completed

### Estimate Remaining Time

Based on:
- Tasks remaining in current chunk
- Chunks remaining
- Average time per task (from history)

## Integration with Other Skills

**write-plan:**
- Creates plan-meta.json
- Initializes status as "pending"

**execute-plan:**
- Updates currentChunk
- Updates completedChunks
- Updates status
- Updates lastUpdated

**finishing-a-development-branch:**
- Sets status to "completed"
- Offers archive option

## Context Awareness

**In worktree:**
- Auto-detect feature name from worktree path
- Default commands to current feature
- Show only current feature status

**Outside worktree:**
- Require feature-name parameter
- Show all plans by default

## Remember

- Always load plan-meta.json first
- Keep metadata in sync with actual state
- Verify chunks complete before marking
- Update timestamps on every change
- Offer helpful next steps in output
- Handle missing/corrupt plans gracefully

## Error Handling

**Missing plan-meta.json:**
```
Error: Plan metadata not found for 'feature-name'
Available plans: [list other plans]
```

**Corrupt JSON:**
```
Error: Plan metadata corrupted for 'feature-name'
Attempting recovery...
[Try to reconstruct from chunk files]
```

**Chunk file missing:**
```
Error: Chunk file chunk-003.md not found
Expected: .claude/plans/feature-name/chunk-003.md
Cannot continue execution without this chunk.
```
