---
name: execute-plan
description: Smart orchestrator for chunked plans - auto-detects complexity, detects parallelizable groups, recommends execution mode (parallel/automated/supervised/hybrid), dispatches to appropriate executor, tracks progress
---

# Execute Plan (Smart Orchestrator)

## CRITICAL: You Are an Orchestrator, Not an Implementer

**YOU MUST FOLLOW THESE RULES - NO EXCEPTIONS:**

1. **NEVER implement tasks yourself** - always dispatch to specialized subagents
2. **NEVER use general-purpose subagent for implementation** - use python-pro, security-engineer, etc.
3. **NEVER abandon this workflow** to "do it yourself" - the workflow ensures quality control
4. **ALWAYS dispatch to execute-plan-with-subagents** for automated mode
5. **ALWAYS ensure code review happens** between tasks/chunks

**Why this matters:** When you bypass the workflow and implement things yourself or use general-purpose for everything, you:
- Skip specialized domain expertise (security, Python idioms, testing patterns)
- Skip mandatory code reviews
- Produce lower quality code
- Miss issues that specialized agents would catch

**If you're tempted to "just do it yourself":** STOP. That's the wrong approach. Use the workflow.

---

## Overview

Intelligent execution orchestrator for micro-chunked plans. Analyzes chunk complexity, detects parallelizable groups, checks workspace safety, recommends execution mode, and dispatches to the appropriate executor (subagents for automation, human-in-loop for supervision).

**Core principle:** Right execution mode for each chunk/group based on complexity + parallelization opportunity + user confirmation

**NEW: Parallel Group Detection** - Automatically detects when currentChunk is part of a parallelizable group (from plan-meta.json), loads all chunks in the group, calculates time savings, and offers parallel execution as an option. Dispatches entire chunk group to execute-plan-with-subagents for simultaneous execution.

**Announce at start:**
- Single chunk: "I'm using the execute-plan orchestrator to execute chunk N."
- Parallel group: "I'm using the execute-plan orchestrator to execute chunks N-M in parallel."

---

## Jira Integration (Automatic Tracking)

If `jiraTracking.enabled` is true in plan-meta.json, automatically manage Jira issue transitions:

**On Chunk Start:**
```
1. Check if chunk has jiraIssueKey in plan-meta.json chunkMapping
2. If yes:
   - Transition Jira issue to "In Progress" using MCP Jira tools
   - Update chunk status in chunkMapping: "todo" → "in_progress"
   - Log transition in executionHistory
```

**On Chunk Complete:**
```
1. If chunk has jiraIssueKey:
   - Transition Jira issue to "Done" using MCP Jira tools
   - Update chunk status in chunkMapping: "in_progress" → "done"
   - Add jiraIssueKey to executionHistory entry
   - Log successful transition
```

**On Chunk Failure/Block:**
```
1. If chunk has jiraIssueKey:
   - Keep status as "in_progress" (don't transition to done)
   - Add comment to Jira issue describing the blocker
   - Log in executionHistory with issue details
```

**Error Handling with User Choice:**
```
If Jira MCP connection fails or transition errors:
  Use AskUserQuestion tool:

  Question: "Jira update failed: [error message]. How would you like to proceed?"
  Options:
    - "Restart MCP & Retry" → Save state to TodoList, tell user to run `/mcp restart jira-pcc`
    - "Skip Jira Updates" → Continue execution without Jira tracking
    - "Retry Now" → Retry transition immediately (max 3 attempts)
    - "Pause Execution" → Stop chunk execution to investigate

  If "Restart MCP & Retry":
    - Add to TodoList: "Resume chunk execution after Jira MCP restart"
    - Tell user: "Please run `/mcp restart jira-pcc` then ask me to resume"
    - Exit gracefully

  If "Skip Jira Updates":
    - Continue execution
    - Log skipped updates for later reconciliation

  If "Retry Now":
    - Retry transition (max 3 times with 5-second delays)
    - If all retries fail → Ask again with same options

  If "Pause Execution":
    - Stop execution, preserve chunk state
    - User can investigate and resume manually
```

---

## The Orchestration Flow

### Step 0: Workspace Safety Check

```
If chunk complexity suggests automated mode:
  Check: Am I in a worktree? (git rev-parse --git-dir)

  If NO (in main repo):
    Present context:
    "⚠️  Subagent execution works best in isolated worktree."

    Use AskUserQuestion:
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

  If YES (in worktree):
    ✓ Safe to proceed with subagents
    Continue to Step 1

If supervised mode:
  No worktree required (human reviews each step)
  Continue to Step 1
```

### Step 1: Load & Analyze

```
1. Read plan-meta.json:
   - Get currentChunk number
   - Get totalChunks
   - Get executionConfig (if present)
   - Get executionHistory (to learn from past choices)
   - Get jiraTracking (if present) - check enabled, get chunkMapping

2. Check for parallelizable group (NEW):
   - Read executionConfig.parallelizable (e.g., [[1,2,3], [6,7], [10,11,12]])
   - Is currentChunk in a parallelizable group?
   - If YES:
     * Identify all chunks in the group (e.g., chunks 3,4,5)
     * Check if other chunks in group are still pending
     * Set parallel_execution_candidate = true
     * Store chunk_group = [3, 4, 5]
   - If NO:
     * Set parallel_execution_candidate = false
     * Continue with single chunk execution

3. Load chunk(s):
   - If parallel_execution_candidate:
     * Load ALL chunk files in the group
     * Parse all task details from all chunks
     * Aggregate complexity ratings
   - If single chunk:
     * Load chunk-NNN-name.md (2-3 tasks, ~300-500 tokens)
     * Parse all task details
     * Check chunk metadata (complexity, dependencies, estimated time)

4. Check dependencies:
   - Verify prerequisite chunks complete
   - For parallel groups: ALL chunks in group must have same dependencies satisfied
   - If dependency missing: Stop and report

5. Get complexity rating:
   - From chunk file(s) (if present)
   - From plan-meta.json executionConfig
   - For parallel groups: Use highest complexity in group
   - Or infer from task descriptions:
     * simple: Boilerplate, config, well-defined patterns
     * medium: Business logic with tests, standard CRUD
     * complex: Algorithms, architecture, tricky integration
```

### Step 2: Recommend & Confirm

```
Analyze and recommend execution mode:

Factors:
- Chunk complexity (simple → automated, complex → supervised)
- Parallel execution candidate (from Step 1)
- Worktree status (in worktree → safer for automation)
- User history (from executionHistory - does user prefer automation?)
- Chunk size (2-3 tasks is perfect for automated)

** If parallel_execution_candidate == true: **

Present parallel option using AskUserQuestion:

```
Present context to user:
"Chunks [N-M]: '[Group Description]'
• Chunk N: [name] - [brief description] (X tasks)
• Chunk M: [name] - [brief description] (Y tasks)
• Chunk K: [name] - [brief description] (Z tasks)

Complexity: [SIMPLE/MEDIUM/COMPLEX] (highest in group)
Worktree: [✓ in worktree / ✗ in main repo]
Parallelizable: ✓ Detected in plan-meta.json

Time estimate:
• Sequential: ~45 minutes (3 chunks × 15 min each)
• Parallel: ~15 minutes (all chunks simultaneously)
• Potential savings: 30 minutes"

Then use AskUserQuestion:
{
  "questions": [{
    "question": "How would you like to execute these chunks?",
    "header": "Exec mode",
    "multiSelect": false,
    "options": [
      {
        "label": "Parallel Automated (Recommended)",
        "description": "All chunks run simultaneously with subagents. 3× faster, single code review at end. File conflict check will be performed."
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

** If parallel_execution_candidate == false: **

Present context to user:
"Chunk N: '[Chunk Name]' (X tasks, ~Y tokens)
Complexity: [SIMPLE/MEDIUM/COMPLEX] - [Reason]
Worktree: [✓ in worktree / ✗ in main repo]"

Then use AskUserQuestion:
```
{
  "questions": [{
    "question": "How would you like to execute this chunk?",
    "header": "Exec mode",
    "multiSelect": false,
    "options": [
      {
        "label": "Automated (Recommended for [COMPLEXITY])",
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

**User Preference Handling:**
```
# Map user's selection to mode
mode_mapping = {
  "Automated (Recommended for [COMPLEXITY])": "automated",
  "Supervised": "supervised",
  "Hybrid": "hybrid"
}

mode = mode_mapping[user_selection]

# Remember choice for future
update_user_preference_pattern(mode, complexity)
```

### Step 3: Transition Jira & Dispatch to Executor

**Before Dispatch - Transition Jira to "In Progress":**
```
If jiraTracking.enabled:
  For each chunk about to execute:
    1. Find jiraIssueKey in chunkMapping
    2. If found:
       Try: Transition Jira issue to "In Progress" using MCP Jira tools
       If MCP error: Use error handling (see Jira Integration section above)
       If success:
         - Update status in chunkMapping: "todo" → "in_progress"
         - Log transition
    3. If not found:
       - Log warning (issue key missing)
       - Continue execution
```

Based on confirmed mode:

**Mode: Parallel Automated (NEW)**
```
Invoke execute-plan-with-subagents skill with chunk group:
- Pass: chunk_group = [3, 4, 5], plan directory
- Skill will:
  * Load all chunks in the group
  * Perform file conflict analysis
  * Ask user confirmation (with time estimate)
  * Dispatch all chunks in parallel if approved
  * Return when all chunks complete or blocked
- Handle result (see Step 4)
- Note: Multiple chunks will be marked complete simultaneously
```

**Mode: Automated (Sequential)**
```
Invoke execute-plan-with-subagents skill:
- Pass: chunk file path, chunk number, plan directory
- Skill dispatches subagents for each task sequentially
- Returns when chunk complete or blocked
- Handle result (see Step 4)
```

**Mode: Supervised**
```
Traditional execution (human-in-loop):

For each task (2-3 max):
  1. Mark task as in_progress in TodoWrite
  2. Present task details to user
  3. Follow each step exactly with user
  4. Run verifications
  5. Mark task complete
  6. Brief pause for feedback

After all tasks:
  - Run chunk completion checklist
  - Update plan-meta.json
  - Proceed to Step 4
```

**Mode: Hybrid**
```
Smart delegation per task:

Analyze each task:
  if task_is_simple(task):
    dispatch_subagent(task)
    review_result()
  else:
    execute_supervised(task)

This gives speed for simple tasks,
control for complex ones.
```

### Step 4: Track, Transition Jira & Report

After chunk complete (or blocked):

**If Chunk Complete - Transition Jira to "Done":**
```
If jiraTracking.enabled:
  For each completed chunk:
    1. Find jiraIssueKey in chunkMapping
    2. If found:
       Try: Transition Jira issue to "Done" using MCP Jira tools
       If MCP error: Use error handling (see Jira Integration section above)
       If success:
         - Update status in chunkMapping: "in_progress" → "done"
         - Add jiraIssueKey to executionHistory entry
         - Log successful completion
    3. If not found:
       - Log warning (issue key missing)
       - Continue
```

**If Chunk Blocked - Add Jira Comment:**
```
If jiraTracking.enabled && chunk blocked:
  1. Find jiraIssueKey in chunkMapping
  2. If found:
     - Add comment to Jira issue: "Blocked: [error description]"
     - Keep status as "in_progress"
     - Log blocker in executionHistory
```

**Update plan-meta.json:**
```json
{
  "currentChunk": N+1,
  "status": "in-progress",

  "jiraTracking": {
    "enabled": true,
    "project": "PROJ",
    "chunkMapping": [
      {"chunk": N, "jiraIssueKey": "PROJ-101", "status": "done"}
    ]
  },

  "executionHistory": [
    ...previous entries...,
    {
      "chunk": N,
      "jiraIssueKey": "PROJ-101",
      "mode": "automated",
      "startedAt": "2025-11-12T15:00:00Z",
      "completedAt": "2025-11-12T15:08:00Z",
      "duration": 8,
      "subagentInvocations": 6,
      "testsAdded": 6,
      "testsPassing": true,
      "issues": ["minor: could improve error messages"]
    }
  ]
}
```

**Report to User:**
```
"✅ Chunk N complete: [summary of what was built]

📊 Stats:
- Duration: 8 minutes
- Tests added: 6
- All tests passing: ✓
- Issues: Minor - could add more logging

📍 Progress: N of M chunks complete (X%)

⏭️  Next: Chunk N+1 - '[Name]' (complexity: [MEDIUM])
   Recommendation: [Automated / Supervised]

Use /cc-unleashed:plan-next to continue
Use /cc-unleashed:plan-status for detailed progress"
```

**If Blocked:**
```
Present context:
"⚠️  Chunk N blocked at task X:
[Error/issue description]

Recommendation: [Switch to supervised mode / Fix manually / Revisit plan]"

Use AskUserQuestion:
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

### Step 5: Complete All Chunks

When currentChunk > totalChunks:

```
"🎉 All chunks complete! Feature implemented.

📊 Summary:
- Total chunks: M
- Total duration: X hours
- Tests added: Y
- Execution modes used:
  * Automated: N chunks
  * Supervised: M chunks
  * Hybrid: K chunks

Invoking finishing-a-development-branch skill..."

[Use finishing-a-development-branch skill]
- Verify all tests passing
- Present options: Create PR / Merge / Continue working
```

---

## Complexity Detection Logic

**Auto-detect complexity from task descriptions:**

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

**Track patterns to improve recommendations:**

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

## Context Management

**Key advantages:**
- Only 1 micro-chunk loaded at a time (~300-500 tokens vs old 1,500-2,000)
- Smaller chunks = easier analysis and mode selection
- Previous chunks unloaded after completion
- Can pause/resume at any chunk boundary
- executionHistory provides learning context without bloating current context

---

## When to Stop and Ask

**STOP immediately when:**
- Chunk dependency not satisfied
- Chunk file not found or malformed
- User cancels mid-execution
- Automated mode blocked (subagent failed after retries)
- Tests failing after chunk completion

**Ask user when:**
- Ambiguous complexity (could be medium or complex)
- First time seeing this plan (no history to learn from)
- Previous chunk had issues (maybe switch modes?)
- Workspace not ideal for automated (not in worktree)

---

## Resuming Interrupted Plans

```
1. Read plan-meta.json → currentChunk = N
2. Check executionHistory:
   - Was chunk N-1 completed successfully?
   - What mode was used?
   - Were there issues?
3. Load chunk-N
4. Recommend mode (considering history)
5. Continue normal flow
```

---

## Error Handling

**Automated mode blocked:**
```
if automated_executor.status == "blocked":
    Present context:
    "Automated execution blocked: [reason]"

    Use AskUserQuestion:
    {
      "questions": [{
        "question": "How would you like to handle this automation failure?",
        "header": "Recovery",
        "multiSelect": false,
        "options": [
          {
            "label": "Switch to supervised mode",
            "description": "Continue this chunk with human-in-loop for better control."
          },
          {
            "label": "Debug and retry",
            "description": "Let me investigate the issue and attempt automated execution again."
          },
          {
            "label": "Pause and review plan",
            "description": "Stop to manually investigate and potentially revise the plan."
          }
        ]
      }]
    }
```

**Tests failing:**
```
if tests.failed():
    Present context:
    "⚠️  Tests failing after chunk completion

    Output:
    [test output]

    This is a blocker."

    Use AskUserQuestion:
    {
      "questions": [{
        "question": "How would you like to fix the failing tests?",
        "header": "Fix tests",
        "multiSelect": false,
        "options": [
          {
            "label": "Let me debug and fix",
            "description": "I'll investigate the test failures and attempt to fix them automatically."
          },
          {
            "label": "Review together (supervised)",
            "description": "We'll review the failures together and fix them step-by-step."
          },
          {
            "label": "Pause for manual investigation",
            "description": "Stop execution so you can investigate and fix the issues manually."
          }
        ]
      }]
    }
```

---

## Integration with Other Skills

**Calls:**
- **execute-plan-with-subagents** (for automated mode)
- **using-git-worktrees** (if creating worktree recommended)
- **finishing-a-development-branch** (after all chunks complete)

**Called by:**
- `/cc-unleashed:plan-next` command
- brainstorming skill (after plan created, if user wants to execute)

**Reads:**
- plan-meta.json (from write-plan skill)
- chunk-NNN-name.md files (from write-plan skill)

**Updates:**
- plan-meta.json (currentChunk, executionHistory)
- TodoWrite (task progress within chunk)

---

## Example Interactions

### Example 1: Simple Chunk (Automated)

```
User: /cc-unleashed:plan-next

Orchestrator: "Chunk 1: 'Project Initialization' (2 tasks, ~400 tokens)
Complexity: SIMPLE (boilerplate setup)
Worktree: ✓ in .worktrees/feature-auth/
Recommendation: Automated execution

Options:
A) Automated (subagents, fast)
B) Supervised (human-in-loop, slower)
C) Hybrid

Your choice? [A/B/C, or 'auto']"

User: auto

Orchestrator: "Executing with subagents..."
[Invokes execute-plan-with-subagents]
[8 minutes later]

"✅ Chunk 1 complete: Project structure initialized, config files created
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
Recommendation: Supervised execution (safer for architectural decisions)

Options:
A) Automated (risk: subagent may not handle complexity well)
B) Supervised (safer, full control)
C) Hybrid (I'll help, but with checkpoints)

Your choice? [A/B/C, or 'auto']"

User: B

Orchestrator: "Executing in supervised mode. I'll guide you through each step.

Task 1: Design rate limiter with token bucket algorithm
[Presents step 1]
Ready to proceed?"

[Human-in-loop execution continues]
```

### Example 3: Parallel Execution (NEW)

```
User: /cc-unleashed:plan-next

Orchestrator: [Loads chunk 3]
[Detects chunk 3 is in parallelizable group [3,4,5]]
[Loads all chunks in group]

"Chunks 3-5: 'Type Definitions'
• Chunk 3: User types (2 tasks, ~350 tokens)
• Chunk 4: Role types (2 tasks, ~350 tokens)
• Chunk 5: Permission types (2 tasks, ~400 tokens)

Complexity: SIMPLE (independent type definitions)
Worktree: ✓ in .worktrees/descope-mgmt/
Parallelizable: ✓ Detected in plan-meta.json

Time estimate:
• Sequential: ~45 minutes (3 chunks × 15 min each)
• Parallel: ~15 minutes (all chunks simultaneously)
• Potential savings: 30 minutes

Recommendation: Parallel Automated Execution

Options:
A) Parallel Automated (all chunks run simultaneously with subagents)
   → 3× faster, single code review at end
   → File conflict check will be performed

B) Sequential Automated (chunks run one at a time)
   → Slower but safer, review after each chunk

C) Supervised (you execute with my help, review every step)
   → Full control and visibility

Your choice? [A/B/C, or 'auto']"

User: A

Orchestrator: "Executing chunks 3-5 in parallel with subagents..."
[Invokes execute-plan-with-subagents with chunk_group=[3,4,5]]
[Skill performs file conflict check]
[Skill asks user confirmation]
User confirms parallel execution
[15 minutes later]

"✅ Chunks 3-5 complete (parallel execution): Type definitions implemented
Duration: 15 min (saved 30 min vs sequential) | Tests: 6 added, all passing
Files: 6 created (3 source + 3 test)
Progress: 5 of 24 chunks (21%)

Next: Chunk 6 - 'API Handlers' (medium)
Recommendation: Sequential Automated

/cc-unleashed:plan-next to continue"
```

### Example 4: Not in Worktree (Warning)

```
User: /cc-unleashed:plan-next

Orchestrator: "Chunk 5: 'OAuth Handler' (3 tasks, ~450 tokens)
Complexity: MEDIUM (business logic with tests)
Worktree: ✗ NOT in worktree (in main repo: ~/pcc/core/pcc-descope-mgmt/)

⚠️  You're not in an isolated worktree. Automated subagent execution works best
in isolation to avoid affecting your main workspace."

[Use AskUserQuestion]
{
  "questions": [{
    "question": "How would you like to proceed without a worktree?",
    "header": "Worktree",
    "multiSelect": false,
    "options": [
      {
        "label": "Create worktree now (Recommended)",
        "description": "Use the using-git-worktrees skill to create an isolated workspace, then proceed with automated execution."
      },
      {
        "label": "Execute here anyway",
        "description": "Continue with automated mode in the current directory. Your code, your choice."
      },
      {
        "label": "Use supervised mode",
        "description": "Switch to human-in-loop execution, which is safer without worktree isolation."
      }
    ]
  }]
}

User selects: "Create worktree now (Recommended)"

Orchestrator: "Creating worktree..."
[Invokes using-git-worktrees]
[Copies plan to worktree]
"Worktree ready at .worktrees/phase1-week1/
Now in worktree. Proceeding with automated execution..."
```

---

## Success Criteria

✅ **Complexity detected:** Accurate analysis of simple/medium/complex
✅ **Smart recommendations:** Mode suggestions make sense for complexity
✅ **User confirmation:** Always ask, never assume
✅ **Proper dispatch:** Calls correct executor for chosen mode
✅ **Progress tracked:** executionHistory updated after each chunk
✅ **Learning:** Recommendations improve based on user patterns
✅ **Safety checks:** Warns about workspace issues
✅ **Error handling:** Graceful handling of blocks/failures

---

## Commands Reference

**Called by:**
- `/cc-unleashed:plan-next` → Loads and executes next chunk
- `/cc-unleashed:plan-status` → Shows progress (doesn't execute)
- `/cc-unleashed:plan-resume` → Resumes interrupted plan

**Calls:**
- `/cc-unleashed:worktree` → Creates isolated workspace if needed

---

## Red Flags

**NEVER:**
- **Implement tasks yourself** - you are an orchestrator, dispatch to subagents
- **Use general-purpose for implementation** - use specialized agents (python-pro, security-engineer, etc.)
- **Abandon this workflow** - the orchestrated process exists for quality control
- **Skip code reviews** - every task/chunk needs review before proceeding
- Execute without user confirmation of mode
- Proceed with unmet dependencies
- Skip complexity analysis
- Ignore workspace safety (silently proceed without warning)
- Continue with failing tests
- Lose executionHistory (always update plan-meta.json)

**ALWAYS:**
- **Dispatch to execute-plan-with-subagents** for automated mode
- **Ensure specialized agents are used** for each task type
- **Verify code review happened** before marking chunk complete
- Analyze complexity first
- Recommend appropriate mode
- Get user confirmation
- Check workspace safety for automated mode
- Update plan-meta.json after each chunk
- Report clear progress and next steps

---

## Remember

This is an **orchestrator**, not an executor. Your job is to:
- ✅ Analyze and recommend (not decide)
- ✅ Dispatch to appropriate executor (not execute yourself)
- ✅ Track progress (update metadata)
- ✅ Learn from patterns (improve recommendations)
- ✅ Handle errors gracefully (provide options)

The actual execution happens in:
- execute-plan-with-subagents (automated)
- Traditional flow in this skill (supervised)

**FINAL WARNING:** If you find yourself writing implementation code directly instead of dispatching to subagents, you are doing it wrong. STOP and use the workflow. The orchestrated process with specialized agents and code reviews exists because it produces better results than "doing it yourself."
