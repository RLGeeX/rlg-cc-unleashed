---
name: execute-plan
description: Smart orchestrator for chunked plans - auto-detects complexity, recommends execution mode (parallel/automated/supervised/hybrid), dispatches to executor, tracks progress with mandatory code review. Supports --persist flag for autonomous looping.
---

# Execute Plan (Smart Orchestrator)

## Usage

```
/cc-unleashed:execute-plan [plan-path] [options]

Options:
  --persist              Enable persistence mode (loops until complete or limits reached)
  --max-iterations N     With --persist: max iterations (default: 10)
  --timeout M            With --persist: max runtime in minutes (default: 60)
```

**Example with persistence:**
```
/cc-unleashed:execute-plan .claude/plans/my-feature --persist --max-iterations 20 --timeout 120
```

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
- **Persistent Automated** (if --persist flag or user requests)

### Step 2.5: Persistence Mode Setup (if --persist)

If `--persist` flag is provided or user selects "Persistent Automated":

1. **Initialize persist-execute state file** at `~/.claude/persist-execute-state.json`:
   ```json
   {
     "active": true,
     "planPath": "<plan-path>",
     "prompt": "Continue executing plan...",
     "iteration": 0,
     "maxIterations": <--max-iterations or 10>,
     "timeoutSeconds": <--timeout * 60 or 3600>,
     "startTime": <current unix timestamp>,
     "completionPromise": "PERSIST_COMPLETE",
     "mode": "automated"
   }
   ```

2. **Warn user about persistence implications:**
   - Will loop until all chunks complete OR limits reached
   - Use `/cc-unleashed:persist-cancel` to stop early
   - Recommend using git worktree for safety

3. **Confirm safeguard settings** before proceeding

4. **Stop hook will automatically:**
   - Block exit attempts
   - Re-feed execution prompt
   - Track iterations
   - Enforce timeout

**When persistence completes:** Clean up state file and report summary.

### Step 3: Jira Transition to "In Progress" (if enabled)

If `jiraTracking.enabled`:
1. Look up `jiraIssueKey` for current chunk in `jiraTracking.chunkMapping`
2. **Check if this is the first chunk of a phase** (from `phases` array in plan-meta.json)
   - If yes: Also transition the **parent story** to "In Progress"
   - Parent story key is in `jiraTracking.stories` (e.g., `stories.week1`, `stories.week2`)
3. **MUST transition chunk issue to "In Progress" BEFORE dispatching executor**
4. If transition fails: Ask user (Retry / Skip Jira / Abort)

```
# If first chunk of phase, transition parent story first:
mcp__jira__transitionJiraIssue(parentStoryKey, "In Progress")

# Always transition chunk issue:
mcp__jira__transitionJiraIssue(jiraIssueKey, "In Progress")
```

**If no Jira tracking:** Skip to Step 4.

### Step 4: Dispatch to Executor

| Mode | Action |
|------|--------|
| Parallel Automated | Invoke execute-plan-with-subagents with chunk_group |
| Sequential Automated | Invoke execute-plan-with-subagents with single chunk |
| Supervised | Execute human-in-loop: present each task, run verifications |
| Hybrid | Subagent for simple tasks, supervised for complex |

### Step 5: Review Verification Gate (MANDATORY)

**Before marking chunk complete, verify:**

- [ ] Code reviewer was dispatched
- [ ] Review report received with assessment
- [ ] Assessment is "Ready" (not "Major concerns")
- [ ] All critical issues resolved

**If gate fails:** STOP. Present errors. Options: Run review now / Fix and re-review / Abort.

**There is NO option to skip the review gate.**

### Step 6: Push Code (autonomous mode)

After review passes, push the code:
```bash
git push origin <branch>
```

**Push Policy:** In autonomous/automated mode, the user has implicitly approved pushing by choosing that mode. The base system rule "don't push without asking" does NOT apply during autonomous execution - that rule is for ad-hoc work, not planned execution.

**When to push:**
- Automated mode: Always push after review passes
- Supervised mode: Ask user before pushing
- If CI/CD is configured: Push triggers deployment

### Step 7: Jira Transition to "Done" (if enabled)

If `jiraTracking.enabled` and review passed:
1. Transition chunk issue to "Done"
2. **Check if this is the last chunk of a phase** (from `phases` array in plan-meta.json)
   - If yes: Also transition the **parent story** to "Done"
   - Parent story key is in `jiraTracking.stories` (e.g., `stories.week1`, `stories.week2`)

```
# Always transition chunk issue:
mcp__jira__transitionJiraIssue(jiraIssueKey, "Done")

# If last chunk of phase, also transition parent story:
mcp__jira__transitionJiraIssue(parentStoryKey, "Done")
```

If transition fails: Ask user (Retry / Skip / Continue anyway)

**If no Jira tracking:** Skip to Step 8.

### Step 8: Update Metadata

Update plan-meta.json:
- Increment `currentChunk` to N+1
- Add `executionHistory` entry with: chunk, mode, duration, tests, review fields, Jira fields (if enabled)

See `reference.md` for full executionHistory schema.

### Step 9: Report to User

Present summary: stats, progress, Jira status, next chunk recommendation.

### Step 10: Plan Complete

When currentChunk > totalChunks:
- Report completion summary
- Invoke finishing-a-development-branch skill

---

## Jira Integration (MANDATORY when enabled)

If `jiraTracking.enabled` in plan-meta.json, Jira transitions are **woven into the main flow**:

| Step | Action | Timing |
|------|--------|--------|
| Step 1 | Extract `jiraIssueKey` from `chunkMapping` | During load |
| Step 1 | Check if chunk is first/last in phase | During load |
| Step 2 | Display issue key and status | When presenting chunk |
| Step 3 | **Transition chunk to "In Progress"** | BEFORE dispatch |
| Step 3 | **Transition parent story to "In Progress"** (if first chunk of phase) | BEFORE dispatch |
| Step 6 | **Push code** (autonomous mode) | AFTER review passes |
| Step 7 | **Transition chunk to "Done"** | AFTER push |
| Step 7 | **Transition parent story to "Done"** (if last chunk of phase) | AFTER push |

**Parent Story Transitions:**
- First chunk of phase → parent story to "In Progress"
- Last chunk of phase → parent story to "Done"
- Parent story keys are in `jiraTracking.stories` (e.g., `week1`, `week2`)
- Phase boundaries are in `phases` array in plan-meta.json

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

**Calls:** execute-plan-with-subagents, using-git-worktrees, finishing-a-development-branch, persist-execute (when --persist)

**Called by:** /cc-unleashed:plan-next, /cc-unleashed:plan-resume

**With --persist:** Uses Stop hook at `hooks/persist-stop-hook.sh` for autonomous looping

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
- Push code after review passes (autonomous mode)
- Get user confirmation for mode
- Update plan-meta.json after each chunk
- Transition chunk to "In Progress" BEFORE dispatch (if Jira enabled)
- Transition chunk to "Done" AFTER review passes (if Jira enabled)
- Transition parent story to "In Progress" when starting first chunk of phase
- Transition parent story to "Done" when completing last chunk of phase
- Check phases array to determine first/last chunk boundaries
- Include Jira fields in executionHistory (if enabled)

---

## Remember

This is an **orchestrator**, not an executor:
- Analyze and recommend (not decide)
- Dispatch to appropriate executor (not execute yourself)
- Track progress (update metadata)
- Handle errors gracefully (provide options)

**See `reference.md` for:** Full AskUserQuestion examples, pseudocode implementations, detailed error handling, example interactions.
