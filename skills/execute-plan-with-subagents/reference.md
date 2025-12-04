# Execute Plan With Subagents - Reference Documentation

Detailed examples, templates, and implementation details for the execute-plan-with-subagents skill.

## Table of Contents

1. [Parallel Execution Details](#parallel-execution-details)
2. [Jira Integration Details](#jira-integration-details)
3. [Subagent Prompt Templates](#subagent-prompt-templates)
4. [Example Execution Flows](#example-execution-flows)
5. [Error Handling Patterns](#error-handling-patterns)
6. [Cost Considerations](#cost-considerations)
7. [AskUserQuestion Templates](#askuserquestion-templates)

---

## Parallel Execution Details

### Checking for Parallel Opportunity

Before executing tasks, check if current chunk is part of a parallelizable group:

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
      - Prepare user confirmation

   C. If file conflicts detected:
      - Skip parallel execution
      - Fall back to sequential
      - Log: "Chunks N-M have file conflicts, executing sequentially"

4. Track choice in executionHistory for learning
```

**Safety Checks:**
- ✅ Verify all chunks in group have same dependencies satisfied
- ✅ Ensure we're in a git worktree (safer for parallel work)
- ✅ All previous chunks must be complete
- ⚠️ If any safety check fails → fall back to sequential

### Parallel Execution Flow

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

     subagent_type: "[agent-id-from-chunk]"
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

6. Dispatch SINGLE unified code reviewer (see Code Review Template below)

7. Handle review feedback (same as sequential)
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
       "subagentInvocations": 4,
       "testsAdded": 12,
       "testsPassing": true,
       "timeSaved": 30,
       "reviewCompleted": true,
       "reviewedBy": "code-reviewer",
       "reviewAssessment": "Ready",
       "reviewTimestamp": "2025-11-13T10:14:30Z"
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

## Jira Integration Details

### When Jira Tracking is Enabled

If `jiraTracking.enabled` in plan-meta.json, the executor MUST:

1. **Step 1B: Extract Jira Issue Key**
   ```python
   jira_key = plan_meta["jiraTracking"]["chunkMapping"]
       .find(m => m.chunk == current_chunk)
       ?.jiraIssueKey

   if not jira_key:
       log_warning("No Jira issue mapped to chunk {current_chunk}")
       # Continue without Jira - don't block execution
   ```

2. **Step 2A: Transition to In Progress (BEFORE first task)**
   ```python
   if jira_key:
       transitions = mcp__jira__getTransitionsForJiraIssue(jira_key)
       in_progress_id = transitions.find(t => t.name == "In Progress")?.id

       if in_progress_id:
           mcp__jira__transitionJiraIssue(jira_key, in_progress_id)
           execution_state["jiraTransitionedToInProgress"] = True
       else:
           # Issue might already be in progress
           log_info("No 'In Progress' transition available for {jira_key}")
   ```

3. **Step 3: Transition to Done (AFTER review passes)**
   ```python
   if jira_key and review_assessment == "Ready":
       transitions = mcp__jira__getTransitionsForJiraIssue(jira_key)
       done_id = transitions.find(t => t.name == "Done")?.id

       if done_id:
           mcp__jira__transitionJiraIssue(jira_key, done_id)
           execution_state["jiraTransitionedToDone"] = True
   ```

### Jira Error Handling

```python
def handle_jira_error(error, operation):
    """Handle Jira MCP errors gracefully."""

    if "MCP" in str(error) or "connection" in str(error).lower():
        # MCP connectivity issue
        return ask_user_question({
            "question": f"Jira {operation} failed: {error}. How to proceed?",
            "options": [
                {"label": "Retry", "description": "Try the Jira operation again"},
                {"label": "Skip Jira", "description": "Continue without Jira tracking"},
                {"label": "Pause", "description": "Stop execution to investigate"}
            ]
        })

    if "not found" in str(error).lower():
        # Issue doesn't exist - log and continue
        log_warning(f"Jira issue not found: {error}")
        return "continue"

    if "transition" in str(error).lower():
        # Invalid transition - issue might be in wrong state
        log_warning(f"Transition failed: {error}")
        return "continue"  # Don't block on transition errors
```

### Parallel Execution with Jira

When executing chunks in parallel with Jira enabled:

```python
# Before parallel dispatch
for chunk in parallel_group:
    jira_key = get_jira_key_for_chunk(chunk)
    if jira_key:
        transition_to_in_progress(jira_key)

# After all chunks complete and review passes
for chunk in parallel_group:
    jira_key = get_jira_key_for_chunk(chunk)
    if jira_key:
        transition_to_done(jira_key)
```

---

## Subagent Prompt Templates

### Implementation Subagent (Full Template)

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

### Code Review Subagent Template

```markdown
You are reviewing the implementation of Task N from [chunk-file].

## What Was Implemented
[From implementation subagent's report]

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

### Unified Review Template (Parallel Execution)

```markdown
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
```

---

## Example Execution Flows

### Example 1: Sequential Execution

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

### Example 2: Parallel Execution

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
  "timeSaved": 30,
  "reviewCompleted": true,
  "reviewedBy": "code-reviewer",
  "reviewAssessment": "Ready"
}

Return to orchestrator:
  "Chunks 3-5 complete (parallel execution): Type definitions implemented
   Tests: 6 added, all passing
   Duration: 15 minutes (saved 30 minutes vs sequential)
   Files: 6 created (3 source + 3 test)
   Next: chunk-006-api-handlers (medium - recommend automated)"
```

---

## Error Handling Patterns

### Subagent Failure

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

### Critical Issues in Review

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

### Test Failures

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

### Parallel Execution

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

## AskUserQuestion Templates

### Parallel Execution Confirmation

```json
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
```

### Parallel Execution Blocked

```json
{
  "questions": [{
    "question": "Parallel chunk failed. How would you like to proceed?",
    "header": "Partial",
    "multiSelect": false,
    "options": [
      {
        "label": "Continue failed chunk in supervised mode",
        "description": "Switch to human-in-loop for the failed chunk only."
      },
      {
        "label": "Retry failed chunk automatically",
        "description": "Dispatch subagent again for the failed chunk."
      },
      {
        "label": "Pause and investigate",
        "description": "Stop execution to manually debug the issue."
      }
    ]
  }]
}
```

### Jira MCP Error

```json
{
  "questions": [{
    "question": "Jira transition failed. How would you like to proceed?",
    "header": "Jira Error",
    "multiSelect": false,
    "options": [
      {
        "label": "Retry transition",
        "description": "Try the Jira transition again (max 3 attempts)."
      },
      {
        "label": "Skip Jira updates",
        "description": "Continue execution without Jira tracking for this chunk."
      },
      {
        "label": "Pause execution",
        "description": "Stop to investigate the Jira connection issue."
      }
    ]
  }]
}
```

---

## Comparison: execute-plan-with-subagents vs subagent-driven-development

| Feature | execute-plan-with-subagents | subagent-driven-development |
|---------|----------------------------|----------------------------|
| **Input** | Chunked plans (from write-plan) | Flat plan file |
| **Invocation** | Called by execute-plan orchestrator | Manual user invocation |
| **Metadata** | Updates plan-meta.json | No metadata tracking |
| **Progress** | Chunk-by-chunk with checkpoints | All-at-once |
| **Mode switching** | Part of hybrid workflow | Standalone |
| **Use case** | Orchestrated automation | Quick standalone execution |

**Keep both:** Different use cases, both valuable
