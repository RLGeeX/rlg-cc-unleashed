#!/usr/bin/env python3
"""Per-org Jira REST client for the agent/lane flow (ai-broker chunk-006).

REST against /rest/api/3 with per-org Basic auth (email + API token), NOT the
Atlassian MCP — the MCP's per-site scope bit us before (only one site visible per
session). Credentials come from the per-org context (chunk-005):

    source ~/.config/org-context.sh        # selects org from $PWD, exports the env
    -> JIRA_BASE_URL  JIRA_EMAIL  JIRA_API_TOKEN

Logic ported from rlg-cc-broker/broker/jira_client.py (get_ticket, transition-by-name,
add_comment via ADF, _render_adf) but stdlib-only (urllib) so the skill needs no deps.

Subcommands:
    get KEY                         read an issue (key | status | summary + body)
    transitions KEY                 list available transitions (non-mutating)
    transition KEY --to NAME        move an OWNED issue to a named state
    comment KEY --body TEXT         ADF comment on an OWNED issue
    resolve-cloudid                 resolve this site's cloudId and write it to plan-meta

Ownership gate: `transition` and `comment` act ONLY on issues this plan owns per
plan-meta.json `jira.issueKeys` (epic + storiesByPhase + workItemsByChunk). Jira is
the HUMAN board; the agent transitions its own Work-Items/Stories, nothing else.
"""

from __future__ import annotations

import argparse
import base64
import glob
import json
import os
import sys
import urllib.error
import urllib.request

API = "/rest/api/3"


def _die(msg: str, code: int = 1) -> "None":
    print(f"[ERROR] {msg}", file=sys.stderr)
    raise SystemExit(code)


def _creds() -> "tuple[str, str, str]":
    base = os.environ.get("JIRA_BASE_URL", "").rstrip("/")
    email = os.environ.get("JIRA_EMAIL", "")
    token = os.environ.get("JIRA_API_TOKEN", "")
    if not (base and email and token):
        missing = [
            n
            for n, v in (
                ("JIRA_BASE_URL", base),
                ("JIRA_EMAIL", email),
                ("JIRA_API_TOKEN", token),
            )
            if not v
        ]
        _die(
            "missing per-org Jira creds: "
            + ", ".join(missing)
            + "\n        run:  source ~/.config/org-context.sh   (selects org from $PWD)"
        )
    return base, email, token


def _request(method: str, url: str, *, body: "dict | None" = None) -> "dict | None":
    """Basic-auth REST call. Returns parsed JSON (or None for empty 2xx bodies)."""
    _, email, token = _creds()
    auth = base64.b64encode(f"{email}:{token}".encode()).decode()
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Basic {auth}")
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:500]
        _die(f"HTTP {exc.code} {method} {url}\n        {detail}")
    except urllib.error.URLError as exc:
        _die(f"could not reach Jira ({exc.reason}) — check JIRA_BASE_URL / network")
    return None  # unreachable; _die raises


def _render_adf(adf: "dict | None") -> "str | None":
    """Render Atlassian Document Format to plain text (lossy). Ported from the broker."""
    if not adf:
        return None
    parts: "list[str]" = []

    def walk(node: dict) -> None:
        if "text" in node:
            parts.append(str(node["text"]))
        content = node.get("content")
        if isinstance(content, list):
            for child in content:
                if isinstance(child, dict):
                    walk(child)
        if node.get("type") == "paragraph":
            parts.append("\n")

    walk(adf)
    return "".join(parts).strip() or None


# --- plan-meta ownership ----------------------------------------------------

def _find_plan_meta(plan_dir: "str | None") -> "str | None":
    if plan_dir:
        p = os.path.join(plan_dir, "plan-meta.json")
        return p if os.path.isfile(p) else _die(f"no plan-meta.json in {plan_dir}")
    hits = sorted(glob.glob(".claude/plans/*/plan-meta.json"))
    if len(hits) == 1:
        return hits[0]
    if not hits:
        return None
    _die(
        "multiple plans found; pass --plan-dir to pick one:\n        "
        + "\n        ".join(os.path.dirname(h) for h in hits)
    )
    return None


def _owned_keys(meta: dict) -> "set[str]":
    jira = meta.get("jira", {}) or {}
    keys = jira.get("issueKeys", {}) or {}
    owned: "set[str]" = set()
    if isinstance(keys, dict):
        if keys.get("epic"):
            owned.add(str(keys["epic"]))
        for grp in ("storiesByPhase", "workItemsByChunk"):
            sub = keys.get(grp, {}) or {}
            if isinstance(sub, dict):
                owned.update(str(v) for v in sub.values() if v)
    if jira.get("epic"):
        owned.add(str(jira["epic"]))
    return owned


def _assert_owned(key: str, plan_dir: "str | None") -> None:
    meta_path = _find_plan_meta(plan_dir)
    if not meta_path:
        _die(
            f"refusing to mutate {key}: no plan-meta.json found to confirm ownership.\n"
            "        Pass --plan-dir <plan> whose jira.issueKeys lists this issue."
        )
    meta = json.load(open(meta_path))
    owned = _owned_keys(meta)
    if key not in owned:
        _die(
            f"refusing to mutate {key}: not in {meta_path} jira.issueKeys "
            f"(owned: {sorted(owned) or 'none'}).\n"
            "        The agent transitions only its OWN Work-Items/Stories/Epic."
        )


# --- subcommands ------------------------------------------------------------

def cmd_get(args: argparse.Namespace) -> None:
    base, _, _ = _creds()
    data = _request(
        "GET",
        f"{base}{API}/issue/{args.key}"
        "?fields=summary,description,status,customfield_10100",
    )
    f = data["fields"]
    print(f"{data['key']} | {f['status']['name']} | {f.get('summary', '')}")
    body = _render_adf(f.get("description"))
    if body:
        print("\n" + body)
    ac = _render_adf(f.get("customfield_10100"))
    if ac:
        print("\nAcceptance criteria:\n" + ac)


def cmd_transitions(args: argparse.Namespace) -> None:
    base, _, _ = _creds()
    data = _request("GET", f"{base}{API}/issue/{args.key}/transitions")
    print(f"transitions for {args.key}:")
    for t in data["transitions"]:
        print(f"  {t['id']:>4}  {t['name']}  -> {t['to']['name']}")


def cmd_transition(args: argparse.Namespace) -> None:
    _assert_owned(args.key, args.plan_dir)
    base, _, _ = _creds()
    data = _request("GET", f"{base}{API}/issue/{args.key}/transitions")
    match = next(
        (t for t in data["transitions"] if str(t["name"]).lower() == args.to.lower()),
        None,
    )
    if not match:
        _die(
            f"no transition '{args.to}' for {args.key}; "
            f"available: {[t['name'] for t in data['transitions']]}"
        )
    if args.dry_run:
        print(
            f"[DRY-RUN] owned + resolvable: would move {args.key} -> "
            f"{match['to']['name']} via transition '{match['name']}' (id {match['id']})"
        )
        return
    _request(
        "POST",
        f"{base}{API}/issue/{args.key}/transitions",
        body={"transition": {"id": match["id"]}},
    )
    print(f"{args.key} -> {match['to']['name']} (transition '{match['name']}' applied)")


def cmd_comment(args: argparse.Namespace) -> None:
    _assert_owned(args.key, args.plan_dir)
    if args.dry_run:
        print(f"[DRY-RUN] owned: would comment on {args.key}: {args.body!r}")
        return
    base, _, _ = _creds()
    adf = {
        "version": 1,
        "type": "doc",
        "content": [
            {"type": "paragraph", "content": [{"type": "text", "text": args.body}]}
        ],
    }
    _request("POST", f"{base}{API}/issue/{args.key}/comment", body={"body": adf})
    print(f"comment posted on {args.key}")


def cmd_resolve_cloudid(args: argparse.Namespace) -> None:
    base, _, _ = _creds()
    # Basic-auth-friendly tenant lookup (the OAuth getAccessibleAtlassianResources
    # path needs a bearer token; _edge/tenant_info works with the API token).
    info = _request("GET", f"{base}/_edge/tenant_info")
    cloud_id = info.get("cloudId")
    if not cloud_id:
        _die(f"no cloudId in tenant_info response: {info}")
    site = base.replace("https://", "").replace("http://", "")
    print(f"cloudId: {cloud_id}  site: {site}")

    meta_path = _find_plan_meta(args.plan_dir)
    if not meta_path:
        print("(no plan-meta.json found — not writing back; pass --plan-dir to persist)")
        return
    meta = json.load(open(meta_path))
    jira = meta.setdefault("jira", {})
    existing_site = jira.get("site")
    if existing_site and existing_site != site:
        _die(
            f"refusing to write: resolved site '{site}' != plan-meta jira.site "
            f"'{existing_site}' in {meta_path}.\n"
            "        The active org creds don't match this plan's org — "
            "source the right org-context, or pass the matching --plan-dir."
        )
    changed = jira.get("cloudId") != cloud_id or jira.get("site") != site
    jira["cloudId"] = cloud_id
    jira.setdefault("site", site)
    if args.project_key:
        jira["projectKey"] = args.project_key
    with open(meta_path, "w") as fh:
        json.dump(meta, fh, indent=2)
        fh.write("\n")
    print(f"{'wrote' if changed else 'confirmed'} cloudId in {meta_path}")


def main(argv: "list[str] | None" = None) -> None:
    p = argparse.ArgumentParser(prog="jira_rest.py", description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("get", help="read an issue")
    g.add_argument("key")
    g.set_defaults(func=cmd_get)

    tl = sub.add_parser("transitions", help="list available transitions (non-mutating)")
    tl.add_argument("key")
    tl.set_defaults(func=cmd_transitions)

    t = sub.add_parser("transition", help="move an OWNED issue to a named state")
    t.add_argument("key")
    t.add_argument("--to", required=True, help="target transition name, e.g. 'In Progress'")
    t.add_argument("--plan-dir", help="plan dir whose jira.issueKeys confirms ownership")
    t.add_argument("--dry-run", action="store_true", help="check ownership + resolve, do not POST")
    t.set_defaults(func=cmd_transition)

    c = sub.add_parser("comment", help="ADF comment on an OWNED issue")
    c.add_argument("key")
    c.add_argument("--body", required=True)
    c.add_argument("--plan-dir")
    c.add_argument("--dry-run", action="store_true", help="check ownership, do not POST")
    c.set_defaults(func=cmd_comment)

    r = sub.add_parser("resolve-cloudid", help="resolve site cloudId; write to plan-meta")
    r.add_argument("--plan-dir")
    r.add_argument("--project-key", help="also set jira.projectKey")
    r.set_defaults(func=cmd_resolve_cloudid)

    args = p.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
