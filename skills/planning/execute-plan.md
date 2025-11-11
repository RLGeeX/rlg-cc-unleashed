---
name: execute-plan
description: Executes chunked plans task-by-task - loads one chunk at a time, executes with review checkpoints, manages chunk progression
---

# Executing Chunked Plans

## Overview

Load and execute chunked plans one chunk at a time. Follow tasks exactly, verify each step, report for review between batches.

**Core principle:** Chunk-by-chunk execution with architect review checkpoints.

**Announce at start:** "I'm using the execute-plan skill to implement chunk N of this plan."

## The Process

### Step 1: Load Plan and Current Chunk

1. Read `plan-meta.json` to get current chunk number
2. Load `chunk-NNN.md` for current chunk
3. Review critically - identify questions or concerns
4. Check dependencies - ensure prerequisite chunks complete
5. If concerns: Raise with partner before starting
6. If no concerns: Create TodoWrite with chunk tasks and proceed

### Step 2: Execute Batch

**Default: First 3 tasks of current chunk**

For each task:
1. Mark task as in_progress in TodoWrite
2. Follow each step exactly (bite-sized steps)
3. Run verifications as specified
4. Verify all tests pass
5. Mark task as completed

### Step 3: Report

When batch complete:
- Show what was implemented
- Show verification output (test results, build output)
- Current progress: "Chunk N: X of Y tasks complete"
- Say: "Ready for feedback before continuing."

### Step 4: Continue

Based on feedback:
- Apply changes if needed
- Execute next batch (3 more tasks)
- Repeat until chunk complete

### Step 5: Complete Chunk

When all tasks in chunk complete:
1. Run chunk completion checklist
2. Update `plan-meta.json`:
   - Mark chunk status as "completed"
   - Increment currentChunk if more chunks exist
3. Commit all changes
4. Report completion:
   - "Chunk N complete: [summary of what was built]"
   - "Next: Chunk N+1 - [preview of next phase]"
   - "Use `/rlg:plan-next` to continue, or `/rlg:plan-status` to review progress"

### Step 6: Complete All Chunks

After final chunk complete and verified:
- Announce: "All chunks complete! Using finishing-a-development-branch skill."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
- Follow that skill to verify tests, present options (merge/PR/cleanup)

## Context Management

**Key advantage of chunked execution:**
- Only 1 chunk loaded in context at a time (~300-500 tokens)
- Previous chunks unloaded after completion
- Keeps context lean throughout feature development
- Can pause/resume between chunks without context bloat

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker mid-batch (missing dependency, test fails, instruction unclear)
- Chunk dependency not satisfied (prerequisite chunk incomplete)
- You don't understand an instruction
- Verification fails repeatedly
- Test failures that aren't specified in plan

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the chunk based on feedback
- Dependencies change
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Chunk Progress Tracking

Update `plan-meta.json` after each chunk:

```json
{
  "feature": "add-oauth-login",
  "created": "2025-11-11T14:30:00Z",
  "totalChunks": 4,
  "currentChunk": 2,
  "status": "in-progress",
  "completedChunks": [1],
  "lastUpdated": "2025-11-11T15:45:00Z"
}
```

## Resuming Interrupted Plans

If execution interrupted:
1. Read `plan-meta.json` to find currentChunk
2. Read chunk file to find last completed task
3. Resume from next incomplete task
4. Use TodoWrite to track remaining tasks
5. Continue normal execution flow

## Remember

- Load only current chunk (not entire plan)
- Review chunk critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Between batches: just report and wait
- Stop when blocked, don't guess
- Update plan-meta.json after each chunk
- Commit frequently as specified

## Batch Size Adjustment

Default: 3 tasks per batch

**Adjust based on:**
- Task complexity (simpler tasks → larger batch)
- Feedback frequency needs (more review → smaller batch)
- Chunk urgency (faster progress → larger batch)

**Always ask before changing batch size.**

## Example Execution Flow

**Starting chunk-002 of add-oauth-login feature:**

1. Load plan-meta.json: currentChunk = 2
2. Load chunk-002.md: "Auth flow implementation" - 8 tasks
3. Review: Depends on chunk-001 (config) ✓ complete
4. Create TodoWrite with 8 tasks
5. Execute batch 1: Tasks 1-3
   - Implement OAuth routes
   - Add session handling
   - Create redirect logic
6. Report: "Batch 1 of chunk-002 complete. 3/8 tasks done. Tests passing."
7. Get feedback → continue
8. Execute batch 2: Tasks 4-6
9. Execute batch 3: Tasks 7-8
10. Update plan-meta.json: currentChunk = 3
11. Report: "Chunk-002 complete! OAuth flow working. Next: User integration."
