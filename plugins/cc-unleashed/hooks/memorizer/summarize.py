#!/usr/bin/env python3
"""Summarize a Claude Code session transcript into typed memories via Haiku.

Reads a Claude Code session JSONL transcript, strips noise, enforces a token
budget, strips <private> spans, calls Anthropic Haiku with a cached system
prompt, and emits a validated JSON array of memories on stdout.

Exit code is always 0 — failures emit `[]` so Stop hooks never block.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Iterable

DEFAULT_MODEL = "claude-haiku-4-5-20251001"
DEFAULT_BUDGET = 30000
API_URL = "https://api.anthropic.com/v1/messages"
ALLOWED_TYPES = {"decision", "preference", "pattern", "risk", "task", "fact"}
PRIVATE_RE = re.compile(r"<private>.*?</private>", re.DOTALL | re.IGNORECASE)

SYSTEM_PROMPT = """You extract durable memories from a Claude Code session transcript.

Return a JSON array. Each item must have:
- type: one of [decision, preference, pattern, risk, task, fact]
- title: concise summary, <80 chars
- body: supporting detail, <500 chars
- salience: 0.0-1.0 (how worth remembering long-term)
- why: what makes this non-obvious or load-bearing, <200 chars

Types:
- decision: choice made with rationale (e.g. "chose Haiku over OpenRouter for caching reliability")
- preference: user's stated or demonstrated preference (e.g. "user prefers terse responses")
- pattern: recurring structure or approach seen in code/workflow
- risk: known pitfall, gotcha, or thing-that-broke-before
- task: concrete work item deferred to later
- fact: project/system state worth remembering (config, endpoint, credential location)

Skip:
- trivial tool invocations ("read file X")
- transient debugging state
- anything restated from prior memory (assume dedup happens later — just don't repeat yourself within one output)
- anything that would embarrass the user if leaked

Return [] if nothing meets the bar. Empty is fine. Better than noise.
Respond with ONLY the JSON array, no prose."""


def log(msg: str) -> None:
    print(f"[summarize] {msg}", file=sys.stderr)


def transcript_path(session_id: str) -> Path | None:
    """Locate the JSONL transcript for a given session id."""
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    abs_proj = os.path.abspath(project_dir)
    flat = abs_proj.replace(os.sep, "-")
    if not flat.startswith("-"):
        flat = "-" + flat
    candidate = Path.home() / ".claude" / "projects" / flat / f"{session_id}.jsonl"
    if candidate.exists():
        return candidate
    # Fallback: scan all project dirs for the file
    root = Path.home() / ".claude" / "projects"
    if root.exists():
        for sub in root.iterdir():
            p = sub / f"{session_id}.jsonl"
            if p.exists():
                return p
    return None


def iter_messages(path: Path) -> Iterable[dict[str, Any]]:
    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def summarize_content(content: Any) -> str:
    """Convert a message's content into a compact text representation."""
    if isinstance(content, str):
        return content.strip()
    if not isinstance(content, list):
        return ""
    parts: list[str] = []
    for block in content:
        if not isinstance(block, dict):
            continue
        btype = block.get("type")
        if btype == "text":
            text = (block.get("text") or "").strip()
            if text:
                parts.append(text)
        elif btype == "tool_use":
            name = block.get("name") or "tool"
            tool_input = block.get("input") or {}
            summary = _summarize_tool_input(name, tool_input)
            parts.append(f"[tool:{name}{summary}]")
        # drop: thinking, tool_result, image
    return "\n".join(parts).strip()


def _summarize_tool_input(name: str, tool_input: dict[str, Any]) -> str:
    if not isinstance(tool_input, dict):
        return ""
    for key in ("file_path", "path", "pattern", "command", "description", "query"):
        val = tool_input.get(key)
        if isinstance(val, str) and val:
            snippet = val if len(val) <= 120 else val[:117] + "..."
            return f" {key}={snippet!r}"
    return ""


def estimate_tokens(text: str) -> int:
    return len(text) // 4


def build_transcript(path: Path, budget: int) -> str:
    """Walk messages, keep user+assistant text, truncate tail-biased to budget."""
    entries: list[str] = []
    for msg in iter_messages(path):
        mtype = msg.get("type")
        if mtype not in {"user", "assistant"}:
            continue
        inner = msg.get("message")
        if not isinstance(inner, dict):
            continue
        role = inner.get("role") or mtype
        if role not in {"user", "assistant"}:
            continue
        text = summarize_content(inner.get("content"))
        if not text:
            continue
        # Tool input summaries may still leak large file paths; cap per-entry size
        if len(text) > 2000:
            text = text[:1000] + "\n...[truncated]...\n" + text[-900:]
        entries.append(f"[{role}]\n{text}")

    if not entries:
        return ""

    # Tail-biased: walk from newest to oldest until budget hit, then re-chronologize
    kept_rev: list[str] = []
    used = 0
    for entry in reversed(entries):
        cost = estimate_tokens(entry)
        if used + cost > budget and kept_rev:
            break
        kept_rev.append(entry)
        used += cost
    kept = list(reversed(kept_rev))
    return "\n\n".join(kept)


def strip_private(text: str) -> str:
    return PRIVATE_RE.sub("", text)


def call_anthropic(
    transcript: str, model: str, api_key: str, timeout: float = 30.0
) -> dict[str, Any] | None:
    payload = {
        "model": model,
        "max_tokens": 2048,
        "system": [
            {
                "type": "text",
                "text": SYSTEM_PROMPT,
                "cache_control": {"type": "ephemeral"},
            }
        ],
        "messages": [{"role": "user", "content": transcript}],
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        API_URL,
        data=data,
        headers={
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as err:
        log(f"HTTP {err.code}: {err.read()[:400].decode('utf-8', errors='replace')}")
        return None
    except (urllib.error.URLError, TimeoutError, OSError) as err:
        log(f"network error: {err}")
        return None
    try:
        return json.loads(body)
    except json.JSONDecodeError as err:
        log(f"response not JSON: {err}")
        return None


def extract_text(response: dict[str, Any]) -> str:
    content = response.get("content") or []
    for block in content:
        if isinstance(block, dict) and block.get("type") == "text":
            return block.get("text") or ""
    return ""


def parse_memories(raw: str) -> list[dict[str, Any]]:
    raw = raw.strip()
    if not raw:
        return []
    # Strip optional ```json fences
    if raw.startswith("```"):
        raw = re.sub(r"^```[a-zA-Z]*\s*", "", raw)
        raw = re.sub(r"\s*```$", "", raw)
    # Find first JSON array
    start = raw.find("[")
    end = raw.rfind("]")
    if start == -1 or end == -1 or end < start:
        return []
    candidate = raw[start : end + 1]
    try:
        data = json.loads(candidate)
    except json.JSONDecodeError:
        return []
    if not isinstance(data, list):
        return []
    valid: list[dict[str, Any]] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        mtype = item.get("type")
        title = item.get("title")
        body = item.get("body")
        why = item.get("why")
        salience = item.get("salience")
        if mtype not in ALLOWED_TYPES:
            continue
        if not isinstance(title, str) or not title.strip():
            continue
        if not isinstance(body, str) or not body.strip():
            continue
        try:
            salience_f = float(salience)
        except (TypeError, ValueError):
            continue
        if not 0.0 <= salience_f <= 1.0:
            continue
        valid.append(
            {
                "type": mtype,
                "title": title.strip()[:80],
                "body": body.strip()[:500],
                "salience": salience_f,
                "why": (why.strip()[:200] if isinstance(why, str) else ""),
            }
        )
    return valid


def run(
    transcript_file: Path,
    project_id: str | None,
    budget: int,
    model: str,
) -> list[dict[str, Any]]:
    transcript = build_transcript(transcript_file, budget)
    if not transcript:
        log("empty transcript after filtering")
        return []
    transcript = strip_private(transcript)
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        log("ANTHROPIC_API_KEY unset — skipping API call")
        return []
    response = call_anthropic(transcript, model, api_key)
    if not response:
        return []
    usage = response.get("usage") or {}
    log(
        "usage: in={} out={} cache_read={} cache_create={}".format(
            usage.get("input_tokens"),
            usage.get("output_tokens"),
            usage.get("cache_read_input_tokens"),
            usage.get("cache_creation_input_tokens"),
        )
    )
    text = extract_text(response)
    return parse_memories(text)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--session-id", help="Claude Code session id")
    parser.add_argument("--project-id", default="", help="Memorizer project UUID")
    parser.add_argument("--budget", type=int, default=DEFAULT_BUDGET)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument(
        "--dry-run",
        metavar="JSONL_PATH",
        help="Run against a specific transcript file",
    )
    args = parser.parse_args()

    if args.dry_run:
        path = Path(args.dry_run)
        if not path.exists():
            log(f"dry-run transcript not found: {path}")
            print("[]")
            return 0
    elif args.session_id:
        located = transcript_path(args.session_id)
        if not located:
            log(f"transcript not found for session {args.session_id}")
            print("[]")
            return 0
        path = located
    else:
        parser.print_usage(sys.stderr)
        log("--session-id or --dry-run required")
        print("[]")
        return 0

    try:
        memories = run(path, args.project_id or None, args.budget, args.model)
    except Exception as err:  # never raise from a Stop hook
        log(f"unexpected error: {err}")
        memories = []

    print(json.dumps(memories, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
