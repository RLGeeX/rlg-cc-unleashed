---
name: execute-plan-with-subagents
description: Automated subagent execution for micro-chunked plans - dispatches fresh subagent per task within orchestrated workflow, code review after each task, progress tracking
---

# Execute Plan With Subagents

## CRITICAL: Agent Selection Rules

**YOU MUST FOLLOW THESE RULES - NO EXCEPTIONS:**

1. **Every task MUST have an Agent field** in the chunk file (e.g., `**Agent:** python-pro`)
2. **Use the specified agent** from the chunk - python-pro, security-engineer, react-specialist, etc.
3. **NEVER use general-purpose for implementation** - it lacks domain expertise and will produce inferior code
4. **If chunk is missing Agent field: STOP and ask user** - don't guess, don't fallback to general-purpose
5. **NEVER abandon this workflow** to "do it yourself" - the orchestrated process exists for quality control

**Why this matters:** Using general-purpose for everything bypasses specialized expertise (security-engineer for security fixes, python-pro for Python code, test-automator for tests). This leads to poor quality code and missed issues.

---

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

### Step 1: Load Chunk and Discover Agents

```
1. Receive chunk info from orchestrator:
   - Chunk file path (e.g., chunk-005-authentication.md)
   - Current chunk number
   - Plan directory

2. Discover available agents (one-time per execution):
   - Read manifest.json
   - Load all agent categories and their agents
   - Build agent registry with IDs and capabilities
   - Cache for this execution

3. Read chunk file (2-3 tasks max, ~300-500 tokens)
4. Parse tasks with all details:
   - Task descriptions
   - **Agent** field (e.g., "python-pro")
   - Files to create/modify
   - Tests required
   - Verification commands
5. Verify dependencies satisfied (check previous chunks complete)
6. Validate agent IDs exist (check against discovered agents)
   - If ANY task is missing Agent field: STOP immediately
   - Report: "Task N missing agent assignment - cannot proceed"
   - Ask user to update chunk file with correct agent
   - NEVER fallback to general-purpose for implementation
7. Select code reviewer agent:
   - Find quality agents with "review" in name/description
   - Prefer: code-reviewer, architect-reviewer, qa-expert
   - Fallback for review ONLY: general-purpose (review is less specialized)
   - Cache for this execution
8. Create TodoWrite with tasks from chunk
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

4. User Confirmation using AskUserQuestion:

   Present context:
   "Chunks N-M can be executed in parallel:

   • Chunk N: [name] - [brief description]
   • Chunk M: [name] - [brief description]
   • Chunk K: [name] - [brief description]

   File conflict analysis: ✓ No overlaps detected

   Time estimate:
   • Sequential: ~45 minutes (3 chunks × 15 min)
   • Parallel: ~15 minutes (all chunks simultaneously)
   • Potential savings: 30 minutes"

   Use AskUserQuestion:
   {
     "questions": [{
       "question": "Proceed with parallel execution of these chunks?",
       "header": "Parallel",
       "multiSelect": false,
       "options": [
         {
           "label": "Yes - Execute in parallel",
           "description": "Run all chunks simultaneously. 3× faster, single code review at end."
         },
         {
           "label": "No - Execute sequentially",
           "description": "Run chunks one at a time with review after each. Slower but more controlled."
         }
       ]
     }]
   }

   If user selects "Yes": Proceed to Step 2A (Parallel Execution)
   If user selects "No": Fall back to Step 2 (Sequential Execution)

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
     Read agent ID from chunk file (e.g., "python-pro")

     Use Task tool with specified agent:

     subagent_type: "[agent-id-from-chunk]"  # e.g., "python-pro"
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

   Select code reviewer agent dynamically:
     1. Read manifest.json quality category
     2. Find agents with "review" in name or description
     3. Prefer: code-reviewer, architect-reviewer, qa-expert
     4. Fallback: general-purpose if no reviewer found

   Use Task tool with selected reviewer agent:

   subagent_type: "[selected-reviewer-agent-id]"  # e.g., "code-reviewer"
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
Read agent ID from task (e.g., "python-pro")

Use Task tool with specified agent:

subagent_type: "[agent-id-from-task]"  # e.g., "python-pro"
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

**D. MANDATORY: Code Review (NO EXCEPTIONS)**

**THIS STEP CANNOT BE SKIPPED. Code review is REQUIRED for every task.**

```
STOP AND VERIFY:
Before proceeding, confirm you have dispatched the implementation subagent
and received its report. If not, go back to Step A.

YOU MUST NOW DISPATCH CODE REVIEWER. There is no path forward without review.
```

```
Select code reviewer agent dynamically:
  1. Read manifest.json quality category
  2. Find agents with "review" in name or description
  3. Prefer: code-reviewer, architect-reviewer, qa-expert
  4. Fallback: general-purpose if no reviewer found

IMPORTANT: If you cannot find a reviewer agent, you MUST:
  - STOP execution
  - Report: "No code reviewer agent available"
  - Do NOT proceed without review

Use Task tool with selected reviewer agent:

subagent_type: "[selected-reviewer-agent-id]"  # e.g., "code-reviewer"
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
3. VERIFY REVIEW DATA EXISTS (MANDATORY):
   - reviewCompleted must be true
   - reviewedBy must have agent name
   - reviewAssessment must be "Ready"
   - If ANY of these missing → DO NOT mark chunk complete
4. Update plan-meta.json:
   - Increment currentChunk
   - Add executionHistory entry WITH REVIEW FIELDS:
     {
       "chunk": N,
       "mode": "automated",
       "startedAt": "2025-11-12T15:00:00Z",
       "completedAt": "2025-11-12T15:08:00Z",
       "duration": 8,
       "subagentInvocations": 7,  // 2 per task (impl + review) + 3 fixes
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
5. Report chunk completion to orchestrator
```

**CRITICAL: Review Fields are REQUIRED**

The following fields MUST be present in executionHistory for a chunk to be considered complete:
- `reviewCompleted`: Must be `true`
- `reviewedBy`: Must contain the reviewer agent name (e.g., "code-reviewer")
- `reviewAssessment`: Must be "Ready" (or "Needs fixes" if issues were resolved)
- `reviewTimestamp`: When review completed

**If review was not performed, you MUST:**
1. NOT update plan-meta.json
2. NOT mark chunk complete
3. Report to orchestrator: `{"status": "review_missing", "error": "Code review was not performed"}`
4. The orchestrator will handle the failure

### Step 4: Return Control

```
Return to execute-plan orchestrator with REVIEW DATA:

{
  "status": "complete",
  "chunk": N,
  "summary": "[what was built]",
  "testsAdded": 6,
  "testsPassing": true,
  "duration": 8,
  "minorIssues": ["list"],

  "reviewData": {
    "reviewCompleted": true,
    "reviewedBy": "code-reviewer",
    "reviewAssessment": "Ready",
    "reviewTimestamp": "2025-11-12T15:07:30Z",
    "criticalIssuesFound": 0,
    "criticalIssuesResolved": 0
  },

  "nextChunk": {
    "number": N+1,
    "name": "chunk-006-session-mgmt",
    "complexity": "complex",
    "recommendation": "supervised"
  }
}
```

**IMPORTANT: The orchestrator will verify reviewData exists.**

If reviewData is missing or incomplete, the orchestrator will:
1. NOT mark chunk complete
2. Fail the Review Verification Gate
3. Ask user how to proceed

**Never return without reviewData unless returning an error status.**

---

## Subagent Prompt Template

**Implementation Subagent (Full Template):**

Note: Subagent type is read from chunk file's **Agent** field for each task.
Examples: `python-pro`, `react-specialist`

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
- Task tool with specialist agents (python-pro, react-specialist, etc. for implementation)
- Task tool with dynamically selected reviewer agent (code-reviewer, architect-reviewer, etc.)
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

[Present context to user]
"Chunks 3-5 can be executed in parallel:

• Chunk 3: User type definitions (2 tasks)
• Chunk 4: Role type definitions (2 tasks)
• Chunk 5: Permission type definitions (2 tasks)

File conflict analysis: ✓ No overlaps detected

Time estimate:
• Sequential: ~45 minutes (3 chunks × 15 min)
• Parallel: ~15 minutes (all chunks simultaneously)
• Potential savings: 30 minutes"

[Use AskUserQuestion - user selects "Yes - Execute in parallel"]

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

**NEVER:**
- **Use general-purpose subagent for implementation tasks** - use the specialized agent from the chunk file
- **Abandon the plan-execute workflow** to "do it yourself" - the workflow exists for quality control
- **Guess an agent** if chunk is missing Agent field - STOP and ask user
- **Skip code review** - review is MANDATORY, there is NO exception
- **Return without reviewData** - orchestrator will reject incomplete results
- **Mark chunk complete without review** - review gate will fail
- Proceed with critical issues unfixed
- Dispatch parallel chunks with file conflicts (check first!)
- Continue with failing tests
- Exceed 2 fix attempts (escalate to human)
- Parallel execute without user confirmation

**ALWAYS:**
- **Read the Agent field from each task** and use that specific agent
- **Use specialized agents**: python-pro for Python, security-engineer for security, test-automator for tests
- **Stop if Agent field missing** - ask user to fix the chunk file
- **Dispatch code reviewer after EVERY task** - no exceptions
- **Include reviewData in return value** - orchestrator requires it
- **Track review fields**: reviewCompleted, reviewedBy, reviewAssessment, reviewTimestamp
- Fresh subagent per task/chunk (no reuse)
- Full task context in prompt (self-contained)
- TDD approach (test first)
- Check parallelizable metadata from plan-meta.json
- Analyze file paths before parallel execution
- Ask user to confirm parallel mode
- Update plan-meta.json after chunk(s) WITH review fields
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
