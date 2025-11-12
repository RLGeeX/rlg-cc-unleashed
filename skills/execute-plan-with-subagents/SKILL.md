---
name: execute-plan-with-subagents
description: Automated subagent execution for micro-chunked plans - dispatches fresh subagent per task within orchestrated workflow, code review after each task, progress tracking
---

# Execute Plan With Subagents

## Overview

Automated execution of micro-chunked plans using fresh subagents per task. This skill is called by the execute-plan orchestrator when automated mode is selected. It reads chunk files (2-3 tasks, 300-500 tokens), dispatches implementation and code-review subagents, and tracks progress.

**Core principle:** Fresh subagent per task + automatic code review = fast iteration with quality gates

**Called by:** execute-plan orchestrator (not invoked directly by user)

**Announce at start:** "Executing chunk N with subagents (automated mode)"

---

## The Process

### Step 1: Load Chunk

```
1. Receive chunk info from orchestrator:
   - Chunk file path (e.g., chunk-005-authentication.md)
   - Current chunk number
   - Plan directory
2. Read chunk file (2-3 tasks max, ~300-500 tokens)
3. Parse tasks with all details:
   - Task descriptions
   - Files to create/modify
   - Tests required
   - Verification commands
4. Verify dependencies satisfied (check previous chunks complete)
5. Create TodoWrite with tasks from chunk
```

### Step 2: Execute Each Task with Subagent

For each task (2-3 max per chunk):

**A. Dispatch Implementation Subagent**

```
Use Task tool (general-purpose subagent):

description: "Implement Task N from chunk-005-authentication"

prompt: |
  You are implementing Task N from chunk-005-authentication.md

  ## Task Description
  [Full task text from chunk]

  ## Files to Create/Modify
  [Exact file paths from chunk]

  ## Tests Required
  [Test descriptions from chunk]

  ## Verification Commands
  [Commands with expected output]

  ## Your Job (TDD)
  1. Write failing test first
  2. Run test to verify it fails
  3. Implement minimal code to pass
  4. Run test to verify it passes
  5. Run all verification commands
  6. Commit with conventional commit message
  7. Report back

  ## Working Directory
  [Current working directory]

  ## Report Format
  - What you implemented
  - Files created/modified
  - Tests written
  - Test results (all output)
  - Commit SHA
  - Any issues or concerns
```

**B. Wait for Implementation Report**

Subagent completes and reports back with:
- Implementation summary
- Files changed
- Test results
- Commit SHA

**C. Get Git SHAs for Review**

```bash
# Before implementation (from previous task or chunk start)
base_sha=$(git rev-parse HEAD~1)

# After implementation
head_sha=$(git rev-parse HEAD)
```

**D. Dispatch Code Reviewer Subagent**

```
Use Task tool (code-reviewer agent):

description: "Review Task N implementation"

prompt: |
  You are reviewing the implementation of Task N from chunk-005-authentication.

  ## What Was Implemented
  [From subagent's report]

  ## Plan Requirements
  [Task description from chunk]

  ## Git Range
  Base: [base_sha]
  Head: [head_sha]

  ## Your Job
  1. Review the code changes
  2. Verify requirements met
  3. Check test coverage
  4. Identify issues (Critical/Important/Minor)
  5. Assess overall quality

  ## Report Format
  **Strengths:**
  - [What was done well]

  **Issues:**
  - Critical: [Must fix before continuing]
  - Important: [Should fix before next chunk]
  - Minor: [Nice to have]

  **Assessment:** Ready | Needs fixes | Major concerns
```

**E. Handle Review Feedback**

```python
if review.assessment == "Needs fixes" or review.has_critical_issues():
    # Dispatch fix subagent
    fix_issues(review.critical_issues + review.important_issues)

    # Re-run code reviewer
    verify_fixes()

if review.assessment == "Ready":
    mark_task_complete()
    proceed_to_next_task()
```

### Step 3: Complete Chunk

After all tasks (2-3) in chunk complete:

```
1. Run chunk completion checklist (from chunk file)
2. Verify all tests passing
3. Update plan-meta.json:
   - Increment currentChunk
   - Add executionHistory entry:
     {
       "chunk": N,
       "mode": "automated",
       "startedAt": "2025-11-12T15:00:00Z",
       "completedAt": "2025-11-12T15:08:00Z",
       "duration": 8,
       "subagentInvocations": 7,  // 2 per task (impl + review) + 3 fixes
       "testsAdded": 6,
       "testsPassing": true,
       "issues": ["minor: could improve error messages"]
     }
4. Report chunk completion to orchestrator
```

### Step 4: Return Control

```
Return to execute-plan orchestrator with:
- Chunk N complete: [summary]
- Tests added: 6
- All tests passing: true
- Duration: 8 minutes
- Minor issues: [list]
- Next: chunk-006-session-mgmt (complex - recommend supervised)
```

---

## Subagent Prompt Template

**Implementation Subagent (Full Template):**

```markdown
You are implementing Task N from [chunk-file].

## Context
This is part of a larger feature: [feature-name]
Current chunk: [N of M]
Previous chunks completed: [list]

## Task Description
[Full task text from chunk, verbatim]

## Files to Create/Modify
[Exact paths from chunk]

## Test Requirements
[Test descriptions from chunk]

## Verification Commands
[Commands with expected output]

## Your Job (TDD Approach)

1. **Write the failing test**
   - Create/modify test file
   - Write test that describes expected behavior
   - Run: [test command]
   - Verify: FAIL with expected error

2. **Implement minimal code**
   - Create/modify source files
   - Write simplest code to pass test
   - Follow patterns from design

3. **Verify test passes**
   - Run: [test command]
   - Verify: PASS

4. **Run all verification commands**
   - [Command 1]: [expected output]
   - [Command 2]: [expected output]

5. **Commit your work**
   - git add [files]
   - git commit -m "[conventional commit message]"
   - Get commit SHA

6. **Report back**
   Required format:
   - Implementation: [what you did]
   - Files: [created/modified list]
   - Tests: [what tests you wrote]
   - Test Results: [full output]
   - Commit: [SHA]
   - Issues: [any concerns or problems]

## Working Directory
[Current directory]

## Important
- Follow TDD strictly (test first!)
- Minimal implementation (no gold plating)
- Commit after each test passes
- Report any blockers immediately
```

---

## Key Features

**Fresh Context Per Task:**
- Each subagent gets only the current task (~300-500 tokens)
- No context pollution from previous tasks
- Can hold entire chunk + instructions in context window

**Automatic Quality Gates:**
- Code review after every task
- Fix loops for critical/important issues
- Can't proceed with failing tests

**Progress Tracking:**
- executionHistory in plan-meta.json
- Duration, test counts, issue tracking
- Subagent invocation counts (for cost analysis)

**Fast Iteration:**
- No human waiting between tasks
- Parallel-safe (fresh subagent = no conflicts)
- Continuous progress within chunk

---

## When to Use This Skill

**Called by orchestrator when:**
- User selects "automated" mode
- Chunk complexity is "simple" or "medium"
- User wants fast, unattended execution

**Not used when:**
- User selects "supervised" mode
- Chunk complexity is "complex"
- User wants to review each step

---

## Error Handling

**If subagent fails:**
```python
if subagent.failed():
    log_failure(task, subagent.error)

    # Try fix subagent once
    try_fix = dispatch_fix_subagent(task, error)

    if try_fix.failed():
        # Stop, report to orchestrator
        return {
            "status": "blocked",
            "task": task,
            "error": error,
            "recommendation": "Switch to supervised mode for this task"
        }
```

**If code review finds critical issues:**
```python
max_fix_attempts = 2

for attempt in range(max_fix_attempts):
    dispatch_fix_subagent(issues)
    re_review = dispatch_reviewer()

    if re_review.assessment == "Ready":
        break
else:
    # After 2 attempts, escalate
    return {
        "status": "needs_human",
        "issues": issues,
        "recommendation": "Human review required"
    }
```

**If tests fail:**
```python
if test_results.failed():
    # Don't proceed - this is a blocker
    return {
        "status": "tests_failing",
        "output": test_results.output,
        "recommendation": "Fix tests before continuing"
    }
```

---

## Integration with Other Skills

**Called by:**
- **execute-plan** (orchestrator) - dispatches this skill for automated execution

**Uses:**
- Task tool with general-purpose subagents (for implementation)
- Task tool with code-reviewer agent (for quality checks)
- **test-driven-development** (subagents follow TDD)

**Updates:**
- plan-meta.json (executionHistory)
- TodoWrite (task progress)

**Pairs with:**
- **execute-plan** (the orchestrator)
- **write-plan** (creates the chunks this skill executes)

---

## Example Execution Flow

```
Orchestrator: "Execute chunk-005-authentication (3 tasks, automated)"

[Load chunk-005-authentication.md]
[Parse 3 tasks]
[Create TodoWrite: 3 tasks pending]

Task 1: "Add OAuth route handler"
├─ [Dispatch implementation subagent]
├─ Subagent: "Implemented handler, tests pass, commit abc123"
├─ [Get git range: abc122..abc123]
├─ [Dispatch code-reviewer]
├─ Reviewer: "Strengths: good tests. Issues: none. Ready."
└─ [Mark task 1 complete]

Task 2: "Add session management"
├─ [Dispatch implementation subagent]
├─ Subagent: "Added session logic, tests pass, commit def456"
├─ [Dispatch code-reviewer]
├─ Reviewer: "Issues: Important - missing error handling"
├─ [Dispatch fix subagent]
├─ Fix subagent: "Added error handling, commit ghi789"
├─ [Re-dispatch code-reviewer]
├─ Reviewer: "Ready."
└─ [Mark task 2 complete]

Task 3: "Add redirect logic"
├─ [Dispatch implementation subagent]
├─ Subagent: "Added redirects, tests pass, commit jkl012"
├─ [Dispatch code-reviewer]
├─ Reviewer: "Strengths: clean code. Issues: Minor - could add logging. Ready."
└─ [Mark task 3 complete]

[Run chunk checklist]
[All tests passing: ✓]
[Update plan-meta.json: chunk 5 complete, 8 min, 7 subagent calls]

Return to orchestrator:
  "Chunk 5 complete: OAuth authentication working
   Tests: 6 added, all passing
   Duration: 8 minutes
   Minor issues: Could add more logging in redirects
   Next: chunk-006-session-mgmt (complex - recommend supervised)"
```

---

## Cost Considerations

**Subagent invocations per task:**
- 1 implementation subagent
- 1 code-reviewer subagent
- 0-2 fix subagents (if issues found)

**Average: 2-4 subagents per task**

**Per chunk (2-3 tasks):**
- 4-12 subagent invocations
- ~8 minutes execution time
- Catches issues early (cheaper than debugging later)

**Trade-off:**
- More API calls than human-supervised
- But faster iteration and automatic quality checks
- Good for simple/medium chunks, not worth it for complex

---

## Red Flags

**Never:**
- Skip code review (always review after each task)
- Proceed with critical issues unfixed
- Dispatch multiple implementation subagents in parallel (git conflicts)
- Continue with failing tests
- Exceed 2 fix attempts (escalate to human)

**Always:**
- Fresh subagent per task (no reuse)
- Full task context in prompt (self-contained)
- TDD approach (test first)
- Update plan-meta.json after chunk
- Report to orchestrator when complete/blocked

---

## Success Criteria

✅ **Subagent succeeds:** Implements task, tests pass, commit created
✅ **Code review passes:** No critical issues, assessment = "Ready"
✅ **Tests passing:** All verification commands succeed
✅ **Progress tracked:** executionHistory updated in plan-meta.json
✅ **Fast execution:** Chunk complete in 5-15 minutes
✅ **Quality maintained:** Code review catches issues early

---

## Comparison with subagent-driven-development

| Feature | execute-plan-with-subagents | subagent-driven-development |
|---------|----------------------------|----------------------------|
| **Input** | Chunked plans (from write-plan) | Flat plan file |
| **Invocation** | Called by execute-plan orchestrator | Manual user invocation |
| **Metadata** | Updates plan-meta.json | No metadata tracking |
| **Progress** | Chunk-by-chunk with checkpoints | All-at-once |
| **Mode switching** | Part of hybrid workflow | Standalone |
| **Use case** | Orchestrated automation | Quick standalone execution |

**Keep both:** Different use cases, both valuable
