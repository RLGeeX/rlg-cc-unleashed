#!/usr/bin/env python3
"""Deploy skill: merge -> watch -> smoke -> Jira Done, human-gated (ai-broker chunk-009).

The one net-new capability cc-unleashed lacked. Ported from the broker operator:
merge policy from agents/charters/operator/AGENT.md, watch+smoke from
workers/lib/cloudbuild_cli.py. Stdlib only (subprocess for gh/gcloud, urllib for
smoke + broker) so the skill needs no deps.

Flow (HUMAN-GATED on the irreversible ship — NEVER ships without an explicit GO):
  1. gate    -> get GO/NO-GO (interactive inline, or broker chunk-004 apply gate)
  2. merge   -> cloneless `gh pr merge --repo <org>/<repo> <pr> --squash`; capture SHA
  3. watch   -> poll Cloud Build by COMMIT_SHA to a terminal state
  4. smoke   -> HTTP GET the URL until 200 (retries)
  5. jira    -> transition the plan-meta Work-Item to Done via the jira-rest skill
  6. journal -> receipts + a run entry via the observability journal skill (chunk-010)

Identity travels with the cwd (chunk-005): `source ~/.config/org-context.sh`
exports GOOGLE_APPLICATION_CREDENTIALS (org SA key) + the gh token is the org's.
Fully non-interactive — no browser/login prompt ever.

Broker apply gate (chunk-004, live at http://localhost:8080):
  POST /a2a/coordinator/ask {query_type:"go_no_go", ...} -> {awaiting_human:true}
  human resolves: POST /a2a/coordinator/resolve {decision:"go"|"no_go", actor}
  worker reads the latest coordinator->worker message via GET /a2a/inbox?role=<role>

Usage:
  deploy.py --repo Org/repo --pr 42 --stack rlg --plan-dir .claude/plans/ai-broker \\
    --smoke-url https://rlgeex.com --ticket RLG-123 --actor jfogarty \\
    [--env dev] [--gate interactive|broker] [--rid run-abc] \\
    [--build-project rlg-terraform] [--build-region us-east4] \\
    [--merge-method squash|merge|rebase] [--dry-run]

Written for macOS bash 3.2 + Linux; stdlib only.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
# sibling skill: observability/scripts/journal.py
JOURNAL = os.path.normpath(os.path.join(HERE, "..", "..", "observability", "scripts", "journal.py"))
# sibling skill: jira-rest/scripts/jira_rest.py
JIRA = os.path.normpath(os.path.join(HERE, "..", "..", "jira-rest", "scripts", "jira_rest.py"))

BROKER_URL = os.environ.get("BROKER_URL", "http://localhost:8080").rstrip("/")
_TERMINAL = frozenset({"SUCCESS", "FAILURE", "INTERNAL_ERROR", "TIMEOUT", "CANCELLED", "EXPIRED"})


def log(msg: str) -> None:
    print(f"[deploy] {msg}", flush=True)


def die(msg: str, receipts: "dict | None" = None) -> "None":
    print(f"[deploy][ERROR] {msg}", file=sys.stderr)
    raise SystemExit(1)


def run(cmd: "list[str]") -> "tuple[int, str, str]":
    p = subprocess.run(cmd, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


# --- step 1: the human gate -------------------------------------------------

def gate_interactive(plan_shape: str) -> bool:
    print("\n=== HUMAN APPLY GATE (irreversible ship) ===")
    print(plan_shape)
    sys.stdout.write("Approve the ship? type 'go' to proceed, anything else aborts: ")
    sys.stdout.flush()
    try:
        answer = sys.stdin.readline().strip().lower()
    except (EOFError, KeyboardInterrupt):
        answer = ""
    return answer == "go"


def gate_broker(args: argparse.Namespace, plan_shape: str) -> bool:
    """Record the go_no_go hold, then poll the inbox for the human's resolve."""
    stop_body = f"🛑 GO/NO-GO — irreversible ship\n\n{plan_shape}"
    payload = {
        "ticket_id": args.ticket or args.rid, "rid": args.rid, "stack": args.stack,
        "plan_dir": args.plan_dir, "worker_role": args.worker_role,
        "stop_body": stop_body, "query_type": "go_no_go",
    }
    resp = _post(f"{BROKER_URL}/a2a/coordinator/ask", payload)
    if not resp.get("awaiting_human"):
        die(f"broker did not register an apply hold (response: {resp})")
    log("apply gate recorded; awaiting human GO/NO-GO via POST /a2a/coordinator/resolve")
    log(f"polling {BROKER_URL}/a2a/inbox?role={args.worker_role} (timeout {args.gate_timeout}s)")
    deadline = time.monotonic() + args.gate_timeout
    while time.monotonic() < deadline:
        inbox = _get(f"{BROKER_URL}/a2a/inbox?role={args.worker_role}")
        for msg in reversed(inbox if isinstance(inbox, list) else []):
            body = (msg.get("body_markdown") or "").upper()
            if body.startswith("APPLY APPROVED — GO") or "APPLY APPROVED" in body:
                log(f"resolved: GO ({msg.get('body_markdown')})")
                return True
            if body.startswith("APPLY DENIED") or "NO-GO" in body:
                log(f"resolved: NO-GO ({msg.get('body_markdown')})")
                return False
        time.sleep(args.gate_poll)
    die("apply gate timed out waiting for a human GO/NO-GO")
    return False


def _post(url: str, body: dict) -> dict:
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as exc:
        die(f"broker HTTP {exc.code} on {url}: {exc.read().decode(errors='replace')[:300]}")
    except urllib.error.URLError as exc:
        die(f"could not reach broker at {url} ({exc.reason}); is it running? BROKER_URL={BROKER_URL}")
    return {}


def _get(url: str) -> "list | dict":
    req = urllib.request.Request(url, method="GET")
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read() or b"[]")
    except urllib.error.URLError:
        return []


# --- steps 2-4: merge, watch, smoke ----------------------------------------

def merge_pr(args: argparse.Namespace) -> str:
    log(f"merging PR #{args.pr} in {args.repo} (--{args.merge_method}, cloneless)")
    code, out, err = run(["gh", "pr", "merge", str(args.pr), "--repo", args.repo,
                          f"--{args.merge_method}"])
    if code != 0:
        die(f"gh pr merge failed: {err.strip() or out.strip()}")
    code, out, err = run(["gh", "pr", "view", str(args.pr), "--repo", args.repo,
                          "--json", "mergeCommit", "-q", ".mergeCommit.oid"])
    sha = out.strip()
    if code != 0 or not sha:
        die(f"could not read merge SHA: {err.strip() or out.strip()}")
    log(f"merged; SHA={sha}")
    return sha


def watch_build(args: argparse.Namespace, sha: str) -> dict:
    log(f"watching Cloud Build for COMMIT_SHA={sha} (timeout {args.build_timeout}s)")
    deadline = time.monotonic() + args.build_timeout
    while time.monotonic() < deadline:
        code, out, err = run([
            "gcloud", "builds", "list",
            f"--project={args.build_project}", f"--region={args.build_region}",
            f"--filter=substitutions.COMMIT_SHA={sha}", "--format=json", "--quiet",
        ])
        if code == 0 and out.strip():
            try:
                builds = json.loads(out)
            except json.JSONDecodeError:
                builds = []
            if builds:
                newest = max(builds, key=lambda b: b.get("createTime", ""))
                status = newest.get("status", "")
                if status in _TERMINAL:
                    return {"id": newest.get("id", "unknown"), "status": status,
                            "logUrl": newest.get("logUrl", "")}
        time.sleep(args.build_poll)
    die(f"build watch timed out for SHA={sha}")
    return {}


def smoke(args: argparse.Namespace) -> dict:
    log(f"smoke-checking {args.smoke_url} (until HTTP 200, {args.smoke_retries} tries)")
    for attempt in range(1, args.smoke_retries + 1):
        try:
            with urllib.request.urlopen(args.smoke_url, timeout=15) as r:
                if r.status == 200:
                    return {"status": "HTTP 200", "attempt": attempt}
                last = f"HTTP {r.status}"
        except urllib.error.HTTPError as exc:
            last = f"HTTP {exc.code}"
        except urllib.error.URLError as exc:
            last = str(exc.reason)
        if attempt < args.smoke_retries:
            time.sleep(args.smoke_delay)
    die(f"smoke failed: {args.smoke_url} did not return 200 ({last})")
    return {}


# --- steps 5-6: jira transition + journal ----------------------------------

def jira_done(args: argparse.Namespace) -> "str | None":
    if not args.ticket:
        log("no --ticket; skipping Jira transition")
        return None
    if not os.path.isfile(JIRA):
        log(f"jira-rest script not found at {JIRA}; skipping Jira transition")
        return None
    log(f"transitioning {args.ticket} -> Done via jira-rest")
    code, out, err = run(["python3", JIRA, "transition", args.ticket, "--to", "Done",
                          "--plan-dir", args.plan_dir])
    if code != 0:
        log(f"jira transition non-fatal failure: {err.strip() or out.strip()}")
        return f"FAILED: {err.strip() or out.strip()}"
    return out.strip()


def write_journal(args: argparse.Namespace, status: str, receipts: dict, summary: str) -> None:
    if not os.path.isfile(JOURNAL):
        log(f"journal script not found at {JOURNAL}; receipts:\n{json.dumps(receipts, indent=2)}")
        return
    rfile = f"/tmp/deploy-receipts-{args.rid}.json"
    with open(rfile, "w") as fh:
        json.dump(receipts, fh)
    run(["python3", JOURNAL, "append", "--plan-dir", args.plan_dir, "--run-id", args.rid,
         "--kind", "deploy", "--status", status, "--summary", summary, "--receipts", f"@{rfile}"])
    log(f"journal entry written for run {args.rid}")


# --- orchestration ----------------------------------------------------------

def main(argv: "list[str] | None" = None) -> None:
    p = argparse.ArgumentParser(prog="deploy.py", description=__doc__)
    p.add_argument("--repo", required=True, help="GitHub Org/repo")
    p.add_argument("--pr", required=True, type=int, help="PR number to merge")
    p.add_argument("--stack", required=True, help="org/stack key, e.g. rlg")
    p.add_argument("--plan-dir", required=True)
    p.add_argument("--smoke-url", required=True)
    p.add_argument("--ticket", help="Jira Work-Item to transition to Done")
    p.add_argument("--actor", default="operator", help="human actor for the gate record")
    p.add_argument("--rid", default=None, help="run id (default: pr-<n>)")
    p.add_argument("--env", default="dev", help="target environment (recorded in receipts)")
    p.add_argument("--worker-role", default="operator")
    p.add_argument("--gate", choices=["interactive", "broker"], default="interactive")
    p.add_argument("--gate-timeout", type=int, default=1800)
    p.add_argument("--gate-poll", type=int, default=10)
    p.add_argument("--merge-method", choices=["squash", "merge", "rebase"], default="squash")
    p.add_argument("--build-project", default=os.environ.get("CLOUDBUILD_PROJECT", "rlg-terraform"))
    p.add_argument("--build-region", default=os.environ.get("CLOUDBUILD_REGION", "us-east4"))
    p.add_argument("--build-timeout", type=int, default=900)
    p.add_argument("--build-poll", type=int, default=20)
    p.add_argument("--smoke-retries", type=int, default=10)
    p.add_argument("--smoke-delay", type=int, default=10)
    p.add_argument("--dry-run", action="store_true", help="print the plan + gate prompt; do not ship")
    args = p.parse_args(argv)
    args.rid = args.rid or f"pr-{args.pr}"

    plan_shape = (f"Ship: merge PR #{args.pr} ({args.repo}) via {args.merge_method} -> "
                  f"watch build in {args.build_project}/{args.build_region} -> "
                  f"smoke {args.smoke_url} -> Jira {args.ticket or '(none)'} Done. env={args.env}")

    if args.dry_run:
        print("[DRY-RUN] " + plan_shape)
        print(f"[DRY-RUN] gate mode: {args.gate}; would require an explicit GO before merging.")
        return

    # 1. GATE — never ship without an explicit GO
    approved = gate_broker(args, plan_shape) if args.gate == "broker" else gate_interactive(plan_shape)
    if not approved:
        write_journal(args, "aborted", {"gate": {"value": "NO-GO / no approval", "source": args.gate}},
                      f"ship aborted at the human gate for PR #{args.pr}")
        die("NO-GO — ship aborted at the human apply gate")

    # 2-4. merge -> watch -> smoke (receipts captured at each step)
    receipts: "dict" = {"environment": {"value": args.env, "source": "--env"},
                        "gate": {"value": "GO", "source": args.gate}}
    sha = merge_pr(args)
    receipts["merged_sha"] = {"value": sha, "source": "gh pr view --json mergeCommit"}

    build = watch_build(args, sha)
    receipts["build_id"] = {"value": build["id"], "source": "gcloud builds list"}
    receipts["build_status"] = {"value": build["status"], "source": "gcloud builds list"}
    receipts["build_log"] = {"value": build.get("logUrl", ""), "source": "gcloud builds list"}
    if build["status"] != "SUCCESS":
        write_journal(args, "failed", receipts, f"build {build['status']} for PR #{args.pr}")
        die(f"build did not succeed: {build['status']} (logs: {build.get('logUrl')})")

    sm = smoke(args)
    receipts["smoke"] = {"value": sm["status"], "source": f"GET {args.smoke_url}"}

    # 5. Jira Done
    jt = jira_done(args)
    if jt:
        receipts["jira"] = {"value": jt, "source": "jira-rest transition"}

    # 6. receipts + journal
    summary = (f"Shipped PR #{args.pr} ({args.repo}) to {args.env}: build {build['status']}, "
               f"smoke {sm['status']}, {args.ticket or 'no ticket'}.")
    write_journal(args, "success", receipts, summary)

    print("\n=== DEPLOY RECEIPTS ===")
    for claim, info in receipts.items():
        print(f"  {claim}: {info['value']}  [{info['source']}]")
    log("done.")


if __name__ == "__main__":
    main()
