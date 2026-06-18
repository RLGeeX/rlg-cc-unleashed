---
name: ask-coordinator
description: Use when a worker lane hits a STOP it cannot resolve from its own context (a DECIDE/SCOPE/CONSTRAINT/FACT/SEQUENCE question) - POSTs the typed STOP to the broker coordinator-oracle and returns its verdict, removing the human copy-paste relay. Does NOT decide irreversible-apply GO/NO-GO (stays a human one-tap approve).
allowed-tools: Bash, Read, AskUserQuestion
---

# Ask Coordinator

The worker half of the worker↔coordinator channel (ai-broker chunk-003). When a
worker lane reaches a STOP it cannot resolve from its own context, build a typed
STOP envelope, POST it to the standing coordinator-oracle, and act on the verdict —
**no human relaying the question and answer between tabs.**

The broker persists BOTH the STOP and the verdict to the v3 `a2a_messages` table by
construction. This skill does **not** log a2a itself — it just calls the endpoint.

## CRITICAL: automate vs. keep human

**Automate** these query types — call the coordinator, use the verdict directly:

| Type | The question |
|------|--------------|
| `DECIDE` | Pick among options; the coordinator may override the recommendation |
| `SCOPE` | Is X in this chunk? reconcile authored-vs-applied |
| `CONSTRAINT` | Does decision AW8/R26/mit-1/H-series govern X? |
| `FACT` | Pure lookup: repo slug, SA id, lock holder, Jira mapping |
| `SEQUENCE` | Ordering / lock: W19 hold, pull-ahead, apply-vs-merge order |

**Keep human — do NOT call this skill to decide it:** a `GO/NO-GO` on an
**irreversible apply** (`applierIsHuman` / W16). Surface it for a one-tap human
approve (chunk-004, separate). This skill never auto-resolves that gate. If the STOP
is "should I apply this?" on something irreversible, stop and hand it to the human.

## Process

### 1. Classify the STOP

Confirm it is one of the five automated types above. If it is an irreversible-apply
GO/NO-GO, **stop here** and surface it for human approval instead.

### 2. Build the STOP envelope

Reuse the worker's existing "🛑 STOP-and-surface" format. The body must contain:

- **Situation** — what blocked, with the live facts you already have.
- **2–3 options** — the concrete choices.
- **Recommendation** — which option you'd take and why.
- **For an apply only:** the plan shape `N add / M change / K destroy` + the saved
  `tfplan` id, so the coordinator verifies against the real plan.

Write the envelope to a file (e.g. `/tmp/stop-<rid>.md`). See `reference.md` for a
copy-paste template and a worked example per query type.

### 3. Gather the routing fields

The endpoint needs `ticket_id`, `rid`, `stack`, `plan_dir`, `worker_role`. Pull
these from the lane context / `plan-meta.json` in the active plan dir. If any are
unknown, ask the operator before sending — do not guess a ticket id or stack.

### 4. POST to the coordinator

Run the script (do **not** craft the curl by hand):

```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/plugins/cc-unleashed/skills/ask-coordinator/scripts/ask_coordinator.sh \
  --ticket-id RLG-123 \
  --rid run-abc123 \
  --stack rlg \
  --plan-dir .claude/plans/ai-broker \
  --worker-role dev \
  --stop-file /tmp/stop-run-abc123.md
```

`stop_body` may also be piped on stdin instead of `--stop-file`. The script POSTs to
`POST {BROKER_URL}/a2a/coordinator/ask` and prints the verdict.

### 5. Act on the verdict

The verdict carries: chosen option + rationale + binding reminders + any ticket
instruction. Apply it in the lane. On `DECIDE`, the coordinator may pick a different
option than you recommended — that is authoritative; follow it. The exchange is
already in the DB, so no further logging is needed.

## Endpoint contract (broker side already built)

```
POST {BROKER_URL}/a2a/coordinator/ask
request  : { ticket_id, rid, stack, plan_dir, worker_role, stop_body }
response : { verdict }
```

## Config

- `BROKER_URL` — broker base URL (default `http://localhost:8080`, env-overridable
  or `--broker-url`).
- `ASK_TIMEOUT` — curl max time in seconds (default `120`; the oracle verifies live
  `gh`/terraform/repo state before answering, so allow time).

## Error handling

- **Connection failed / `000`**: broker not running or wrong `BROKER_URL`. Confirm
  the broker is up and the URL is reachable from the host.
- **HTTP 422**: bad `worker_role`/surface — fix the routing fields and resend.
- **HTTP 500**: coordinator-side failure; surface to the operator (check broker logs).
- **`--dry-run`**: prints the JSON payload without sending — use to inspect the
  envelope before a real call.

## When NOT to use

- Irreversible-apply `GO/NO-GO` (human gate — chunk-004).
- Questions the lane can answer from its own loaded context (don't relay needlessly).
- Plan authoring or code review (those are the `/arch` and `/test` lanes).

---

## References

See `reference.md` for the STOP envelope template, a worked example per query type,
and the verdict shape.
