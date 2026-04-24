---
name: persist-execute
description: Execute a chunked plan with Ralph Wiggum-style persistence - blocks exit attempts and continues iteratively until completion or safeguard limits reached. Use when you want unstoppable plan execution that resists interruption, or say "persist execute", "don't stop until done", or "keep going no matter what".
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
| heartbeat staleness | 30 min | Auto-deactivate if hook hasn't fired in this long (catches crashed sessions) |

**WARNING:** Without safeguards, Claude will loop indefinitely. ALWAYS set reasonable limits.

---

## Project Scoping (v1.11.0+)

State is **scoped to the project's working directory**, not global. The hook computes `sha256(cwd)[:16]` and only reads `~/.claude/persist-execute-state/<that-hash>.json`. Sessions in other projects cannot be hijacked by an active persist-execute elsewhere.

This replaces the pre-1.11 behavior where a single global file at `~/.claude/persist-execute-state.json` caused cross-session hijacks. The legacy global file is auto-archived on first activation after upgrade.

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
2. Skill calls scripts/init.sh, which writes state keyed to current cwd
3. Skill begins plan execution via execute-plan
4. Claude works on tasks, makes progress
5. Claude attempts to exit (task complete or blocked)
6. Stop hook intercepts exit attempt (only for this project)
7. Hook checks: heartbeat fresh AND iteration < max AND time < timeout
   AND completion promise not in last assistant message?
8. If yes: Block exit, increment counter, refresh heartbeat, re-feed prompt
9. Claude sees previous work and continues
10. Repeat until: completion promise OR max iterations OR timeout OR stale heartbeat
11. Hook allows exit, exitReason recorded in state file
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

Run the init script (do **not** write the JSON by hand):

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/persist-execute/scripts/init.sh" \
    --plan-path "<plan-path>" \
    --prompt "Continue executing the plan..." \
    --max-iterations 10 \
    --timeout-minutes 60 \
    --completion-promise "PERSIST_COMPLETE" \
    --mode automated
```

The script:
- Computes the project-scoped state path from current cwd
- Creates `~/.claude/persist-execute-state/` if missing
- Records `cwd`, `sessionId`, `lastHeartbeat`, plus all the safeguard fields
- Archives any legacy global state file (`~/.claude/persist-execute-state.json`) as a one-time migration

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
- Heartbeat: refreshed each iteration; stale > 30min auto-deactivates
- To cancel early: Output PERSIST_COMPLETE on its own line, or run /cc-unleashed:persist-cancel

If blocked or stuck:
- Document what's blocking
- Attempt alternative approaches
- After [max-iterations/2] attempts, summarize status

BEGIN EXECUTION
```

### Step 5: Monitor Progress

The stop hook handles continuation automatically. Between iterations:

1. Hook reads stdin (cwd, session_id, transcript_path) provided by Claude Code
2. Hook locates the state file for current cwd; if missing, allows exit
3. Hook checks (in order): active flag, heartbeat freshness, wall-clock timeout, iteration cap, completion promise in last assistant message
4. If continuing: increments iteration, refreshes `lastHeartbeat`, records `lastSessionId`, emits `{decision: "block", reason: ...}`
5. If stopping: sets `active: false`, records `exitReason`

### Step 6: Completion

When execution ends (any reason):

1. Read final state from `${CLAUDE_PLUGIN_ROOT}/skills/persist-execute/scripts/status.sh`
2. Present completion summary:
   - Total iterations used
   - Total time elapsed
   - Exit reason (`completion_promise` / `timeout` / `max_iterations` / `heartbeat_stale` / `user_cancelled`)
   - Chunks completed
   - Test status
3. Invoke finishing-a-development-branch if plan complete

---

## State File Schema

Path: `~/.claude/persist-execute-state/<sha256(cwd)[:16]>.json`

```json
{
  "active": true,
  "cwd": "/abs/path/to/project",
  "planPath": ".claude/plans/feature-name",
  "prompt": "Execution prompt re-fed each iteration",
  "iteration": 5,
  "maxIterations": 15,
  "timeoutSeconds": 5400,
  "startTime": 1705123456,
  "lastHeartbeat": 1705124100,
  "completionPromise": "PERSIST_COMPLETE",
  "mode": "automated",
  "sessionId": "session-uuid-at-init",
  "lastSessionId": "session-uuid-most-recent-iteration",
  "notes": "",
  "exitReason": null
}
```

`exitReason` is null while active. On deactivation it is one of:
`completion_promise`, `timeout`, `max_iterations`, `heartbeat_stale`, `user_cancelled`.

---

## Cancellation

### Via Completion Promise (output string)

Output the completion promise text in your response. The hook reads the most recent assistant message from the transcript and matches the literal string:

```
All tasks complete. Tests passing. Documentation updated.

PERSIST_COMPLETE
```

The string must appear verbatim. Embedding it in prose works (`"... resulting in PERSIST_COMPLETE."`); appending it on its own line is most reliable.

### Via Cancel Command

```
/cc-unleashed:persist-cancel
```

This calls `scripts/cancel.sh` which deactivates the state file for the current cwd. Add `--all` to cancel every project's active state.

### Via Status Check

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/persist-execute/scripts/status.sh"
```

Lists every state file across projects, showing active/inactive, last-heartbeat age, and exit reason.

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

The worktree's path becomes the cwd, so its state file is distinct from the parent repo's — multiple worktrees of the same repo can persist independently.

### 4. Monitor Costs

For long-running executions, check API costs periodically. The skill logs iteration counts to help estimate spend.

---

## Integration

**Calls:** execute-plan, execute-plan-with-subagents, finishing-a-development-branch

**Uses:** Stop hook at `hooks/persist-stop-hook.sh`

**State:** `~/.claude/persist-execute-state/<sha256(cwd)[:16]>.json` (project-scoped)

**Helpers:** `scripts/{state-path,init,cancel,status,test-isolation}.sh`

---

## Red Flags

**NEVER:**
- Run without safeguards (max-iterations, timeout)
- Use on production branches (always use worktree)
- Set max-iterations > 50 without good reason
- Ignore timeout warnings
- Hand-edit `~/.claude/persist-execute-state/*.json` (use `cancel.sh` instead)

**ALWAYS:**
- Confirm safeguard settings with user
- Provide clear completion criteria
- Include escape instructions in prompts
- Use `init.sh` to create state — never write JSON inline (it would skip migration of legacy file and risk schema drift)

---

## Troubleshooting

### Hook not triggering

Check plugin is properly installed: `/plugin list`

Known issue: Exit code 2 hooks may not work via plugins (Issue #10412). This implementation uses JSON response format instead.

### Hook firing in unrelated projects

This was the v1.10.x bug. As of v1.11.0 the hook is project-scoped — verify by running `scripts/status.sh` and confirming the listed `cwd` matches your project. If you see legacy `~/.claude/persist-execute-state.json` mentioned, run any `init.sh` invocation (it auto-archives) or simply `rm` the file.

### Infinite loop

If stuck in loop:
1. Output completion promise as the final line: `PERSIST_COMPLETE`
2. Or run: `/cc-unleashed:persist-cancel`
3. Worst case (multi-project mass cancel): `${CLAUDE_PLUGIN_ROOT}/skills/persist-execute/scripts/cancel.sh --all`

### State file corruption

```bash
rm "$(${CLAUDE_PLUGIN_ROOT}/skills/persist-execute/scripts/state-path.sh)"
```

### Verifying isolation

A bash test suite ships with the skill:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/persist-execute/scripts/test-isolation.sh"
```

The suite sandboxes `$HOME` to a temp dir and verifies cross-project isolation, heartbeat staleness, max-iterations, completion-promise detection, and legacy migration.

---

## Sources

- [Ralph Wiggum: Autonomous Loops](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Stop Hook Bug #10412](https://github.com/anthropics/claude-code/issues/10412)
