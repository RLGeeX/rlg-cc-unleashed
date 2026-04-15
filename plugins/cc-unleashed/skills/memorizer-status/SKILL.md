---
name: memorizer-status
description: Shows auto-capture rates, dedup counts, prompt-cache health, and recent captures for the Memorizer integration. Use when the user asks "is memorizer working", "what's been auto-captured", "show memorizer status", or to verify Phase 4.7 auto-capture is healthy.
---

# /memorizer-status — Auto-Capture Observability

## Overview

Report on Memorizer's automatic work: how many memories are being captured per source, how often dedup fires, Haiku prompt-cache efficiency, and a recent-captures list. Makes the auto-capture pipeline observable so the user can tell whether it's actually doing its job.

**Announce at start:** "Checking Memorizer auto-capture status."

**Prerequisite:** Memorizer MCP server registered (`scripts/setup-memory.sh`).

---

## Step 1: Scope the Query

1. Read `cwd` from environment
2. Derive `org/project` — strip `~/prj/`, take first two segments
3. Call `get_project_context(query: "<project>")` to get the project UUID
4. Keep the UUID for scoped queries. If no project matches, fall back to global.

---

## Step 2: Fetch Recent Captures

Pull a recent sample. Filter client-side by `Source:` field — the MCP tool doesn't support `source` as a query param, so we sample and group.

```
search_memories(
  query: "session decision preference pattern risk",
  limit: 50,
  minSimilarity: 0.0,
  projectId: "<uuid>"      # omit for global report
)
```

Parse the plain-text response. For each memory block, extract:
- `Source:` — the capture origin
- `Type:` — memory type
- `Title:`
- `Created:` — ISO datetime
- `Confidence:` — salience proxy

Group by source:
- `stop-hook-synthesis` → auto session synthesis (Phase 4.7, chunks 1-2)
- `memorizer-hooks` → anatomy + bugfix heuristics (Phase 4B)
- `LLM` → manual `/memorize`
- `system` → server-provided baseline memories

Within `stop-hook-synthesis`, further split by tag: `decision | preference | pattern | risk | task | fact`.

---

## Step 3: Fetch Cache-Health Stats

Read the summarizer log for Haiku prompt-cache efficiency:

```bash
LOG="${CLAUDE_PROJECT_DIR:-$(pwd)}/.memorizer/summarize.log"
[[ -f "$LOG" ]] || echo "(no synthesis events logged yet — run a few sessions first)"

tail -200 "$LOG" | grep -E "cache_read_input_tokens|cache_creation_input_tokens"
```

Sum `cache_read_input_tokens` and `cache_creation_input_tokens` over the last N events. Cache hit rate = `read / (read + creation)`. Target: ≥80%.

If the log doesn't exist yet, report "(awaiting first session synthesis event)" — do not error.

---

## Step 4: Format the Report

Emit a single structured message:

```
# Memorizer Status — <workspace/project or "global">

## Captures (sampled from last 50)
- stop-hook-synthesis: <N>  (decision: X, preference: X, pattern: X, risk: X, task: X, fact: X)
- memorizer-hooks:     <N>  (anatomy + bugfix auto-detection)
- LLM (/memorize):     <N>
- system:              <N>  (server seed memories)

## Last 10 auto-captures (synthesis + hooks, newest first)
1. [DECISION] <title> — <relative time>
   <body first 100 chars>
2. ...

## Haiku prompt-cache (last 50 synthesis events)
- cache_read_tokens:   <avg>
- cache_creation:      <avg>
- hit rate:            <pct> (target ≥80%)

## Top 5 most-salient recent memories
1. <title> (salience=<X>, type=<Y>, source=<Z>)
2. ...

## Health
- [✓|✗] Synthesis pipeline active (log file exists)
- [✓|✗] Cache hit rate ≥80%
- [✓|✗] At least 1 auto-capture in last 7 days
```

If any section has no data, print the section with `(none)` so the user can tell whether a pipeline is dormant vs broken.

---

## Step 5: Diagnose If Silent

If both auto sources report 0 captures, check these in order and report the first failing:

| Check | Command | Remediation |
|-------|---------|-------------|
| MCP registered | `claude mcp list \| grep memorizer` | Run `scripts/setup-memory.sh` |
| API key set | `[[ -n $ANTHROPIC_API_KEY ]]` | Export in shell init; synthesis needs it |
| Hook wired | `cat ~/.claude/settings.json \| jq .hooks.Stop` | Verify Stop hook includes `memorizer/stop.sh` |
| Project has UUID | `get_project_context(query: "<project>")` | Create workspace/project via `create_workspace` + `create_project` |
| `.memorizer/` exists in cwd | `ls .memorizer/` | First file read/write in project auto-creates it |

Report the first failing check with the remediation command.

---

## Key Rules

| Rule | Detail |
|------|--------|
| Project scope | Default to current cwd's project; fall back to global if no match |
| Sample size | 50 memories per query is enough for rate observability |
| Cache stats | Read log file; don't re-query Anthropic API |
| Silent diagnostic | If both auto sources are 0, run Step 5 checks and report first failure |
| Honest reporting | If the synthesis log doesn't exist yet, say so — don't fabricate a hit rate |
