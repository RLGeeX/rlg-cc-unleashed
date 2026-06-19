---
name: observability
description: Use to record a lane/deploy run's receipts + an evidence-cited postmortem to a per-plan file journal, and to emit per-session/subagent token, cost, and latency from Claude Code transcripts (OTEL-style). The observability layer over the broker DB record - ai-broker chunk-010.
allowed-tools: Bash, Read
---

# Observability

The DB (inbox + `a2a_messages`) is the durable source of record. This skill layers the
rest on top so every run is inspectable: a **file journal** per plan dir and an
**OTEL-style** token/cost/latency trace from the free Claude Code `.jsonl` transcripts.
A complete trace = **a2a + inbox rows (DB) + journal.md + otel.md + the transcript.**

## 1. File journal — `journal.py`

Each lane/deploy run appends a run summary + receipts + a postmortem to
`<plan-dir>/journal.md`.

```bash
JOURNAL="$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/plugins/cc-unleashed/skills/observability/scripts/journal.py"

python3 "$JOURNAL" append --plan-dir .claude/plans/ai-broker --run-id pr-42 \
  --kind deploy --status success \
  --summary "Shipped PR #42 to dev." \
  --receipts @/tmp/receipts.json \
  --postmortem @/tmp/postmortem.md --author coordinator

python3 "$JOURNAL" show --plan-dir .claude/plans/ai-broker
```

- **Receipts** are `{claim: {value, source}}` (inline JSON or `@file`). Rendered as a
  claim → value → **source** table: every state claim cites the tool output that proves
  it. A fabricated claim has nowhere to hide. The `deploy` skill passes its receipts here
  automatically.
- **Postmortem (Echelon DELTA): the builder never grades itself.** `--author` must be a
  reviewer/coordinator, not the worker that did the run; the journal stamps who authored
  it. A deploy run with no postmortem is flagged for a reviewer to fill in.
- `--kind` = `lane` / `deploy` / `arch` / `dev` / `test` / …; `--status` = `success` /
  `failed` / `aborted` / `blocked`. Timestamps are UTC.

## 2. OTEL trace — `otel.py`

Aggregates per-session and per-subagent tokens, cost, and latency from a Claude Code
transcript. The free source: `~/.claude/projects/<project-slug>/<session>.jsonl`, where
each assistant line carries `message.usage`, `message.model`, `durationMs`, and
`isSidechain`/`agentName` for subagent attribution.

```bash
OTEL="$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/plugins/cc-unleashed/skills/observability/scripts/otel.py"

python3 "$OTEL" trace                          # newest transcript for the cwd's project
python3 "$OTEL" trace --format json            # OTLP-ish metrics JSON
python3 "$OTEL" trace --plan-dir .claude/plans/ai-broker   # also append to <dir>/otel.md
```

Cost uses per-MTok rates (confirmed via the `claude-api` skill): Opus 4.8 $5/$25
(cache-write 5m $6.25 / 1h $10.00, cache-read $0.50), Sonnet 4.6 $3/$15, Haiku 4.5 $1/$5
— cache write = 1.25× (5m) / 2× (1h) input, cache read = 0.1× input. Per-subagent rows
appear when the transcript has sidechain activity.

## Capturing agent reasoning in the trace

Opus 4.7/4.8 omit thinking by default. To make reasoning visible in logs, run agents
with `thinking: {type: "adaptive", display: "summarized"}` — otherwise the transcript's
thinking blocks are empty and the postmortem can't cite the reasoning.

## When to use

- After any lane or deploy run → append a journal entry (the `deploy` skill does this
  for you; lane commands should too).
- To audit cost/latency of a session or a subagent fan-out → `otel.py trace`.
- Reviewer/coordinator writing the per-cycle postmortem → `journal.py append
  --postmortem --author <reviewer>`.

## When NOT to use

- As the source of record — that's the broker DB. This is the readable layer over it.
- To grade your own run — the postmortem author must not be the builder.

---

See `reference.md` for the transcript field reference, the cost-rate table, and the
journal entry format.
