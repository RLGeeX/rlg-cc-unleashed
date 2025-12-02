---
name: execute-plan
description: Smart orchestrator for chunked plans - auto-detects complexity, recommends execution mode (parallel/automated/supervised/hybrid), dispatches to executor, tracks progress with mandatory code review
---

# Execute Plan (Smart Orchestrator)

## CRITICAL: You Are an Orchestrator, Not an Implementer

**RULES - NO EXCEPTIONS:**

1. **NEVER implement tasks yourself** - dispatch to specialized subagents
2. **NEVER use general-purpose for implementation** - use python-pro, security-engineer, etc.
3. **NEVER abandon this workflow** - it ensures quality control
4. **ALWAYS dispatch to execute-plan-with-subagents** for automated mode
5. **ALWAYS ensure code review happens** between tasks/chunks

**If tempted to "just do it yourself":** STOP. Use the workflow.

---

## Pre-Execution Checklist (MANDATORY)

Before executing ANY chunk, verify:

| Check | Requirement |
|-------|-------------|
| Plan validity | status = "ready" or "in-progress", planReview.assessment = "Ready" |
| Chunk validity | File exists, all tasks have **Agent:** field |
| Previous review | If chunk > 1: previous chunk has reviewCompleted = true |
| Dependencies | All dependency chunks are complete |

**If ANY check fails:** STOP. Present errors to user with options: Fix and retry / Skip (DANGEROUS) / Abort.

See `reference.md` for detailed checklist implementation.

---

## The Orchestration Flow

### Step 0: Workspace Safety Check

If automated mode likely:
- Check if in worktree: `git rev-parse --git-dir`
- If NOT in worktree: Warn user, offer options (create worktree / execute anyway / use supervised)
- If in worktree: Safe to proceed

### Step 1: Load & Analyze

1. **Read plan-meta.json**: currentChunk, totalChunks, executionConfig, jiraTracking
2. **Check for parallel group**: Is currentChunk in executionConfig.parallelizable?
3. **Load chunk(s)**: Parse tasks, check metadata
4. **Check dependencies**: Verify prerequisites complete
5. **Get complexity**: From chunk file or infer (simple/medium/complex)

### Step 2: Recommend & Confirm

Present to user:
- Chunk info (name, tasks, tokens)
- Complexity rating with reason
- Worktree status
- If parallel candidate: time savings estimate

**Use AskUserQuestion** with options:
- Parallel Automated (if applicable)
- Sequential Automated
- Supervised
- Hybrid

### Step 3: Dispatch to Executor

**Jira Integration:** If jiraTracking.enabled, transition issue to "In Progress" before dispatch.

| Mode | Action |
|------|--------|
| Parallel Automated | Invoke execute-plan-with-subagents with chunk_group |
| Sequential Automated | Invoke execute-plan-with-subagents with single chunk |
| Supervised | Execute human-in-loop: present each task, run verifications |
| Hybrid | Subagent for simple tasks, supervised for complex |

### Step 4: Review Verification Gate (MANDATORY)

**Before marking chunk complete, verify:**

- [ ] Code reviewer was dispatched
- [ ] Review report received with assessment
- [ ] Assessment is "Ready" (not "Major concerns")
- [ ] All critical issues resolved

**If gate fails:** STOP. Present errors. Options: Run review now / Fix and re-review / Abort.

**There is NO option to skip the review gate.**

### Step 5: Track & Report

**Update plan-meta.json:**
```json
{
  "currentChunk": N+1,
  "executionHistory": [{
    "chunk": N,
    "mode": "automated",
    "duration": 8,
    "testsAdded": 6,
    "testsPassing": true,
    "reviewCompleted": true,
    "reviewedBy": "code-reviewer",
    "reviewAssessment": "Ready",
    "reviewTimestamp": "2025-11-12T15:07:30Z"
  }]
}
```

**Jira:** If enabled, transition issue to "Done".

**Report to user:** Summary, stats, progress, next chunk recommendation.

### Step 6: Plan Complete

When currentChunk > totalChunks:
- Report completion summary
- Invoke finishing-a-development-branch skill

---

## Jira Integration

If `jiraTracking.enabled` in plan-meta.json:

| Event | Action |
|-------|--------|
| Chunk start | Transition to "In Progress" |
| Chunk complete | Transition to "Done" |
| Chunk blocked | Add comment with blocker description |
| MCP error | Ask user: Restart MCP / Skip Jira / Retry / Pause |

---

## Complexity Detection

| Complexity | Indicators | Recommended Mode |
|------------|------------|------------------|
| Simple | initialize, configure, setup, boilerplate | Automated |
| Medium | API, handler, CRUD, business logic | Automated with review |
| Complex | algorithm, concurrency, architectural | Supervised |

---

## When to Stop and Ask

**STOP immediately:**
- Dependency not satisfied
- Chunk file not found
- User cancels
- Automated mode blocked
- Tests failing

**Ask user:**
- Ambiguous complexity
- First time with this plan
- Previous chunk had issues
- Not in worktree

---

## Integration

**Calls:** execute-plan-with-subagents, using-git-worktrees, finishing-a-development-branch

**Called by:** /cc-unleashed:plan-next, /cc-unleashed:plan-resume

**Reads:** plan-meta.json, chunk-NNN-name.md

**Updates:** plan-meta.json (currentChunk, executionHistory)

---

## Red Flags

**NEVER:**
- Implement tasks yourself
- Use general-purpose for implementation
- Skip code reviews
- Execute without user confirmation
- Proceed with unmet dependencies
- Continue with failing tests

**ALWAYS:**
- Dispatch to execute-plan-with-subagents for automated mode
- Verify code review before marking complete
- Get user confirmation for mode
- Update plan-meta.json after each chunk

---

## Remember

This is an **orchestrator**, not an executor:
- Analyze and recommend (not decide)
- Dispatch to appropriate executor (not execute yourself)
- Track progress (update metadata)
- Handle errors gracefully (provide options)

**See `reference.md` for:** Full AskUserQuestion examples, pseudocode implementations, detailed error handling, example interactions.
