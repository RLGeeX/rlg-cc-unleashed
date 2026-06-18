# ask-coordinator — reference

Detail for the worker→coordinator STOP→verdict channel (ai-broker chunk-003).
Read `SKILL.md` first for the process and the automate-vs-human split.

## STOP envelope template

The `stop_body` reuses the worker's existing "🛑 STOP-and-surface" format. Keep it
typed and terse — the coordinator answers from the planning record, so give it the
live facts and the concrete choices, not prose.

```markdown
🛑 STOP — <TYPE: DECIDE | SCOPE | CONSTRAINT | FACT | SEQUENCE>

**Situation:** <what blocked, with the live facts already in hand>

**Options:**
1. <option A>
2. <option B>
3. <option C — optional>

**Recommendation:** <which option, and why in one line>

<!-- apply-only block: include ONLY when the STOP concerns a terraform apply -->
**Plan shape:** <N> add / <M> change / <K> destroy
**tfplan id:** <saved plan id>
```

The apply block is for the coordinator to verify scope; it does **not** turn this
into a GO/NO-GO. An irreversible-apply go-ahead stays a human one-tap approve
(chunk-004) — do not route that decision through this skill.

## Verdict shape (what comes back)

`AskResponse.verdict` is free text the coordinator composes from the planning record:

- **Chosen option** — which option to take (may differ from your recommendation on a
  `DECIDE`; the coordinator's choice is authoritative).
- **Rationale** — drawn from `plan.md` / `decisions.md` / the conversational history.
- **Binding reminders** — constraints that still apply (e.g. role boundary, a decision id).
- **Ticket instruction** — any Jira transition / note the lane should make.

## Worked example per query type

### DECIDE
```
🛑 STOP — DECIDE

**Situation:** chunk-003 needs the worker to send stop_body. The broker AskRequest
field is `stop_body` (string). Should the skill also send a structured `query_type`?

**Options:**
1. Send only the fields the contract defines (ticket_id, rid, stack, plan_dir,
   worker_role, stop_body).
2. Add a non-contract `query_type` field and hope the broker ignores it.

**Recommendation:** Option 1 — match the AskRequest contract exactly; encode the type
inside stop_body.
```

### SCOPE
```
🛑 STOP — SCOPE

**Situation:** I'm in chunk-003 (worker→coordinator channel). A deploy skill would be
handy but chunk-003's tasks don't mention it.

**Options:**
1. Stay in chunk-003 scope; leave deploy to chunk-005.
2. Pull the deploy skill into this chunk.

**Recommendation:** Option 1 — deploy is a separate chunk.
```

### CONSTRAINT
```
🛑 STOP — CONSTRAINT

**Situation:** Does any decision govern whether the worker logs to a2a_messages itself?

**Options:**
1. Skill logs the exchange to a2a_messages.
2. Skill does not log; relies on the broker.

**Recommendation:** Option 2 — the broker persists both sides by construction.
```

### FACT
```
🛑 STOP — FACT

**Situation:** I need the canonical GitHub slug for the broker repo to set a remote.

**Options:** (lookup — no options)

**Recommendation:** Please confirm the org/repo slug from the planning record.
```

### SEQUENCE
```
🛑 STOP — SEQUENCE

**Situation:** chunk-003 depends on chunk-002. Is chunk-002 done, and may I proceed?

**Options:**
1. Proceed now.
2. Hold until chunk-002 lands.

**Recommendation:** Need the coordinator to confirm chunk-002 status before I proceed.
```

## Endpoint contract (broker side — already built)

`broker/coordinator/api.py`:

```
POST {BROKER_URL}/a2a/coordinator/ask
request  (AskRequest):  { ticket_id, rid, stack, plan_dir, worker_role, stop_body }
response (AskResponse): { verdict }
```

The broker opens a stack session, calls `answer_stop(...)`, commits, and returns the
verdict — persisting both the STOP and the verdict to v3 `a2a_messages` in that one
transaction. Bad role/surface → HTTP 422; internal failure → HTTP 500.

## Script flags

| Flag | Meaning |
|------|---------|
| `--ticket-id` | Jira work-item id (required) |
| `--rid` | lane run id (required) |
| `--stack` | stack/org key, e.g. `rlg` (required) |
| `--plan-dir` | active chunked-plan dir (required) |
| `--worker-role` | lane role, e.g. `dev` (required) |
| `--stop-file` | file holding the STOP envelope (or pipe on stdin) |
| `--broker-url` | override `BROKER_URL` for this call |
| `--dry-run` | print the JSON payload; do not POST |

Env: `BROKER_URL` (default `http://localhost:8080`), `ASK_TIMEOUT` (default `120`s).
