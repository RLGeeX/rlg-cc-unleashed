# observability — reference

Detail for the observability skill (ai-broker chunk-010). Read `SKILL.md` first.

## The complete trace

| Layer | Where | What |
|-------|-------|------|
| a2a_messages + inbox | broker DB (chunk-001/003) | source of record: every STOP, verdict, gate |
| `journal.md` | `<plan-dir>/` | run summaries + receipts + postmortems (this skill) |
| `otel.md` | `<plan-dir>/` | token/cost/latency summary (this skill, `--plan-dir`) |
| `<session>.jsonl` | `~/.claude/projects/<slug>/` | full per-session transcript (Claude Code, free) |

Together they answer: what was decided (DB), what shipped + why (journal), what it cost
(otel), and the full step-by-step (transcript).

## `journal.py`

| Subcommand | Args |
|-----------|------|
| `append` | `--plan-dir` `--run-id` `--kind` `--status` `--summary` `--receipts` `--postmortem` `--author` `--timestamp` |
| `show` | `--plan-dir` |

- `--receipts`: JSON object `{claim: {value, source}}`, inline or `@file`. Rendered as a
  markdown table. `source` is the tool output that proves the claim.
- `--summary` / `--postmortem`: inline text or `@file`.
- `--author`: stamped on the postmortem as provenance — **must not be the run's builder**
  (DELTA: the builder never grades itself).
- Entry format: `## <UTC> · <kind> · <status> · rid=<id>` then summary, a receipts table,
  and an attributed postmortem. Appends; never rewrites prior entries.

## `otel.py trace`

| Arg | Meaning |
|-----|---------|
| `[transcript]` | path to a `.jsonl` (default: newest in the project dir) |
| `--project-dir` | transcript dir (default: derived from cwd → `-Users-…-slug`) |
| `--format` | `table` (default) or `json` (OTLP-ish metrics) |
| `--plan-dir` | also append a trace summary to `<plan-dir>/otel.md` |

### Transcript fields used

| Field | Use |
|-------|-----|
| `message.usage.input_tokens` | uncached input |
| `message.usage.output_tokens` | output |
| `message.usage.cache_creation.ephemeral_5m_input_tokens` / `_1h_` | cache writes (5m / 1h) |
| `message.usage.cache_read_input_tokens` | cache reads |
| `message.model` | rate selection |
| `durationMs` | latency |
| `isSidechain` + `agentName` | subagent attribution (`subagent:<name>` vs `main`) |
| `sessionId` | session id |

### Cost rates (per MTok)

| model | input | output | cache-write 5m | cache-write 1h | cache-read |
|-------|------:|-------:|---------------:|---------------:|-----------:|
| opus-4-8 / opus-4-7 | 5.00 | 25.00 | 6.25 | 10.00 | 0.50 |
| sonnet-4-6 | 3.00 | 15.00 | 3.75 | 6.00 | 0.30 |
| haiku-4-5 | 1.00 | 5.00 | 1.25 | 2.00 | 0.10 |
| fable-5 | 10.00 | 50.00 | 12.50 | 20.00 | 1.00 |

cache write = 1.25× input (5m) / 2× input (1h); cache read = 0.1× input. Source: the
`claude-api` skill (cached 2026-06). Cost =
`(in·iR + out·oR + cr·crR + cw5m·w5R + cw1h·w1R) / 1e6`, summed per agent.

## Reasoning capture

Opus 4.7/4.8 default to `display: "omitted"` — transcript thinking blocks are empty.
Run agents with `thinking: {type: "adaptive", display: "summarized"}` so the reasoning
is in the transcript for the postmortem to cite.

## Verified (real, non-destructive)

`otel.py trace` over a live session transcript produced per-session tokens, $-cost, and
latency; `journal.py append`/`show` wrote and rendered a receipts table + attributed
postmortem; `otel --plan-dir` appended an `otel.md` summary.
