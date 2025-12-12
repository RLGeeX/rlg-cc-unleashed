# Execute Plan - Reference Documentation

Detailed examples, pseudocode, and edge cases for the execute-plan skill.

## Table of Contents

1. [Pre-Execution Checklist Implementation](#pre-execution-checklist-implementation)
2. [AskUserQuestion Templates](#askuserquestion-templates)
3. [Complexity Detection Logic](#complexity-detection-logic)
4. [User Preference Learning](#user-preference-learning)
5. [Jira Integration Details](#jira-integration-details)
6. [Review Verification Implementation](#review-verification-implementation)
7. [Example Interactions](#example-interactions)
8. [plan-meta.json Schema](#plan-metajson-schema)

---

## Pre-Execution Checklist Implementation

```python
def pre_execution_checklist(plan_meta, chunk_number):
    errors = []

    # 1. Plan Validity
    if plan_meta.status == "pending":
        errors.append("BLOCKER: Plan status is 'pending' - was plan reviewed? Run write-plan validation first.")

    if not plan_meta.planReview or plan_meta.planReview.assessment != "Ready":
        errors.append("BLOCKER: Plan was not reviewed by architect-reviewer. Cannot execute unreviewed plan.")

    # 2. Chunk Validity
    chunk_file = f"chunk-{chunk_number:03d}-*.md"
    if not chunk_file_exists(chunk_file):
        errors.append(f"BLOCKER: Chunk file not found: {chunk_file}")

    tasks = parse_chunk_tasks(chunk_file)
    for task in tasks:
        if not task.has_agent_field():
            errors.append(f"BLOCKER: Task '{task.name}' missing Agent field. Fix chunk file first.")

    # 3. Previous Chunk Review (critical!)
    if chunk_number > 1:
        prev_entry = get_execution_history_entry(chunk_number - 1)
        if not prev_entry:
            errors.append(f"BLOCKER: No execution history for chunk {chunk_number - 1}. Was it executed?")
        elif not prev_entry.get("reviewCompleted"):
            errors.append(f"BLOCKER: Chunk {chunk_number - 1} was NOT reviewed. Code review is mandatory.")
        elif prev_entry.get("reviewAssessment") == "Major concerns":
            errors.append(f"BLOCKER: Chunk {chunk_number - 1} review had 'Major concerns'. Must resolve before continuing.")

    # 4. Dependencies
    chunk_deps = get_chunk_dependencies(chunk_file)
    for dep in chunk_deps:
        if not is_chunk_complete(dep):
            errors.append(f"BLOCKER: Dependency chunk {dep} is not complete.")

    return errors
```

---

## AskUserQuestion Templates

### Checklist Failed

```json
{
  "questions": [{
    "question": "How would you like to resolve these blockers?",
    "header": "Blockers",
    "multiSelect": false,
    "options": [
      {
        "label": "Fix and retry",
        "description": "I'll fix the issues, then run /cc-unleashed:plan-next again."
      },
      {
        "label": "Skip check (DANGEROUS)",
        "description": "Proceed anyway. WARNING: This bypasses quality gates and may cause issues."
      },
      {
        "label": "Abort execution",
        "description": "Stop execution and investigate the issues manually."
      }
    ]
  }]
}
```

### Worktree Warning

```json
{
  "questions": [{
    "question": "How would you like to proceed without a worktree?",
    "header": "Worktree",
    "multiSelect": false,
    "options": [
      {
        "label": "Create worktree now (Recommended)",
        "description": "Use the using-git-worktrees skill to create an isolated workspace first."
      },
      {
        "label": "Execute here anyway",
        "description": "Continue in the current directory. Your code, your choice."
      },
      {
        "label": "Use supervised mode",
        "description": "Switch to human-in-loop execution, safer without worktree."
      }
    ]
  }]
}
```

### Execution Mode (Parallel)

```json
{
  "questions": [{
    "question": "How would you like to execute these chunks?",
    "header": "Exec mode",
    "multiSelect": false,
    "options": [
      {
        "label": "Parallel Automated (Recommended)",
        "description": "All chunks run simultaneously with subagents. 3x faster, single code review at end."
      },
      {
        "label": "Sequential Automated",
        "description": "Chunks run one at a time. Slower but safer, review after each chunk."
      },
      {
        "label": "Supervised",
        "description": "You execute with my help, review every step. Full control and visibility."
      }
    ]
  }]
}
```

### Execution Mode (Single Chunk)

```json
{
  "questions": [{
    "question": "How would you like to execute this chunk?",
    "header": "Exec mode",
    "multiSelect": false,
    "options": [
      {
        "label": "Automated (Recommended for SIMPLE)",
        "description": "Subagents execute all tasks with code review after each. Fast, unattended execution."
      },
      {
        "label": "Supervised",
        "description": "You execute with my help, reviewing every step. Full control and visibility."
      },
      {
        "label": "Hybrid",
        "description": "Subagent handles simple tasks, you review before complex ones. Smart delegation."
      }
    ]
  }]
}
```

### Review Gate Failed

```json
{
  "questions": [{
    "question": "Code review gate failed. How to proceed?",
    "header": "Review Gate",
    "multiSelect": false,
    "options": [
      {
        "label": "Run code review now",
        "description": "Dispatch code reviewer to review the work before proceeding."
      },
      {
        "label": "Fix issues and re-review",
        "description": "Address the critical issues, then run code review again."
      },
      {
        "label": "Abort chunk",
        "description": "Stop execution. Chunk will remain incomplete."
      }
    ]
  }]
}
```

### Chunk Blocked

```json
{
  "questions": [{
    "question": "How would you like to proceed with this blocked chunk?",
    "header": "Next step",
    "multiSelect": false,
    "options": [
      {
        "label": "Continue with supervised mode",
        "description": "Switch to human-in-loop execution for better control over the problem."
      },
      {
        "label": "Let me attempt to fix",
        "description": "I'll try to debug and resolve the issue automatically."
      },
      {
        "label": "Pause and review plan",
        "description": "Stop execution to manually investigate and potentially revise the plan."
      }
    ]
  }]
}
```

### Jira MCP Error

```json
{
  "questions": [{
    "question": "Jira update failed. How would you like to proceed?",
    "header": "Jira Error",
    "multiSelect": false,
    "options": [
      {
        "label": "Restart MCP & Retry",
        "description": "Save state, run /mcp restart jira-pcc, then resume."
      },
      {
        "label": "Skip Jira Updates",
        "description": "Continue execution without Jira tracking."
      },
      {
        "label": "Retry Now",
        "description": "Retry transition immediately (max 3 attempts)."
      },
      {
        "label": "Pause Execution",
        "description": "Stop chunk execution to investigate."
      }
    ]
  }]
}
```

---

## Complexity Detection Logic

```python
def detect_complexity(chunk):
    # Check explicit rating first
    if chunk.has_complexity_rating():
        return chunk.complexity

    # Infer from content
    simple_indicators = [
        "initialize", "create directory", "configure",
        "add dependency", "setup", "install",
        "boilerplate", "scaffold"
    ]

    complex_indicators = [
        "algorithm", "optimization", "rate limiting",
        "concurrency", "async", "distributed",
        "novel approach", "architectural decision"
    ]

    medium_indicators = [
        "API", "handler", "endpoint", "CRUD",
        "business logic", "validation", "integration"
    ]

    # Count indicators
    if any(ind in chunk.text.lower() for ind in complex_indicators):
        return "complex"
    elif any(ind in chunk.text.lower() for ind in simple_indicators):
        return "simple"
    else:
        return "medium"
```

---

## User Preference Learning

```python
# After each chunk
def update_preferences(user_choice, chunk_complexity, outcome):
    prefs = load_user_preferences()

    prefs["history"].append({
        "complexity": chunk_complexity,
        "recommended": recommended_mode,
        "chosen": user_choice,
        "success": outcome.success,
        "duration": outcome.duration
    })

    # Learn patterns
    if chunk_complexity == "simple" and user_choice == "automated":
        prefs["confidence"]["simple_automated"] += 1

    save_preferences(prefs)

# Use when recommending
def get_recommendation(complexity):
    prefs = load_user_preferences()

    # User always chooses automated for simple?
    if complexity == "simple" and prefs["confidence"]["simple_automated"] > 3:
        return "automated", "high_confidence"

    # User prefers supervision for medium?
    if complexity == "medium" and prefs["confidence"]["medium_supervised"] > 2:
        return "supervised", "medium_confidence"

    # Default recommendations
    defaults = {
        "simple": "automated",
        "medium": "automated",  # with review
        "complex": "supervised"
    }

    return defaults[complexity], "default"
```

---

## Jira Integration Details

### On Chunk Start

```
1. Check if chunk has jiraIssueKey in plan-meta.json chunkMapping
2. If yes:
   - Transition Jira issue to "In Progress" using MCP Jira tools
   - Update chunk status in chunkMapping: "todo" -> "in_progress"
   - Log transition in executionHistory
```

### On Chunk Complete

```
1. If chunk has jiraIssueKey:
   - Transition Jira issue to "Done" using MCP Jira tools
   - Update chunk status in chunkMapping: "in_progress" -> "done"
   - Add jiraIssueKey to executionHistory entry
   - Log successful transition
```

### On Chunk Failure/Block

```
1. If chunk has jiraIssueKey:
   - Keep status as "in_progress" (don't transition to done)
   - Add comment to Jira issue describing the blocker
   - Log in executionHistory with issue details
```

---

## Review Verification Implementation

```python
def verify_review_completed(chunk_execution_result):
    """
    MANDATORY: Verify code review was performed before marking chunk complete.
    This gate CANNOT be skipped.
    """
    errors = []

    # Check review was dispatched
    if not chunk_execution_result.review_dispatched:
        errors.append("CRITICAL: Code review was NOT dispatched. Cannot mark chunk complete.")

    # Check review report received
    if not chunk_execution_result.review_report:
        errors.append("CRITICAL: No review report received. Code review is mandatory.")

    # Check review assessment
    if chunk_execution_result.review_assessment == "Major concerns":
        errors.append("CRITICAL: Review found 'Major concerns'. Must resolve before proceeding.")

    # Check critical issues resolved
    if chunk_execution_result.unresolved_critical_issues:
        errors.append(f"CRITICAL: {len(chunk_execution_result.unresolved_critical_issues)} critical issues unresolved.")

    return errors
```

---

## Example Interactions

### Example 1: Simple Chunk (Automated)

```
User: /cc-unleashed:plan-next

Orchestrator: "Chunk 1: 'Project Initialization' (2 tasks, ~400 tokens)
Complexity: SIMPLE (boilerplate setup)
Worktree: ✓ in .worktrees/feature-auth/
Recommendation: Automated execution"

[User selects Automated]

Orchestrator: "Executing with subagents..."
[Invokes execute-plan-with-subagents]
[8 minutes later]

"✓ Chunk 1 complete: Project structure initialized, config files created
Duration: 8 min | Tests: 2 added, all passing
Progress: 1 of 24 chunks (4%)

Next: Chunk 2 - 'Dependencies' (simple)
Recommendation: Automated

/cc-unleashed:plan-next to continue"
```

### Example 2: Complex Chunk (Supervised)

```
User: /cc-unleashed:plan-next

Orchestrator: "Chunk 15: 'Rate Limiting Algorithm' (3 tasks, ~500 tokens)
Complexity: COMPLEX (novel algorithm, concurrency concerns)
Worktree: ✓ in .worktrees/feature-auth/
Recommendation: Supervised execution (safer for architectural decisions)"

[User selects Supervised]

Orchestrator: "Executing in supervised mode. I'll guide you through each step.

Task 1: Design rate limiter with token bucket algorithm
[Presents step 1]
Ready to proceed?"

[Human-in-loop execution continues]
```

### Example 3: Parallel Execution

```
User: /cc-unleashed:plan-next

Orchestrator: [Loads chunk 3]
[Detects chunk 3 is in parallelizable group [3,4,5]]
[Loads all chunks in group]

"Chunks 3-5: 'Type Definitions'
- Chunk 3: User types (2 tasks, ~350 tokens)
- Chunk 4: Role types (2 tasks, ~350 tokens)
- Chunk 5: Permission types (2 tasks, ~400 tokens)

Complexity: SIMPLE (independent type definitions)
Worktree: ✓ in .worktrees/descope-mgmt/
Parallelizable: ✓ Detected in plan-meta.json

Time estimate:
- Sequential: ~45 minutes (3 chunks x 15 min each)
- Parallel: ~15 minutes (all chunks simultaneously)
- Potential savings: 30 minutes"

[User selects Parallel Automated]

"✓ Chunks 3-5 complete (parallel execution): Type definitions implemented
Duration: 15 min (saved 30 min vs sequential) | Tests: 6 added, all passing
Progress: 5 of 24 chunks (21%)"
```

### Example 4: Not in Worktree (Warning)

```
User: /cc-unleashed:plan-next

Orchestrator: "Chunk 5: 'OAuth Handler' (3 tasks, ~450 tokens)
Complexity: MEDIUM (business logic with tests)
Worktree: ✗ NOT in worktree (in main repo)

Warning: You're not in an isolated worktree. Automated subagent execution works best
in isolation to avoid affecting your main workspace."

[User selects "Create worktree now"]

[Invokes using-git-worktrees]
"Worktree ready at .worktrees/phase1-week1/
Now in worktree. Proceeding with automated execution..."
```

---

## plan-meta.json Schema

```json
{
  "feature": "feature-name",
  "created": "2025-11-12T14:30:00Z",
  "totalChunks": 24,
  "currentChunk": 1,
  "status": "ready",
  "description": "Brief description",

  "planReview": {
    "reviewedBy": "architect-reviewer",
    "reviewedAt": "2025-11-12T14:45:00Z",
    "assessment": "Ready",
    "revisionCount": 0
  },

  "phases": [
    {"name": "Setup & Dependencies", "chunks": [1, 2, 3]},
    {"name": "Core Implementation", "chunks": [4, 5, 6, 7, 8]},
    {"name": "Testing & Documentation", "chunks": [9, 10]}
  ],

  "executionConfig": {
    "defaultMode": "auto-detect",
    "chunkComplexity": [
      {"chunk": 1, "complexity": "simple", "reason": "boilerplate setup"},
      {"chunk": 8, "complexity": "medium", "reason": "API client logic"},
      {"chunk": 15, "complexity": "complex", "reason": "rate limiting algorithm"}
    ],
    "reviewCheckpoints": [5, 10, 15, 20, 24],
    "parallelizable": [[1,2,3], [6,7], [10,11,12]],
    "estimatedMinutes": 360
  },

  "jiraTracking": {
    "enabled": true,
    "project": "PROJ",
    "epicKey": "PROJ-100",
    "chunkMapping": [
      {"chunk": 1, "jiraIssueKey": "PROJ-101", "status": "done"},
      {"chunk": 2, "jiraIssueKey": "PROJ-102", "status": "in_progress"}
    ]
  },

  "executionHistory": [
    {
      "chunk": 1,
      "jiraIssueKey": "PROJ-101",
      "jiraTransitionedToInProgress": true,
      "jiraTransitionedToDone": true,
      "mode": "automated",
      "startedAt": "2025-11-12T15:00:00Z",
      "completedAt": "2025-11-12T15:08:00Z",
      "duration": 8,
      "subagentInvocations": 6,
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
  ]
}
```

### Required executionHistory Fields for Review Tracking

| Field | Type | Description |
|-------|------|-------------|
| reviewCompleted | boolean | MUST be true for chunk to be considered complete |
| reviewedBy | string | Agent that performed the review |
| reviewAssessment | string | "Ready" / "Needs fixes" / "Major concerns" |
| reviewTimestamp | string | When review was completed |
| criticalIssuesFound | number | Count of critical issues identified |
| criticalIssuesResolved | number | Count resolved (must equal found) |

### Jira Tracking Fields (when jiraTracking.enabled)

| Field | Type | Description |
|-------|------|-------------|
| jiraIssueKey | string | Issue key for this chunk (e.g., "PROJ-123") |
| jiraTransitionedToInProgress | boolean | True if "In Progress" transition succeeded |
| jiraTransitionedToDone | boolean | True if "Done" transition succeeded |

**Note:** Jira fields are only present when `jiraTracking.enabled` is true in plan-meta.json.
