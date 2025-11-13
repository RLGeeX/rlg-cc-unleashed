---
name: execute-plan-with-subagents
description: Automated subagent execution for micro-chunked plans - dispatches fresh subagent per task within orchestrated workflow, code review after each task, progress tracking
---

# Execute Plan With Subagents

## Overview

Automated execution of micro-chunked plans using fresh subagents per task or chunk. This skill is called by the execute-plan orchestrator when automated mode is selected. It reads chunk files (2-3 tasks, 300-500 tokens), dispatches implementation and code-review subagents, and tracks progress.

**Core principle:** Fresh subagent per task/chunk + automatic code review = fast iteration with quality gates

**NEW: Parallel Execution** - Automatically detects when multiple chunks can run simultaneously (based on plan-meta.json parallelizable groups), checks for file conflicts, asks user confirmation, and dispatches chunks in parallel for 3× faster execution.

**Called by:** execute-plan orchestrator (not invoked directly by user)

**Announce at start:**
- Sequential: "Executing chunk N with subagents (automated mode)"
- Parallel: "Executing chunks N-M in parallel with subagents (automated mode)"

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

### Step 1B: Check for Parallel Execution Opportunity (NEW)

Before executing tasks, check if this chunk is part of a parallelizable group:

```
1. Read plan-meta.json executionConfig.parallelizable
   Example: "parallelizable": [[1,2,3], [6,7], [10,11,12]]

2. Is currentChunk in a parallelizable group?
   - If chunk 3, check if in group with [1,2,3]
   - Determine if other chunks in group are pending

3. If parallelizable group detected:
   A. Analyze file paths for conflicts:
      - Read all chunk files in the group
      - Extract file_path fields from all tasks
      - Check for overlaps (same file in multiple chunks)

   B. If NO file conflicts detected:
      - Calculate time savings (parallel vs sequential)
      - Prepare user confirmation (see below)

   C. If file conflicts detected:
      - Skip parallel execution
      - Fall back to sequential (Step 2)
      - Log: "Chunks N-M have file conflicts, executing sequentially"

4. User Confirmation (using AskUserQuestion):
   "Chunks N-M can be executed in parallel:

   • Chunk N: [name] - [brief description]
   • Chunk M: [name] - [brief description]
   • Chunk K: [name] - [brief description]

   File conflict analysis: ✓ No overlaps detected

   Time estimate:
   • Sequential: ~45 minutes (3 chunks × 15 min)
   • Parallel: ~15 minutes (all chunks simultaneously)
   • Potential savings: 30 minutes

   Proceed with parallel execution?"

   Options:
   - Yes: Proceed to Step 2A (Parallel Execution)
   - No: Fall back to Step 2 (Sequential Execution)

5. Track choice in executionHistory for learning
```

**Safety Checks:**
- ✅ Verify all chunks in group have same dependencies satisfied
- ✅ Ensure we're in a git worktree (safer for parallel work)
- ✅ All previous chunks must be complete
- ⚠️ If any safety check fails → fall back to sequential

---

### Step 2A: Parallel Chunk Execution (NEW)

When user approves parallel execution for chunks N-M:

```
1. Get base commit SHA (before any work starts)
   base_sha = git rev-parse HEAD

2. Create TodoWrite with ALL tasks from ALL chunks
   Example for chunks [3,4,5]:
   - Chunk 3, Task 1: Create UserType
   - Chunk 3, Task 2: Add tests for UserType
   - Chunk 4, Task 1: Create RoleType
   - Chunk 4, Task 2: Add tests for RoleType
   - Chunk 5, Task 1: Create PermissionType
   - Chunk 5, Task 2: Add tests for PermissionType

3. Dispatch ALL chunks in parallel (single message with multiple Task calls)

   For chunk N in parallel_group:
     Use Task tool (general-purpose subagent):

     description: "Implement chunk-N-[name] (parallel execution)"

     prompt: |
       You are implementing chunk-N-[name] as part of parallel execution.

       ## Chunk Overview
       [Chunk description]

       ## All Tasks in This Chunk
       [Task 1 full details]
       [Task 2 full details]
       [Task 3 full details if present]

       ## Your Job (TDD for each task)
       For EACH task:
       1. Write failing test first
       2. Run test to verify it fails
       3. Implement minimal code to pass
       4. Run test to verify it passes
       5. Commit with conventional message

       After ALL tasks complete:
       6. Run all verification commands
       7. Report back with summary

       ## Report Format
       - Tasks completed: [list]
       - Files created/modified: [full list]
       - Tests written: [count and descriptions]
       - Test results: [all output]
       - Commits: [SHAs for each task]
       - Final HEAD: [final commit SHA]
       - Issues: [any concerns]

4. Wait for ALL subagents to complete (parallel execution)
   - Track which chunks have completed
   - Collect all reports
   - Monitor for failures

5. After all chunks complete, get final commit SHA
   head_sha = git rev-parse HEAD

6. Dispatch SINGLE unified code reviewer

   Use Task tool (code-reviewer agent):

   description: "Review parallel execution of chunks N-M"

   prompt: |
     You are reviewing parallel execution of chunks N-M.

     ## What Was Implemented
     **Chunk N:** [summary from subagent N]
     **Chunk M:** [summary from subagent M]
     **Chunk K:** [summary from subagent K]

     ## Git Range
     Base: [base_sha]
     Head: [head_sha]

     ## Your Job
     1. Review all code changes from all chunks
     2. Verify no integration issues between chunks
     3. Check test coverage across all chunks
     4. Identify issues (Critical/Important/Minor)
     5. Assess overall quality

     ## Report Format
     **Strengths:**
     - [What was done well across all chunks]

     **Issues:**
     - Critical: [Must fix before continuing]
     - Important: [Should fix soon]
     - Minor: [Nice to have]

     **Integration concerns:**
     - [Any issues from parallel development]

     **Assessment:** Ready | Needs fixes | Major concerns

7. Handle review feedback (same as Step 2E)
   - If critical issues → dispatch fix subagent
   - Re-review until "Ready"
   - Max 2 fix attempts

8. Update plan-meta.json for ALL chunks
   - Mark chunks N, M, K as complete
   - Update currentChunk to next after group
   - Add executionHistory entries:
     {
       "chunks": [N, M, K],
       "mode": "automated-parallel",
       "startedAt": "2025-11-13T10:00:00Z",
       "completedAt": "2025-11-13T10:15:00Z",
       "duration": 15,
       "subagentInvocations": 4,  // 3 impl + 1 review
       "testsAdded": 12,
       "testsPassing": true,
       "timeSaved": 30,  // vs sequential
       "issues": []
     }

9. Mark all tasks complete in TodoWrite

10. Return to orchestrator with combined summary
```

**Error Handling for Parallel Execution:**
```python
if any_subagent.failed():
    # Stop all parallel execution
    # Report which chunks succeeded vs failed
    return {
        "status": "partially_complete",
        "completed_chunks": [N, M],
        "failed_chunk": K,
        "error": error,
        "recommendation": "Complete failed chunk in supervised mode"
    }
```

---

### Step 2: Execute Each Task with Subagent (Sequential)

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
- Each subagent gets only the current task or chunk (~300-500 tokens)
- No context pollution from previous work
- Can hold entire chunk + instructions in context window

**Automatic Quality Gates:**
- Code review after every task (sequential) or chunk group (parallel)
- Fix loops for critical/important issues
- Can't proceed with failing tests

**Progress Tracking:**
- executionHistory in plan-meta.json
- Duration, test counts, issue tracking
- Subagent invocation counts (for cost analysis)
- Time savings tracking for parallel execution

**Fast Iteration:**
- Sequential: No human waiting between tasks
- Parallel: Multiple chunks execute simultaneously
- Intelligent mode selection based on file conflicts
- User confirmation before parallel execution

**Parallel Execution (NEW):**
- Detects parallelizable groups from plan-meta.json
- Analyzes file paths to prevent conflicts
- Dispatches multiple chunks simultaneously
- Unified code review across all parallel work
- 3× faster for independent chunks (e.g., type definitions)

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

## Example Execution Flows

### Example 1: Sequential Execution (Original)

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

### Example 2: Parallel Execution (NEW)

```
Orchestrator: "Execute chunk-003 (type definitions)"

[Load chunk-003-user-types.md]
[Check plan-meta.json: parallelizable groups = [[3,4,5]]]
[Detected: Chunk 3 is in parallelizable group with chunks 4 and 5]

[Load chunks 3, 4, 5 and analyze file paths]
Chunk 3: src/types/user.py, tests/types/test_user.py
Chunk 4: src/types/role.py, tests/types/test_role.py
Chunk 5: src/types/permission.py, tests/types/test_permission.py

[File conflict check: ✓ No overlaps]

[AskUserQuestion]
"Chunks 3-5 can be executed in parallel:

• Chunk 3: User type definitions (2 tasks)
• Chunk 4: Role type definitions (2 tasks)
• Chunk 5: Permission type definitions (2 tasks)

File conflict analysis: ✓ No overlaps detected

Time estimate:
• Sequential: ~45 minutes (3 chunks × 15 min)
• Parallel: ~15 minutes (all chunks simultaneously)
• Potential savings: 30 minutes

Proceed with parallel execution?"

User: Yes

[Get base SHA: abc000]
[Create TodoWrite: 6 tasks from all 3 chunks]

[Dispatch 3 subagents in parallel - single message]
├─ Chunk 3 subagent: Working on user types...
├─ Chunk 4 subagent: Working on role types...
└─ Chunk 5 subagent: Working on permission types...

[15 minutes later - all complete]

Chunk 3 result:
  - Created src/types/user.py
  - Created tests/types/test_user.py
  - 2 tests passing
  - Commits: def111, def222

Chunk 4 result:
  - Created src/types/role.py
  - Created tests/types/test_role.py
  - 2 tests passing
  - Commits: ghi333, ghi444

Chunk 5 result:
  - Created src/types/permission.py
  - Created tests/types/test_permission.py
  - 2 tests passing
  - Commits: jkl555, jkl666

[Get head SHA: jkl666]
[Dispatch unified code reviewer]
├─ Reviewer: "Reviewing git range abc000..jkl666"
├─ Reviewer: "All 3 type definitions look good"
├─ Reviewer: "No integration issues detected"
└─ Reviewer: "Assessment: Ready"

[Update plan-meta.json: chunks 3, 4, 5 complete]
executionHistory: {
  "chunks": [3, 4, 5],
  "mode": "automated-parallel",
  "duration": 15,
  "subagentInvocations": 4,
  "testsAdded": 6,
  "testsPassing": true,
  "timeSaved": 30
}

Return to orchestrator:
  "Chunks 3-5 complete (parallel execution): Type definitions implemented
   Tests: 6 added, all passing
   Duration: 15 minutes (saved 30 minutes vs sequential)
   Files: 6 created (3 source + 3 test)
   Next: chunk-006-api-handlers (medium - recommend automated)"
```

---

## Cost Considerations

### Sequential Execution

**Subagent invocations per task:**
- 1 implementation subagent
- 1 code-reviewer subagent
- 0-2 fix subagents (if issues found)

**Average: 2-4 subagents per task**

**Per chunk (2-3 tasks):**
- 4-12 subagent invocations
- ~8 minutes execution time
- Catches issues early (cheaper than debugging later)

### Parallel Execution (NEW)

**Subagent invocations for chunk group:**
- N implementation subagents (1 per chunk, dispatched simultaneously)
- 1 unified code-reviewer (reviews all chunks together)
- 0-2 fix subagents (if issues found)

**Example: 3 chunks in parallel**
- 3 implementation subagents (run simultaneously)
- 1 code reviewer (after all complete)
- Total: 4 subagent invocations
- Time: ~15 minutes (vs 45 minutes sequential)
- Cost: Same API calls, but 3x faster wall-clock time

**Trade-off Analysis:**
- **Sequential:** More API calls per chunk (review after each task)
- **Parallel:** Fewer total reviews (1 unified review)
- **Wall time:** Parallel is N× faster for N chunks
- **API costs:** Parallel slightly cheaper (fewer review calls)
- **Risk:** Parallel has integration risk (multiple chunks at once)

**Best for:**
- Sequential: Complex chunks, tight dependencies
- Parallel: Simple/medium chunks, independent work (type definitions, config files)

---

## Red Flags

**Never:**
- Skip code review (always review after task/chunk)
- Proceed with critical issues unfixed
- Dispatch parallel chunks with file conflicts (check first!)
- Continue with failing tests
- Exceed 2 fix attempts (escalate to human)
- Parallel execute without user confirmation

**Always:**
- Fresh subagent per task/chunk (no reuse)
- Full task context in prompt (self-contained)
- TDD approach (test first)
- Check parallelizable metadata from plan-meta.json
- Analyze file paths before parallel execution
- Ask user to confirm parallel mode
- Update plan-meta.json after chunk(s)
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
