---
name: execute-plan-with-subagents
description: Automated subagent execution for micro-chunked plans - dispatches fresh subagent per task within orchestrated workflow, code review after each task, progress tracking
---

# Execute Plan With Subagents

## CRITICAL: Agent Selection Rules

**YOU MUST FOLLOW THESE RULES - NO EXCEPTIONS:**

1. **Every task MUST have an Agent field** in the chunk file (e.g., `**Agent:** python-pro`)
2. **Use the specified agent** from the chunk - python-pro, security-engineer, react-specialist, etc.
3. **NEVER use general-purpose for implementation** - it lacks domain expertise
4. **If chunk is missing Agent field: STOP and ask user** - don't guess, don't fallback
5. **NEVER abandon this workflow** to "do it yourself"

---

## Overview

Automated execution of micro-chunked plans using fresh subagents per task or chunk. Called by execute-plan orchestrator when automated mode is selected.

**Core principle:** Fresh subagent per task/chunk + automatic code review = fast iteration with quality gates

**Parallel Execution:** Detects when multiple chunks can run simultaneously (based on plan-meta.json parallelizable groups), checks for file conflicts, asks user confirmation.

**Called by:** execute-plan orchestrator (not invoked directly by user)

---

## The Process

### Step 1: Load Chunk and Discover Agents

1. Receive chunk info from orchestrator (file path, chunk number, plan directory)
2. Discover available agents from manifest.json (one-time per execution)
3. Read chunk file (2-3 tasks max, ~300-500 tokens)
4. Parse tasks: descriptions, **Agent** field, files, tests, verification commands
5. **If ANY task missing Agent field: STOP immediately**
   - Report: "Task N missing agent assignment - cannot proceed"
   - Ask user to update chunk file
   - NEVER fallback to general-purpose
6. Select code reviewer (prefer code-reviewer, architect-reviewer, qa-expert)
7. Create TodoWrite with tasks from chunk

### Step 1B: Check Jira Integration (MANDATORY if enabled)

**If `jiraTracking.enabled` in plan-meta.json:**

1. Extract Jira subtask key for current chunk from `jiraTracking.chunkMapping`
2. Verify issue exists and current status (should be "To Do" or similar)
3. Store `jiraIssueKey` for transitions in Steps 2-3

**If Jira MCP fails:** Use AskUserQuestion: Retry / Skip Jira / Abort

**If no Jira tracking:** Skip to Step 1C

### Step 1C: Check for Parallel Execution (if applicable)

Check if chunk is in a parallelizable group from plan-meta.json:
- Analyze file paths for conflicts across group
- If no conflicts: present time savings, ask user confirmation
- If conflicts: fall back to sequential

See `reference.md` for detailed parallel execution flow.

### Step 2: Execute Each Task (Sequential)

**A. Transition Jira to "In Progress" (MANDATORY if enabled)**

If Jira tracking enabled and this is the first task in chunk:
```
mcp__jira-pcc__transitionJiraIssue(jiraIssueKey, "In Progress")
```

**If transition fails:** Ask user: Retry / Skip Jira / Abort

**B. Dispatch Implementation Subagent**

Read agent ID from task's **Agent** field, then use Task tool:

```
subagent_type: "[agent-id-from-task]"  # e.g., "python-pro"
description: "Implement Task N from chunk-NNN"

prompt: |
  ## Task Description
  [Full task text from chunk]

  ## Files to Create/Modify
  [Exact paths from chunk]

  ## Your Job (TDD)
  1. Write failing test first
  2. Run test to verify it fails
  3. Implement minimal code to pass
  4. Run test to verify it passes
  5. Run verification commands
  6. Commit with conventional message
  7. Report back
```

**C. Get Git SHAs for Review**

```bash
base_sha=$(git rev-parse HEAD~1)
head_sha=$(git rev-parse HEAD)
```

**D. MANDATORY: Code Review (NO EXCEPTIONS)**

**THIS STEP CANNOT BE SKIPPED.**

```
STOP AND VERIFY:
Before proceeding, confirm you have received implementation report.
YOU MUST NOW DISPATCH CODE REVIEWER. There is no path forward without review.
```

Dispatch code reviewer with git range and implementation summary.

**E. Handle Review Feedback**

- If "Needs fixes" or critical issues: dispatch fix subagent, re-review
- Max 2 fix attempts before escalating to human
- Only proceed when assessment = "Ready"

### Step 3: Complete Chunk

After all tasks complete:

1. Run chunk completion checklist
2. Verify all tests passing
3. **VERIFY REVIEW DATA EXISTS (MANDATORY):**
   - reviewCompleted must be true
   - reviewedBy must have agent name
   - reviewAssessment must be "Ready"
   - **If ANY missing → DO NOT mark chunk complete**
4. **Transition Jira to "Done" (MANDATORY if enabled)**
   ```
   mcp__jira-pcc__transitionJiraIssue(jiraIssueKey, "Done")
   ```
   **If transition fails:** Ask user: Retry / Skip Jira / Continue anyway
5. Update plan-meta.json with executionHistory entry (see schema below)
6. Report chunk completion to orchestrator

### Step 4: Return Control

Return to orchestrator with **REQUIRED fields**:
- `status`, `chunk`, `summary`, `testsAdded`, `testsPassing`, `duration`
- `reviewData`: reviewCompleted, reviewedBy, reviewAssessment, reviewTimestamp
- `jiraIssueKey`, `jiraTransitionedToInProgress`, `jiraTransitionedToDone` (if enabled)

**If reviewData is missing, orchestrator will fail the Review Verification Gate.**

See `reference.md` for full return value and executionHistory schemas.

---

## Error Handling

| Scenario | Action |
|----------|--------|
| Subagent fails | Try fix subagent once, then report "blocked" to orchestrator |
| Critical issues in review | Dispatch fix subagent, re-review (max 2 attempts) |
| Tests failing | Stop, return "tests_failing" status |
| Missing Agent field | Stop immediately, ask user to fix chunk |
| Review not performed | Return "review_missing" status (DO NOT mark complete) |
| Jira MCP unavailable | Ask user: Retry / Skip Jira / Abort |
| Jira transition fails | Ask user: Retry / Skip this transition / Pause |
| Jira issue not found | Log warning, continue (don't block on Jira) |

---

## Red Flags

**NEVER:**
- Use general-purpose for implementation tasks
- Skip code review - review is MANDATORY
- Return without reviewData
- Mark chunk complete without review
- Proceed with critical issues unfixed
- Dispatch parallel chunks with file conflicts
- Continue with failing tests
- Skip Jira transitions when jiraTracking is enabled
- Proceed to next chunk without transitioning previous to Done

**ALWAYS:**
- Read Agent field from each task and use that specific agent
- Dispatch code reviewer after EVERY task
- Include reviewData in return value
- Track review fields in executionHistory
- Fresh subagent per task/chunk
- TDD approach (test first)
- Transition Jira to "In Progress" BEFORE implementation (if enabled)
- Transition Jira to "Done" AFTER review passes (if enabled)
- Include jiraIssueKey in executionHistory (if enabled)

---

## References

See `reference.md` for:
- Parallel execution flow details
- Full subagent prompt templates
- Example execution flows (sequential and parallel)
- Error handling patterns (code examples)
- Cost considerations
- AskUserQuestion templates
