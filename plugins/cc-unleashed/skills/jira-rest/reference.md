# jira-rest — reference

Detail for the per-org REST Jira skill (ai-broker chunk-006). Read `SKILL.md` first.

## Subcommands & flags

| Command | Args / flags | Mutates? | Notes |
|---------|--------------|----------|-------|
| `get KEY` | — | no | key \| status \| summary + ADF-rendered body + acceptance criteria |
| `transitions KEY` | — | no | lists `id  name -> target` for the issue's current step |
| `transition KEY` | `--to NAME` `--plan-dir DIR` `--dry-run` | yes | ownership-gated; match by name (case-insensitive) |
| `comment KEY` | `--body TEXT` `--plan-dir DIR` `--dry-run` | yes | ownership-gated; posts a minimal ADF doc |
| `resolve-cloudid` | `--plan-dir DIR` `--project-key K` | writes plan-meta | site-mismatch-guarded write |

Creds (from `org-context`): `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`.

## plan-meta `jira` shape (ownership source)

The ownership gate reads owned keys from `plan-meta.json`:

```json
{
  "jira": {
    "cloudId": "3850217f-bff7-4532-a2eb-2c95bd15ab6c",
    "site": "rlgeex.atlassian.net",
    "projectKey": "RLG",
    "transitionsHint": "On chunk start: Work-Item -> In Progress; on completion -> Done. ...",
    "issueKeys": {
      "epic": "RLG-100",
      "storiesByPhase": { "P1 …": "RLG-101" },
      "workItemsByChunk": { "1": "RLG-110", "2": "RLG-111" }
    }
  }
}
```

Owned set = `epic` ∪ `storiesByPhase.values()` ∪ `workItemsByChunk.values()` (plus a
top-level `jira.epic` if present). `transition` / `comment` refuse any key outside it.
Before tickets exist, `issueKeys` may be a placeholder string — the gate then refuses
all mutations (correct: nothing is owned yet; run `/jira-plan` to create them first).

## Ported from the broker (read-only reference)

Logic mirrors `rlg-cc-broker/broker/jira_client.py`, re-implemented stdlib-only
(`urllib`) so the skill needs no `httpx`/install:

| broker `jira_client.py` | this skill |
|-------------------------|-----------|
| `get_ticket` (fields summary/description/status/customfield_10100) | `cmd_get` |
| `transition` (GET transitions → match by name → POST) | `cmd_transition` |
| `add_comment` (ADF doc → paragraph → text) | `cmd_comment` |
| `_render_adf` (DFS walk, paragraph newlines) | `_render_adf` (verbatim) |
| per-tenant `base_url` + `email` + `api_token` Basic auth | `_creds` from env |

New here (not in the broker client): the `plan-meta` ownership gate, `resolve-cloudid`
with the site-mismatch write guard, the `transitions` list command, and `--dry-run`.

## Why REST, not the Atlassian MCP

The in-session Atlassian MCP scope is per-site: a session authed to one site can't see
another (it had only TI scope and couldn't see RLG). Per-org REST with the org's own
API token, selected by the project dir, gives clean multi-org access with no scope
bleed. `sk-jira` / `jira-plan` keep using the MCP for John's manual flow; this skill is
the REST path for agents/lanes.

## cloudId lookup

`/_edge/tenant_info` returns `{"cloudId": "..."}` under Basic auth — unlike the OAuth-only
`getAccessibleAtlassianResources`. Verified values: `rlgeex.atlassian.net` →
`3850217f-bff7-4532-a2eb-2c95bd15ab6c`; `chainmtn.atlassian.net` →
`d8458cab-1954-4dda-b1ed-79fef4149e33`.
