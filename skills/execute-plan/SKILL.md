---
name: execute-plan
description: Smart orchestrator for chunked plans - auto-detects complexity, recommends execution mode (automated/supervised/hybrid), dispatches to appropriate executor, tracks progress
---

# Execute Plan (Smart Orchestrator)

## Overview

Intelligent execution orchestrator for micro-chunked plans. Analyzes chunk complexity, checks workspace safety, recommends execution mode, and dispatches to the appropriate executor (subagents for automation, human-in-loop for supervision).

**Core principle:** Right execution mode for each chunk based on complexity + user confirmation

**Announce at start:** "I'm using the execute-plan orchestrator to execute chunk N."

---

## The Orchestration Flow

### Step 0: Workspace Safety Check

```
If chunk complexity suggests automated mode:
  Check: Am I in a worktree? (git rev-parse --git-dir)

  If NO (in main repo):
    Warn: "Subagent execution works best in isolated worktree.

    Options:
    A) Create worktree now (recommended) - use using-git-worktrees skill
    B) Execute in current directory anyway (your code, your choice)
    C) Switch to supervised mode instead (safer without worktree)"

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

2. Load chunk-NNN-name.md:
   - Now only 2-3 tasks (~300-500 tokens)
   - Parse all task details
   - Check chunk metadata (complexity, dependencies, estimated time)

3. Check dependencies:
   - Verify prerequisite chunks complete
   - If dependency missing: Stop and report

4. Get complexity rating:
   - From chunk file (if present)
   - From plan-meta.json executionConfig
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
- Worktree status (in worktree → safer for automation)
- User history (from executionHistory - does user prefer automation?)
- Chunk size (2-3 tasks is perfect for automated)

Present to user:
"Chunk N: '[Chunk Name]' (X tasks, ~Y tokens)
Complexity: [SIMPLE/MEDIUM/COMPLEX] - [Reason]
Worktree: [✓ in worktree / ✗ in main repo]
Recommendation: [Automated / Supervised / Hybrid]

Options:
A) Automated (subagents execute all tasks, code review after each)
   → Fast, unattended execution
   → Uses execute-plan-with-subagents skill

B) Supervised (you execute with my help, review every step)
   → Full control and visibility
   → Traditional human-in-loop

C) Hybrid (subagent handles simple tasks, you review before complex ones)
   → Best of both worlds
   → Smart delegation

Your choice? [A/B/C, or 'auto' to follow my recommendation]"
```

**User Preference Handling:**
```
if user_choice == "auto":
    # Follow recommendation
    mode = recommended_mode
elif user_choice in ["A", "B", "C"]:
    mode = map_choice_to_mode(user_choice)
else:
    # Invalid, ask again
    ask_again()

# Remember choice for future
update_user_preference_pattern(mode, complexity)
```

### Step 3: Dispatch to Executor

Based on confirmed mode:

**Mode: Automated**
```
Invoke execute-plan-with-subagents skill:
- Pass: chunk file path, chunk number, plan directory
- Skill dispatches subagents for each task
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

### Step 4: Track & Report

After chunk complete (or blocked):

**Update plan-meta.json:**
```json
{
  "currentChunk": N+1,
  "status": "in-progress",

  "executionHistory": [
    ...previous entries...,
    {
      "chunk": N,
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
"⚠️  Chunk N blocked at task X:
[Error/issue description]

Recommendation: [Switch to supervised mode / Fix manually / Revisit plan]

Options:
A) Continue with supervised mode
B) Let me attempt to fix
C) Pause and review plan"
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
    "Automated execution blocked: [reason]

    Options:
    A) Switch to supervised mode for this chunk
    B) Let me attempt to debug and retry
    C) Pause and review the plan

    Your choice?"
```

**Tests failing:**
```
if tests.failed():
    "⚠️  Tests failing after chunk completion

    Output:
    [test output]

    This is a blocker. Options:
    A) Let me debug and fix
    B) Review together (supervised mode)
    C) Pause and investigate manually

    Your choice?"
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

### Example 3: Not in Worktree (Warning)

```
User: /cc-unleashed:plan-next

Orchestrator: "Chunk 5: 'OAuth Handler' (3 tasks, ~450 tokens)
Complexity: MEDIUM (business logic with tests)
Worktree: ✗ NOT in worktree (in main repo: ~/pcc/core/pcc-descope-mgmt/)
Recommendation: Create worktree OR use supervised mode

⚠️  You're not in an isolated worktree. Automated subagent execution works best
in isolation to avoid affecting your main workspace.

Options:
A) Create worktree now (using-git-worktrees skill)
B) Execute here anyway with automated mode (your code, your choice)
C) Use supervised mode instead (safer without worktree)

Your choice?"

User: A

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

**Never:**
- Execute without user confirmation of mode
- Proceed with unmet dependencies
- Skip complexity analysis
- Ignore workspace safety (silently proceed without warning)
- Continue with failing tests
- Lose executionHistory (always update plan-meta.json)

**Always:**
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
