---
name: autonomous-execute
description: Fully autonomous plan execution - executes all remaining chunks automatically with subagents, code review, and progress tracking
---

# Autonomous Plan Execution

## Overview

Fully autonomous execution of micro-chunked plans from start to finish. Executes all remaining chunks automatically using execute-plan orchestrator and execute-plan-with-subagents, with code review between chunks and error handling.

**Core principle:** Load plan → Confirm with user → Execute all chunks → Report completion

**Called by:** `/cc-unleashed:plan-execute` command

**Jira Integration:** If `jiraTracking.enabled` in plan-meta.json, transitions happen automatically via the orchestrator.

**Announce at start:**
"I'm executing the entire plan autonomously with subagents. This will continue until all chunks are complete or an error occurs."

---

## The Autonomous Flow

### Step 1: Load Plan and Verify

1. Read plan-meta.json: currentChunk, totalChunks, status
2. Verify plan is ready: file exists, chunks remaining, no blocking errors
3. If currentChunk > totalChunks: "✅ Plan already complete!" - exit gracefully
4. Calculate scope: remaining = totalChunks - currentChunk + 1

### Step 2: MANDATORY Review Chain Verification

**Before starting, verify ALL previous chunks have review data:**

```python
for entry in executionHistory:
    if chunk_num < currentChunk:
        if not entry.get("reviewCompleted"): ERROR
        if not entry.get("reviewedBy"): ERROR
        if entry.get("reviewAssessment") == "Major concerns": ERROR
```

**IF REVIEW CHAIN BROKEN:** STOP immediately. Present errors. Options: Run missing reviews / Abort.

**There is NO option to continue with broken review chain.**

### Step 3: Get User Confirmation

Present context:
```
Ready to execute plan autonomously:

Plan: [feature-name]
Progress: [currentChunk] of [totalChunks] chunks complete
Remaining: [N] chunks to execute
Estimated time: ~[X] minutes

**Autonomous Mode:**
- All chunks execute automatically with subagents
- Code review after each chunk
- Progress updates between chunks
- Stops on errors or test failures
```

Use AskUserQuestion: Yes - Execute all / No - One at a time / Cancel

### Step 4: Execute All Chunks Loop

```
while currentChunk <= totalChunks:
    Show progress header
    Invoke execute-plan orchestrator

    if result.status == "complete":
        # MANDATORY: Verify reviewData exists
        if not result.reviewData.get("reviewCompleted"):
            STOP - "Review not performed"
            Ask user: Run review now / Abort

        # Review verified - track and continue
        Show progress: duration, tests, review status

    elif result.status == "review_missing":
        STOP - "Code review mandatory but not completed"

    elif result.status == "blocked":
        STOP - Ask user: supervised mode / pause / skip

    elif result.status == "tests_failing":
        STOP - "Fix tests before continuing"
```

### Step 5: Final Report

**All chunks complete:** Summary with totals, chunk list, next steps, invoke finishing-a-development-branch

**Stopped early:** Summary with progress, blocking issue, resume instructions

See `reference.md` for detailed report templates.

---

## Quality Gates

| Gate | Enforcement |
|------|-------------|
| Review chain | Verified before starting - cannot proceed if broken |
| Chunk review | Verified after each chunk - stops if missing |
| Test passing | Required for each chunk - stops on failure |
| Fix attempts | Max 2 per issue - escalates to human |

---

## Error Handling

| Status | Action |
|--------|--------|
| complete | Verify reviewData, track progress, continue |
| review_missing | STOP - code review mandatory |
| review_gate_failed | STOP - must resolve before continuing |
| blocked | STOP - ask user for direction |
| tests_failing | STOP - fix tests before continuing |

---

## Integration

| Relationship | Description |
|--------------|-------------|
| Called by | /cc-unleashed:plan-execute |
| Uses | execute-plan (orchestrator), execute-plan-with-subagents, finishing-a-development-branch |
| Reads | plan-meta.json, chunk files |
| Updates | plan-meta.json (via orchestrator), TodoWrite |

---

## Red Flags

**NEVER:**
- Execute without user confirmation at start
- **Continue if review was skipped** - review is mandatory
- **Proceed with broken review chain** - all previous chunks must have review data
- Continue with failing tests
- Skip error reporting
- Lose progress on interruption
- **Accept chunk completion without reviewData**

**ALWAYS:**
- Ask user to confirm before starting
- **Verify review chain before starting**
- **Verify reviewData after each chunk**
- Show progress updates (including review status)
- Stop on critical errors OR missing reviews
- Provide clear summary at end
- Update plan-meta.json after each chunk WITH review fields

---

## Success Criteria

✅ **User confirms:** Autonomous execution approved before starting
✅ **Review chain verified:** All previous chunks have review data
✅ **All chunks execute:** Loop completes or stops gracefully on error
✅ **Reviews verified:** Each chunk has reviewData before marking complete
✅ **Progress tracked:** Updates shown between chunks
✅ **Clear reporting:** Final summary with all details
✅ **Resumable:** Can continue with /cc-unleashed:plan-resume if stopped

---

## References

See `reference.md` for:
- Review chain verification implementation
- Execution loop pseudocode
- AskUserQuestion templates
- Final report templates
- Example execution flow
- Comparison with manual execution
