#!/usr/bin/env python3
"""File journal for lane/deploy runs (ai-broker chunk-010, observability).

Each lane or deploy run appends a run summary + receipts + an evidence-cited
postmortem to ``<plan-dir>/journal.md``. The DB (inbox + a2a_messages) is the
durable source of record; this journal is the human-readable, per-plan layer on
top of it — durable run summaries with receipts and a DELTA-style postmortem.

Receipts pattern (carried from the broker): every state claim cites the tool
output that proves it. The journal stores claim -> value -> source rows, so a
fabricated claim has nowhere to hide.

Postmortem rule (Echelon DELTA): the builder never grades itself. The
``--author`` stamped on a postmortem must be a reviewer/coordinator, not the
worker that did the run; the script records who authored it as provenance.

Usage:
    journal.py append --plan-dir DIR --run-id RID --kind deploy --status success \\
        --summary "merged + deployed RLG-123" \\
        --receipts @/tmp/receipts.json \\
        --postmortem @/tmp/postmortem.md --author coordinator

    journal.py show --plan-dir DIR        # print the journal

``--receipts`` is a JSON object {claim: {value, source}} (inline or @file).
``--postmortem`` / ``--summary`` accept inline text or @file. Timestamps are UTC.

Written for macOS bash 3.2 + Linux; stdlib only.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys


def _die(msg: str) -> "None":
    print(f"[ERROR] {msg}", file=sys.stderr)
    raise SystemExit(1)


def _read_arg(val: "str | None") -> "str | None":
    """Resolve an inline value or @file reference."""
    if val is None:
        return None
    if val.startswith("@"):
        path = val[1:]
        if not os.path.isfile(path):
            _die(f"file not found: {path}")
        with open(path) as fh:
            return fh.read()
    return val


def _journal_path(plan_dir: str) -> str:
    if not os.path.isdir(plan_dir):
        _die(f"plan-dir not found: {plan_dir}")
    return os.path.join(plan_dir, "journal.md")


def _now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def cmd_append(args: argparse.Namespace) -> None:
    path = _journal_path(args.plan_dir)
    receipts_raw = _read_arg(args.receipts)
    receipts = {}
    if receipts_raw:
        try:
            receipts = json.loads(receipts_raw)
        except json.JSONDecodeError as exc:
            _die(f"--receipts is not valid JSON: {exc}")

    summary = (_read_arg(args.summary) or "").strip()
    postmortem = (_read_arg(args.postmortem) or "").strip()
    ts = args.timestamp or _now()

    lines: "list[str]" = []
    if not os.path.exists(path):
        lines.append(f"# Run journal — {os.path.basename(os.path.abspath(args.plan_dir))}\n")
        lines.append(
            "Durable run summaries + receipts + postmortems. The DB "
            "(inbox + a2a_messages) is the source of record; this is the readable layer.\n"
        )

    lines.append(f"\n## {ts} · {args.kind} · {args.status} · rid={args.run_id}\n")
    if summary:
        lines.append(f"\n{summary}\n")

    if receipts:
        lines.append("\n**Receipts** (every claim cites tool output):\n\n")
        lines.append("| Claim | Value | Source |\n|---|---|---|\n")
        for claim, info in receipts.items():
            if isinstance(info, dict):
                value = str(info.get("value", "")).replace("|", "\\|")
                source = str(info.get("source", "")).replace("|", "\\|")
            else:
                value, source = str(info).replace("|", "\\|"), ""
            lines.append(f"| {claim} | {value} | {source} |\n")

    if postmortem:
        author = args.author or "UNATTRIBUTED"
        lines.append(f"\n**Postmortem** (author: {author} — builder must not grade itself):\n\n")
        lines.append(postmortem.rstrip() + "\n")
    elif args.kind == "deploy":
        lines.append(
            "\n_No postmortem recorded. A reviewer/coordinator (not the operator) "
            "should append one with --postmortem --author._\n"
        )

    with open(path, "a") as fh:
        fh.write("".join(lines))
    print(f"journal: appended {args.kind}/{args.status} run {args.run_id} -> {path}")


def cmd_show(args: argparse.Namespace) -> None:
    path = _journal_path(args.plan_dir)
    if not os.path.exists(path):
        print(f"(no journal yet at {path})")
        return
    with open(path) as fh:
        sys.stdout.write(fh.read())


def main(argv: "list[str] | None" = None) -> None:
    p = argparse.ArgumentParser(prog="journal.py", description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("append", help="append a run entry")
    a.add_argument("--plan-dir", required=True)
    a.add_argument("--run-id", required=True)
    a.add_argument("--kind", required=True, help="lane | deploy | arch | dev | test | ...")
    a.add_argument("--status", required=True, help="success | failed | aborted | blocked")
    a.add_argument("--summary", help="run summary (inline or @file)")
    a.add_argument("--receipts", help='JSON {claim:{value,source}} (inline or @file)')
    a.add_argument("--postmortem", help="evidence-cited postmortem (inline or @file)")
    a.add_argument("--author", help="postmortem author (must NOT be the builder)")
    a.add_argument("--timestamp", help="override UTC timestamp (else now)")
    a.set_defaults(func=cmd_append)

    s = sub.add_parser("show", help="print the journal")
    s.add_argument("--plan-dir", required=True)
    s.set_defaults(func=cmd_show)

    args = p.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
