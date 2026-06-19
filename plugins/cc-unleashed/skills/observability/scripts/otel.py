#!/usr/bin/env python3
"""OTEL-style token/cost/latency trace from Claude Code transcripts (ai-broker chunk-010).

The free source: Claude Code writes a per-session ``.jsonl`` transcript under
``~/.claude/projects/<project-slug>/``. Each assistant line carries
``message.usage`` (input / output / cache tokens), ``message.model``,
``timestamp``, ``durationMs``, and ``isSidechain`` + ``agentName`` for subagent
attribution. This script aggregates that into per-session and per-subagent
tokens, cost, and latency — the OTEL layer over the DB record.

Cost rates (per MTok, confirmed via the claude-api skill):
    model         input  output  cache-write-5m  cache-write-1h  cache-read
    opus-4-8      5.00   25.00   6.25            10.00           0.50
    sonnet-4-6    3.00   15.00   3.75             6.00           0.30
    haiku-4-5     1.00    5.00   1.25             2.00           0.10
(cache write = 1.25x input for 5m / 2x for 1h; cache read = 0.1x input.)

Usage:
    otel.py trace [TRANSCRIPT.jsonl]      # default: newest in the project dir
    otel.py trace --project-dir ~/.claude/projects/<slug>
    otel.py trace --format json           # OTLP-ish metrics JSON
    otel.py trace --plan-dir .claude/plans/<feature>   # also append to journal dir

Written for macOS bash 3.2 + Linux; stdlib only.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import sys

# per-MTok rates: (input, output, cache_write_5m, cache_write_1h, cache_read)
RATES = {
    "opus-4-8": (5.00, 25.00, 6.25, 10.00, 0.50),
    "opus-4-7": (5.00, 25.00, 6.25, 10.00, 0.50),
    "sonnet-4-6": (3.00, 15.00, 3.75, 6.00, 0.30),
    "haiku-4-5": (1.00, 5.00, 1.25, 2.00, 0.10),
    "fable-5": (10.00, 50.00, 12.50, 20.00, 1.00),
}
_DEFAULT_RATE = RATES["opus-4-8"]


def _die(msg: str) -> "None":
    print(f"[ERROR] {msg}", file=sys.stderr)
    raise SystemExit(1)


def _rate_for(model: str) -> "tuple":
    for key, rate in RATES.items():
        if key in (model or ""):
            return rate
    return _DEFAULT_RATE


def _find_transcript(path: "str | None", project_dir: "str | None") -> str:
    if path:
        if not os.path.isfile(path):
            _die(f"transcript not found: {path}")
        return path
    base = project_dir or _default_project_dir()
    hits = sorted(glob.glob(os.path.join(base, "*.jsonl")), key=os.path.getmtime, reverse=True)
    if not hits:
        _die(f"no .jsonl transcripts under {base}")
    return hits[0]


def _default_project_dir() -> str:
    # Claude Code slugifies the cwd: /Users/x/prj -> -Users-x-prj
    slug = os.getcwd().replace("/", "-")
    return os.path.join(os.path.expanduser("~/.claude/projects"), slug)


def _agent_key(rec: dict) -> str:
    if rec.get("isSidechain"):
        return "subagent:" + str(rec.get("agentName") or "unknown")
    return "main"


def _accumulate(transcript: str) -> dict:
    """Walk the transcript; return per-agent and total usage/cost/latency."""
    agents: "dict[str, dict]" = {}
    models: set = set()
    session_id = None
    for line in open(transcript):
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        session_id = session_id or rec.get("sessionId")
        msg = rec.get("message") if isinstance(rec.get("message"), dict) else {}
        usage = msg.get("usage") if isinstance(msg.get("usage"), dict) else None
        dur = rec.get("durationMs")
        if not usage and not dur:
            continue
        key = _agent_key(rec)
        a = agents.setdefault(
            key,
            {"in": 0, "out": 0, "cw5m": 0, "cw1h": 0, "cr": 0, "ms": 0, "calls": 0, "cost": 0.0},
        )
        if isinstance(dur, (int, float)):
            a["ms"] += dur
        if not usage:
            continue
        model = msg.get("model") or ""
        models.add(model)
        cc = usage.get("cache_creation") if isinstance(usage.get("cache_creation"), dict) else {}
        cw5m = int(cc.get("ephemeral_5m_input_tokens", 0) or 0)
        cw1h = int(cc.get("ephemeral_1h_input_tokens", 0) or 0)
        if not (cw5m or cw1h):  # fall back to the flat field, treat as 5m
            cw5m = int(usage.get("cache_creation_input_tokens", 0) or 0)
        ti = int(usage.get("input_tokens", 0) or 0)
        to = int(usage.get("output_tokens", 0) or 0)
        cr = int(usage.get("cache_read_input_tokens", 0) or 0)
        r = _rate_for(model)
        cost = (ti * r[0] + to * r[1] + cw5m * r[2] + cw1h * r[3] + cr * r[4]) / 1_000_000
        a["in"] += ti
        a["out"] += to
        a["cw5m"] += cw5m
        a["cw1h"] += cw1h
        a["cr"] += cr
        a["cost"] += cost
        a["calls"] += 1
    return {"session_id": session_id, "models": sorted(m for m in models if m), "agents": agents}


def _totals(agents: dict) -> dict:
    t = {"in": 0, "out": 0, "cw5m": 0, "cw1h": 0, "cr": 0, "ms": 0, "calls": 0, "cost": 0.0}
    for a in agents.values():
        for k in t:
            t[k] += a[k]
    return t


def cmd_trace(args: argparse.Namespace) -> None:
    transcript = _find_transcript(args.transcript, args.project_dir)
    data = _accumulate(transcript)
    agents, totals = data["agents"], _totals(data["agents"])

    if args.format == "json":
        out = {
            "transcript": transcript,
            "session_id": data["session_id"],
            "models": data["models"],
            "metrics": {
                k: {
                    "tokens": {"input": v["in"], "output": v["out"],
                               "cache_write_5m": v["cw5m"], "cache_write_1h": v["cw1h"],
                               "cache_read": v["cr"]},
                    "cost_usd": round(v["cost"], 4),
                    "latency_ms": v["ms"],
                    "model_calls": v["calls"],
                }
                for k, v in agents.items()
            },
            "total": {"cost_usd": round(totals["cost"], 4), "latency_ms": totals["ms"],
                      "model_calls": totals["calls"],
                      "tokens_in": totals["in"], "tokens_out": totals["out"]},
        }
        print(json.dumps(out, indent=2))
        return

    print(f"transcript: {transcript}")
    print(f"session:    {data['session_id']}")
    print(f"models:     {', '.join(data['models']) or 'unknown'}")
    print()
    hdr = f"{'agent':<28} {'calls':>5} {'in':>9} {'out':>8} {'cache_r':>9} {'lat(s)':>7} {'cost$':>8}"
    print(hdr)
    print("-" * len(hdr))
    for key in sorted(agents):
        v = agents[key]
        print(f"{key:<28} {v['calls']:>5} {v['in']:>9} {v['out']:>8} {v['cr']:>9} "
              f"{v['ms'] / 1000:>7.1f} {v['cost']:>8.4f}")
    print("-" * len(hdr))
    print(f"{'TOTAL':<28} {totals['calls']:>5} {totals['in']:>9} {totals['out']:>8} "
          f"{totals['cr']:>9} {totals['ms'] / 1000:>7.1f} {totals['cost']:>8.4f}")

    if args.plan_dir:
        _append_to_journal_dir(args.plan_dir, data, totals)


def _append_to_journal_dir(plan_dir: str, data: dict, totals: dict) -> None:
    if not os.path.isdir(plan_dir):
        _die(f"plan-dir not found: {plan_dir}")
    path = os.path.join(plan_dir, "otel.md")
    sid = data["session_id"] or "unknown"
    with open(path, "a") as fh:
        fh.write(f"\n## OTEL trace · session={sid}\n\n")
        fh.write(f"- models: {', '.join(data['models']) or 'unknown'}\n")
        fh.write(f"- model calls: {totals['calls']}\n")
        fh.write(f"- tokens: {totals['in']} in / {totals['out']} out / {totals['cr']} cache-read\n")
        fh.write(f"- latency: {totals['ms'] / 1000:.1f}s\n")
        fh.write(f"- cost: ${totals['cost']:.4f}\n")
    print(f"\notel: appended trace summary -> {path}")


def main(argv: "list[str] | None" = None) -> None:
    p = argparse.ArgumentParser(prog="otel.py", description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("trace", help="aggregate tokens/cost/latency from a transcript")
    t.add_argument("transcript", nargs="?", help="path to a .jsonl transcript (default: newest)")
    t.add_argument("--project-dir", help="transcript dir (default: derived from cwd)")
    t.add_argument("--format", choices=["table", "json"], default="table")
    t.add_argument("--plan-dir", help="also append a trace summary to <plan-dir>/otel.md")
    t.set_defaults(func=cmd_trace)
    args = p.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
