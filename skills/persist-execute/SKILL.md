---
name: persist-execute
description: Execute a chunked plan with Ralph Wiggum-style persistence - blocks exit attempts and continues iteratively until completion or safeguard limits reached
---

# Persist-Execute: Autonomous Plan Execution with Persistence

Wraps plan execution with a Stop hook that prevents premature exit, enabling long-running autonomous workflows that self-correct across multiple iterations.

## CRITICAL SAFEGUARDS

**This skill enables EXTREME PERSISTENCE.** Safeguards are MANDATORY:

| Safeguard | Default | Purpose |
|-----------|---------|---------|
| `--max-iterations` | 10 | Hard stop after N iterations |
| `--timeout` | 60 | Maximum runtime in minutes |
| `--completion-promise` | PERSIST_COMPLETE | Output this to signal done |

**WARNING:** Without safeguards, Claude will loop indefinitely. ALWAYS set reasonable limits.

---

## Usage

### Basic (with safeguards)

```
/cc-unleashed:persist-execute .claude/plans/my-feature --max-iterations 15 --timeout 90
```

### Full options

```
/cc-unleashed:persist-execute <plan-path> [options]

Options:
  --max-iterations N       Maximum iterations before forced stop (default: 10)
  --timeout M              Maximum runtime in minutes (default: 60)
  --completion-promise T   Text that signals completion (default: PERSIST_COMPLETE)
  --supervised             Pause for confirmation between iterations
```

---

## How It Works

### The Persistence Loop

```
1. User runs /cc-unleashed:persist-execute with plan path
2. Skill creates state file (~/.claude/persist-execute-state.json)
3. Skill begins plan execution via execute-plan
4. Claude works on tasks, makes progress
5. Claude attempts to exit (task complete or blocked)
6. Stop hook intercepts exit attempt
7. Hook checks: iteration < max AND time < timeout?
8. If yes: Block exit, re-feed prompt with context
9. Claude sees previous work (files, git history)
10. Claude continues where it left off
11. Repeat until: completion promise OR max iterations OR timeout
12. Hook allows exit, state file cleaned up
```

### Self-Correction Pattern

Each iteration, Claude:
- Reads modified files from previous iterations
- Reviews git commits and test results
- Identifies what's working and what's broken
- Continues implementation or fixes issues
- Builds on accumulated progress

---

## Workflow Steps

### Step 1: Validate Plan

```
1. Check plan exists at <plan-path>/plan-meta.json
2. Verify plan status is "ready" or "in-progress"
3. Confirm user understands persistence implications
```

### Step 2: Configure Safeguards

Present to user with AskUserQuestion:

```
Persist-Execute Configuration

Plan: [plan-name]
Chunks: [current/total]
Estimated complexity: [from plan-meta.json]

Safeguard settings:
- Max iterations: [--max-iterations or default 10]
- Timeout: [--timeout or default 60] minutes
- Completion signal: [--completion-promise or "PERSIST_COMPLETE"]

This will enable autonomous looping until completion or limits reached.
Proceed?
```

Options:
- Start with these settings
- Modify safeguards
- Use supervised mode (pause between iterations)
- Cancel

### Step 3: Initialize State

Create `~/.claude/persist-execute-state.json`:

```json
{
  "active": true,
  "planPath": ".claude/plans/my-feature",
  "prompt": "Continue executing the plan...",
  "iteration": 0,
  "maxIterations": 10,
  "timeoutSeconds": 3600,
  "startTime": 1705123456,
  "completionPromise": "PERSIST_COMPLETE",
  "mode": "automated"
}
```

### Step 4: Begin Execution

Build the execution prompt:

```
You are executing a chunked plan with persistence enabled.

Plan: [plan-path]
Current chunk: [N of M]
Mode: Automated with persistence

INSTRUCTIONS:
1. Read plan-meta.json to understand current state
2. Execute the current chunk via execute-plan skill
3. After each chunk, check tests and review
4. Continue to next chunk if previous passes
5. When ALL chunks complete, output: PERSIST_COMPLETE

SAFEGUARDS ACTIVE:
- Iteration [X] of [max-iterations]
- Timeout: [remaining] minutes
- To cancel early: Output PERSIST_COMPLETE

If blocked or stuck:
- Document what's blocking
- Attempt alternative approaches
- After [max-iterations/2] attempts, summarize status

BEGIN EXECUTION
```

### Step 5: Monitor Progress

The stop hook handles continuation automatically. Between iterations:

1. Hook increments iteration counter
2. Hook checks safeguards (time, iterations)
3. If continuing: provides context about progress
4. If stopping: records exit reason

### Step 6: Completion

When execution ends (any reason):

1. Read final state from state file
2. Present completion summary:
   - Total iterations used
   - Total time elapsed
   - Exit reason (completion/timeout/max_iterations)
   - Chunks completed
   - Test status
3. Clean up state file
4. Invoke finishing-a-development-branch if plan complete

---

## State File Schema

```json
{
  "active": true,
  "planPath": ".claude/plans/feature-name",
  "prompt": "Execution prompt with plan details",
  "iteration": 5,
  "maxIterations": 15,
  "timeoutSeconds": 5400,
  "startTime": 1705123456,
  "completionPromise": "PERSIST_COMPLETE",
  "mode": "automated",
  "exitReason": null,
  "history": [
    {"iteration": 1, "timestamp": 1705123500, "action": "started chunk 1"},
    {"iteration": 2, "timestamp": 1705123800, "action": "completed chunk 1, started chunk 2"}
  ]
}
```

---

## Cancellation

### Via Completion Promise

Output the completion promise text in your response:

```
All tasks complete. Tests passing. Documentation updated.

PERSIST_COMPLETE
```

### Via Cancel Command

```
/cc-unleashed:persist-cancel
```

This deactivates the state file and allows normal exit.

---

## Best Practices

### 1. Set Realistic Limits

```
# Small feature (1-2 chunks)
--max-iterations 5 --timeout 30

# Medium feature (3-5 chunks)
--max-iterations 15 --timeout 90

# Large feature (5+ chunks)
--max-iterations 30 --timeout 180
```

### 2. Include Escape Instructions in Plan

Add to your plan's instructions:

```
If blocked for more than 3 iterations:
- Document the blocker in .claude/status/brief.md
- List attempted solutions
- Output PERSIST_COMPLETE with status "BLOCKED"
```

### 3. Use Worktrees

Always execute in a git worktree for safety:

```
/cc-unleashed:worktree my-feature
cd ../my-feature-worktree
/cc-unleashed:persist-execute .claude/plans/my-feature
```

### 4. Monitor Costs

For long-running executions, check API costs periodically. The skill logs iteration counts to help estimate spend.

---

## Integration

**Calls:** execute-plan, execute-plan-with-subagents, finishing-a-development-branch

**Uses:** Stop hook at `hooks/persist-stop-hook.sh`

**State:** `~/.claude/persist-execute-state.json`

---

## Red Flags

**NEVER:**
- Run without safeguards (max-iterations, timeout)
- Use on production branches (always use worktree)
- Set max-iterations > 50 without good reason
- Ignore timeout warnings

**ALWAYS:**
- Confirm safeguard settings with user
- Provide clear completion criteria
- Include escape instructions in prompts
- Clean up state file on completion

---

## Troubleshooting

### Hook not triggering

Check plugin is properly installed: `/plugin list`

Known issue: Exit code 2 hooks may not work via plugins (Issue #10412). This implementation uses JSON response format instead.

### Infinite loop

If stuck in loop:
1. Output completion promise: `PERSIST_COMPLETE`
2. Or run: `/cc-unleashed:persist-cancel`
3. Or manually delete: `~/.claude/persist-execute-state.json`

### State file corruption

If state file is corrupted:
```bash
rm ~/.claude/persist-execute-state.json
```

---

## Sources

- [Ralph Wiggum: Autonomous Loops](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Stop Hook Bug #10412](https://github.com/anthropics/claude-code/issues/10412)
