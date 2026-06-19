---
name: jira-rest
description: Use when an agent or lane needs to read or transition Jira issues programmatically across orgs (rlgeex / chain-mountain / TI) - per-org REST client using org-context creds, NOT the Atlassian MCP. Transitions only the plan's OWN Work-Items/Stories per plan-meta. For the human/manual MCP flow use sk-jira / jira-plan instead.
allowed-tools: Bash, Read
---

# Jira REST (per-org, agent/lane flow)

Programmatic Jira for the agent and lane flow: read an issue, list/apply a transition
on an issue **this plan owns**, post an ADF comment, and resolve a site's `cloudId`
into `plan-meta.json`. Per-org REST (`/rest/api/3`) with Basic auth — **not** the
Atlassian MCP, whose per-site scope only exposes one site per session and bit us before.

> **Not a replacement for `sk-jira` / `jira-plan`.** Those back John's manual,
> MCP-based Jira flow (Epic→Story→Sub-task creation) and stay as-is. This skill is the
> separate REST path for automated agents/lanes. Don't use it to bulk-create the human
> hierarchy.

## Credentials — identity travels with the project dir (chunk-005)

Creds are per-org, selected by `$PWD`. Source the context first; it exports
`JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`:

```bash
source ~/.config/org-context.sh        # detect org from ~/prj/<org>/…
source ~/.config/org-context.sh cm     # or force an org
```

Run the script in the same shell so it inherits those env vars. A lane already runs in
its project dir, so its org identity is the active one.

## Commands

```bash
JR="$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/plugins/cc-unleashed/skills/jira-rest/scripts/jira_rest.py"

python3 "$JR" get RLG-99                       # read: key | status | summary + body
python3 "$JR" transitions RLG-99               # list available transitions (non-mutating)
python3 "$JR" transition RLG-99 --to "In Progress" --plan-dir .claude/plans/<feature>
python3 "$JR" comment RLG-99 --body "..."      --plan-dir .claude/plans/<feature>
python3 "$JR" resolve-cloudid --plan-dir .claude/plans/<feature> [--project-key RLG]
```

Add `--dry-run` to `transition` / `comment` to check ownership + resolve the target
without mutating Jira. Preview first when unsure.

## Ownership gate — transition ONLY your own items

Jira is the **human board**. `transition` and `comment` act only on issues the active
plan owns, read from `plan-meta.json` `jira.issueKeys` (`epic` + `storiesByPhase` +
`workItemsByChunk`). Anything not listed there is refused. This enforces the
`transitionsHint` rule: the agent transitions its own Work-Items/Stories/Epic; it never
fires transitions on, or comments minutiae onto, other people's cards.

Pass `--plan-dir` to name the plan whose `issueKeys` confirm ownership (auto-detected
when exactly one plan lives under `.claude/plans/`).

## Transition workflow (per `transitionsHint`)

- On chunk start: transition the Work-Item to **In Progress**.
- On chunk completion: transition it to **Done**.
- On phase start/completion: transition the Story.
- Match by transition **name** (case-insensitive); the script lists valid options if
  the name doesn't match the issue's current workflow step.

## cloudId resolution

`resolve-cloudid` looks up the site's `cloudId` via `/_edge/tenant_info` (the
Basic-auth-friendly path; the MCP `getAccessibleAtlassianResources` needs OAuth) and
writes `cloudId` (+ `site`) back into `plan-meta.json` `jira`. It **refuses to write**
when the resolved site disagrees with the plan-meta's existing `jira.site` — so cm
creds can't stamp a cm cloudId onto an rlgeex plan. Resolve once per plan.

## Error handling

- **Missing creds** → run `source ~/.config/org-context.sh`.
- **HTTP 404 "Site temporarily unavailable"** → the org's `JIRA_BASE_URL` points at a
  non-existent tenant (wrong subdomain). Fix the org's `~/.config/<org>/jira.env`.
- **"no transition 'X'"** → run `transitions <KEY>` to see the issue's valid moves.
- **"refusing to mutate"** → the key isn't in the plan's `issueKeys`; that's the gate
  working. Use the right `--plan-dir`, or it isn't your item to touch.

---

See `reference.md` for the subcommand/flag table, the `plan-meta` `jira` shape, and the
mapping to the broker `jira_client.py` this skill ports.
