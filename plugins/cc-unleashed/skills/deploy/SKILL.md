---
name: deploy
description: Use to ship an approved PR - cloneless merge, watch the build to a terminal state, smoke-check, transition the Jira Work-Item to Done, and write receipts + a journal entry. HUMAN-GATED on the irreversible ship (inline confirm, or the broker apply gate); never ships without an explicit GO. The operator-lane execution step for ai-broker chunk-009.
allowed-tools: Bash, Read
---

# Deploy

The one capability cc-unleashed lacked: **merge → watch → smoke → Jira Done**, with
receipts at every step and a journal entry at the end. Ported from the broker operator
(merge policy from its charter, watch+smoke from `cloudbuild_cli.py`), stdlib-only so it
needs no deps. This is the post-approval execution step the `/deploy` lane calls.

## CRITICAL: human-gated, never auto-ships

The irreversible ship (PR merge / `terraform apply`) is **John's call**. The skill
**never merges without an explicit GO.** Two gate modes:

- **`interactive`** (default) — prints the plan shape and waits for `go` on stdin. Use
  when a human is at the `/deploy` lane.
- **`broker`** — autonomous: POSTs a `go_no_go` STOP to the chunk-004 apply gate
  (`POST {BROKER_URL}/a2a/coordinator/ask {query_type:"go_no_go"}` → `awaiting_human:true`),
  then polls `GET {BROKER_URL}/a2a/inbox?role=<role>` until the human resolves via
  `POST /a2a/coordinator/resolve {decision:"go"|"no_go", actor}`. Only `GO` proceeds.

NO-GO or timeout → aborts before any merge and journals the abort.

## Identity (chunk-005) — fully non-interactive

Run in the project's cwd; `source ~/.config/org-context.sh` first so
`GOOGLE_APPLICATION_CREDENTIALS` (org SA key) is exported and the `gh` token is the
org's. No browser/login prompt ever.

## Run

```bash
DEPLOY="$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/plugins/cc-unleashed/skills/deploy/scripts/deploy.py"

source ~/.config/org-context.sh        # org identity travels with the cwd
python3 "$DEPLOY" \
  --repo RLGeeX/rlg-cc-unleashed --pr 42 --stack rlg \
  --plan-dir .claude/plans/ai-broker --smoke-url https://rlgeex.com \
  --ticket RLG-123 --actor jfogarty --env dev \
  --gate interactive          # or: --gate broker
```

`--dry-run` prints the plan shape + gate mode without shipping — preview first.

## Flow & receipts

1. **Gate** — GO/NO-GO (above). Never proceeds without GO.
2. **Merge** — `gh pr merge <pr> --repo <org>/<repo> --squash` (cloneless); capture the
   merge SHA via `gh pr view --json mergeCommit`.
3. **Watch** — poll `gcloud builds list --filter=substitutions.COMMIT_SHA=<sha>` to a
   terminal status; non-`SUCCESS` aborts with the log URL.
4. **Smoke** — HTTP GET `--smoke-url` until `200` (retries).
5. **Jira** — transition `--ticket` to Done via the `jira-rest` skill (chunk-006);
   ownership-gated by plan-meta, non-fatal if it fails.
6. **Journal** — every state claim (merged SHA, build id/status, smoke HTTP, Jira) is a
   **receipt citing its tool output**, written to `<plan-dir>/journal.md` via the
   `observability` skill (chunk-010).

## Config

- `BROKER_URL` — apply-gate broker (default `http://localhost:8080`).
- `CLOUDBUILD_PROJECT` / `CLOUDBUILD_REGION` — or `--build-project` / `--build-region`
  (defaults `rlg-terraform` / `us-east4`).
- Timeouts/retries: `--gate-timeout`, `--build-timeout`, `--smoke-retries`, etc.

## Error handling

- **Build not SUCCESS** → abort with the `logUrl`; journal `failed`. Never auto-retry —
  stop and report (operator charter rule).
- **Smoke never 200** → abort; nothing to roll back (merge already landed — surface it).
- **Broker unreachable** in `--gate broker` → abort (can't confirm the human GO).
- **Jira transition fails** → non-fatal; recorded as a `FAILED` receipt for follow-up.

## Depends on

chunk-004 (apply gate, live), chunk-005 (identity), chunk-006 (`jira-rest`),
chunk-010 (`observability` journal). See `reference.md` for the full flag table.
