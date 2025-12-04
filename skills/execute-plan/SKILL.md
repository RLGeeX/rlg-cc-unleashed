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
2. **Check Jira integration**: If `jiraTracking.enabled`, extract issue key for current chunk
3. **Check for parallel group**: Is currentChunk in executionConfig.parallelizable?
4. **Load chunk(s)**: Parse tasks, check metadata
5. **Check dependencies**: Verify prerequisites complete
6. **Get complexity**: From chunk file or infer (simple/medium/complex)

### Step 2: Recommend & Confirm

Present to user:
- Chunk info (name, tasks, tokens)
- Complexity rating with reason
- Worktree status
- **Jira status**: If enabled, show issue key and current status
- If parallel candidate: time savings estimate

**Use AskUserQuestion** with options:
- Parallel Automated (if applicable)
- Sequential Automated
- Supervised
- Hybrid

### Step 3: Dispatch to Executor

**A. Jira Transition to "In Progress" (MANDATORY if enabled)**

If `jiraTracking.enabled`:
1. Look up `jiraIssueKey` for current chunk in `jiraTracking.chunkMapping`
2. **MUST transition issue to "In Progress" BEFORE dispatching executor**
3. If transition fails: Ask user (Retry / Skip Jira / Abort)

```
mcp__jira__transitionJiraIssue(jiraIssueKey, "In Progress")
```

**B. Dispatch Based on Mode**

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

**A. Jira Transition to "Done" (MANDATORY if enabled)**

If `jiraTracking.enabled` and review passed:
```
mcp__jira__transitionJiraIssue(jiraIssueKey, "Done")
```

If transition fails: Ask user (Retry / Skip / Continue anyway)

**B. Update plan-meta.json:**
- Increment `currentChunk` to N+1
- Add `executionHistory` entry with: chunk, mode, duration, tests, review fields, Jira fields (if enabled)

See `reference.md` for full executionHistory schema.

**C. Report to user:** Summary, stats, progress, Jira status, next chunk recommendation.

### Step 6: Plan Complete

When currentChunk > totalChunks:
- Report completion summary
- Invoke finishing-a-development-branch skill

---

## Jira Integration (MANDATORY when enabled)

If `jiraTracking.enabled` in plan-meta.json, Jira transitions are **woven into the main flow**:

| Step | Jira Action | Timing |
|------|-------------|--------|
| Step 1 | Extract `jiraIssueKey` from `chunkMapping` | During load |
| Step 2 | Display issue key and status | When presenting chunk |
| Step 3A | **Transition to "In Progress"** | BEFORE dispatch |
| Step 5A | **Transition to "Done"** | AFTER review passes |

**Error handling:** Jira errors should NOT block execution unless user chooses to abort. Ask user: Restart MCP / Skip Jira / Retry / Pause.

See `reference.md` for implementation details and error handling patterns.

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
- Skip Jira transitions when jiraTracking is enabled
- Proceed to next chunk without transitioning previous to Done

**ALWAYS:**
- Dispatch to execute-plan-with-subagents for automated mode
- Verify code review before marking complete
- Get user confirmation for mode
- Update plan-meta.json after each chunk
- Transition Jira to "In Progress" BEFORE dispatch (if enabled)
- Transition Jira to "Done" AFTER review passes (if enabled)
- Include Jira fields in executionHistory (if enabled)

---

## Remember

This is an **orchestrator**, not an executor:
- Analyze and recommend (not decide)
- Dispatch to appropriate executor (not execute yourself)
- Track progress (update metadata)
- Handle errors gracefully (provide options)

**See `reference.md` for:** Full AskUserQuestion examples, pseudocode implementations, detailed error handling, example interactions.
