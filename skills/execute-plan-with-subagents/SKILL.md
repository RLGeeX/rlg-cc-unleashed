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

### Step 1B: Check for Parallel Execution (if applicable)

Check if chunk is in a parallelizable group from plan-meta.json:
- Analyze file paths for conflicts across group
- If no conflicts: present time savings, ask user confirmation
- If conflicts: fall back to sequential

See `reference.md` for detailed parallel execution flow.

### Step 2: Execute Each Task (Sequential)

**A. Dispatch Implementation Subagent**

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

**B. Get Git SHAs for Review**

```bash
base_sha=$(git rev-parse HEAD~1)
head_sha=$(git rev-parse HEAD)
```

**C. MANDATORY: Code Review (NO EXCEPTIONS)**

**THIS STEP CANNOT BE SKIPPED.**

```
STOP AND VERIFY:
Before proceeding, confirm you have received implementation report.
YOU MUST NOW DISPATCH CODE REVIEWER. There is no path forward without review.
```

Dispatch code reviewer with git range and implementation summary.

**D. Handle Review Feedback**

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
4. Update plan-meta.json with executionHistory entry (see schema below)
5. Report chunk completion to orchestrator

### Step 4: Return Control

Return to orchestrator with **REQUIRED reviewData**:

```json
{
  "status": "complete",
  "chunk": N,
  "summary": "[what was built]",
  "testsAdded": 6,
  "testsPassing": true,
  "duration": 8,
  "reviewData": {
    "reviewCompleted": true,
    "reviewedBy": "code-reviewer",
    "reviewAssessment": "Ready",
    "reviewTimestamp": "2025-11-12T15:07:30Z",
    "criticalIssuesFound": 0,
    "criticalIssuesResolved": 0
  }
}
```

**If reviewData is missing, orchestrator will fail the Review Verification Gate.**

---

## executionHistory Schema

```json
{
  "chunk": N,
  "mode": "automated",
  "startedAt": "2025-11-12T15:00:00Z",
  "completedAt": "2025-11-12T15:08:00Z",
  "duration": 8,
  "subagentInvocations": 7,
  "testsAdded": 6,
  "testsPassing": true,
  "issues": ["minor: could improve error messages"],
  "reviewCompleted": true,
  "reviewedBy": "code-reviewer",
  "reviewAssessment": "Ready",
  "reviewTimestamp": "2025-11-12T15:07:30Z",
  "criticalIssuesFound": 0,
  "criticalIssuesResolved": 0
}
```

---

## Error Handling

| Scenario | Action |
|----------|--------|
| Subagent fails | Try fix subagent once, then report "blocked" to orchestrator |
| Critical issues in review | Dispatch fix subagent, re-review (max 2 attempts) |
| Tests failing | Stop, return "tests_failing" status |
| Missing Agent field | Stop immediately, ask user to fix chunk |
| Review not performed | Return "review_missing" status (DO NOT mark complete) |

---

## Key Features

| Feature | Description |
|---------|-------------|
| Fresh Context | Each subagent gets only current task (~300-500 tokens) |
| Quality Gates | Code review after every task, can't proceed with failing tests |
| Progress Tracking | executionHistory in plan-meta.json with duration, tests, issues |
| Parallel Execution | Multiple chunks simultaneously when independent |

---

## Integration

| Relationship | Description |
|--------------|-------------|
| Called by | execute-plan (orchestrator) |
| Uses | Task tool with specialist agents, test-driven-development skill |
| Updates | plan-meta.json (executionHistory), TodoWrite |
| Pairs with | execute-plan, write-plan |

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

**ALWAYS:**
- Read Agent field from each task and use that specific agent
- Dispatch code reviewer after EVERY task
- Include reviewData in return value
- Track review fields in executionHistory
- Fresh subagent per task/chunk
- TDD approach (test first)

---

## References

See `reference.md` for:
- Parallel execution flow details
- Full subagent prompt templates
- Example execution flows (sequential and parallel)
- Error handling patterns (code examples)
- Cost considerations
- AskUserQuestion templates
