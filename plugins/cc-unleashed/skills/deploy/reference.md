# deploy — reference

Detail for the deploy skill (ai-broker chunk-009). Read `SKILL.md` first.

## Flags

| Flag | Default | Meaning |
|------|---------|---------|
| `--repo` | (required) | GitHub `Org/repo` |
| `--pr` | (required) | PR number to merge |
| `--stack` | (required) | org/stack key, e.g. `rlg` |
| `--plan-dir` | (required) | plan dir (Jira ownership + journal target) |
| `--smoke-url` | (required) | URL smoke-checked until HTTP 200 |
| `--ticket` | — | Jira Work-Item to transition to Done (skipped if absent) |
| `--actor` | `operator` | human actor recorded on the gate |
| `--rid` | `pr-<n>` | run id (journal key) |
| `--env` | `dev` | target environment (recorded) |
| `--worker-role` | `operator` | a2a role for the broker gate + inbox poll |
| `--gate` | `interactive` | `interactive` (stdin GO) or `broker` (apply gate) |
| `--gate-timeout` / `--gate-poll` | `1800` / `10` | broker-gate wait + poll seconds |
| `--merge-method` | `squash` | `squash` \| `merge` \| `rebase` |
| `--build-project` / `--build-region` | `rlg-terraform` / `us-east4` | Cloud Build location |
| `--build-timeout` / `--build-poll` | `900` / `20` | build watch seconds |
| `--smoke-retries` / `--smoke-delay` | `10` / `10` | smoke attempts + spacing |
| `--dry-run` | off | print plan + gate mode; do not ship |

Env: `BROKER_URL`, `CLOUDBUILD_PROJECT`, `CLOUDBUILD_REGION`.

## The chunk-004 apply-gate contract (broker, live)

```
POST {BROKER_URL}/a2a/coordinator/ask
  { ticket_id, rid, stack, plan_dir, worker_role, stop_body, query_type:"go_no_go" }
  -> { verdict, awaiting_human: true }          # NOT auto-decided; a human hold is recorded

# the human (notification UI) resolves:
POST {BROKER_URL}/a2a/coordinator/resolve
  { ticket_id, rid, stack, worker_role, decision:"go"|"no_go", actor }
  -> { verdict: "APPLY APPROVED — GO by <actor>." | "APPLY DENIED — NO-GO by <actor>." }

# the worker learns the verdict by reading the latest coordinator->worker message:
GET {BROKER_URL}/a2a/inbox?role=<worker_role>   # body_markdown starts with "APPLY ..."
```

Both the STOP and the verdict persist to v3 `a2a_messages` by construction — the skill
does not log a2a itself.

## Receipts the run emits

`environment`, `gate` (GO + mode), `merged_sha`, `build_id`, `build_status`,
`build_log`, `smoke`, and (when `--ticket`) `jira`. Each is `{value, source}` where
`source` is the exact tool that produced it (`gh pr view --json mergeCommit`,
`gcloud builds list`, `GET <url>`, `jira-rest transition`). They are handed to the
`observability` journal so a fabricated claim has nowhere to hide.

## Ported from the broker (read-only reference)

| broker source | this skill |
|---------------|-----------|
| `agents/charters/operator/AGENT.md` (dev auto-merge; staging/prod human-gated; cloneless `gh pr merge`; capture mergeCommit; smoke; Jira Done; no auto-retry) | the flow + gate |
| `workers/lib/cloudbuild_cli.py` `wait-for-commit` (poll by `COMMIT_SHA`, terminal-status set, newest build) | `watch_build` |
| `workers/lib/cloudbuild_cli.py` `smoke` (HTTP GET, retries, 200) | `smoke` |

Re-implemented stdlib-only (`subprocess` for `gh`/`gcloud`, `urllib` for smoke + broker)
— no `httpx`/install. The deploy execution lives here; the seat/dispatch + the gate
surfacing live in the `/deploy` lane command (chunk-008).

## Live verification note

A true live ship merges a real PR and runs a real Cloud Build — irreversible and
outward-facing. Stub-verified end-to-end here (gate → merge → watch → smoke → journal,
both gate modes, NO-GO abort). Point it at a real PR only with explicit operator GO.
