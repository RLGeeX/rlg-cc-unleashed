#!/usr/bin/env python3
"""Summarize a Claude Code session transcript into typed memories via Haiku.

Reads a Claude Code session JSONL transcript, strips noise, enforces a token
budget, strips <private> spans, calls Anthropic Haiku with a cached system
prompt, and emits a validated JSON array of memories on stdout.

Exit code is always 0 — failures emit `[]` so Stop hooks never block.
"""

from __future__ import annotations

import argparse
import datetime as dt
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

A "durable memory" is something a future Claude instance would wish it had known when the user says "hey, about that thing we did" — load-bearing decisions, non-obvious gotchas, preferences that should shape future work, and concrete state that does not live in the code.

Return a JSON array. Each item must have:
- type: one of [decision, preference, pattern, risk, task, fact]
- title: concise summary, <80 chars, specific enough to distinguish from similar memories
- body: supporting detail, <500 chars; include *why* when the rule has a reason
- salience: 0.0-1.0 (see calibration below — pick deliberately, not a feel-good scale)
- why: what makes this non-obvious or load-bearing, <200 chars

Types and how to tell them apart:

- decision: a choice was made between alternatives, with rationale.
  GOOD: "Scoped persist-execute state per-cwd (option 3) over session-id — session-scoped would orphan state on crash."
  BAD: "Adopt Sonnet over Opus" when no such choice appears in the transcript — do not fabricate decisions.

- preference: user's stated or demonstrated preference about workflow, output, or approach.
  GOOD: "User prefers commit bodies that explain why, not what."
  BAD: "User likes clean code" — too vague to act on.

- pattern: a recurring structure or approach that repeats across the codebase or session.
  GOOD: "Helper scripts live under skills/<name>/scripts/ and SKILL.md invokes them, never inlines bash."
  BAD: "Uses Python" — that's tech stack, not a pattern.

- risk: a pitfall, gotcha, footgun, or thing that broke before that might break again.
  GOOD: "Pre-commit no-ai-attribution hook matches 'claude' case-insensitively; literal path strings in commit bodies get rejected."
  BAD: "Code could have bugs" — not specific.

- task: a concrete work item explicitly deferred to a later session.
  GOOD: "Re-measure synthesis cache hit rate after enlarging the system prompt past 1024 tokens."
  BAD: "Consider improving performance" — no concrete handle.

- fact: project/system state worth remembering (config, endpoint, credential location, version).
  GOOD: "Plugin remote is git@github-rlg:RLGeeX/rlg-cc-unleashed.git"
  BAD: "Project: rlg-cc (reinforcement learning game compiler)" — do not infer project purpose from its name; use only what the transcript says.

Salience calibration:
- 0.9-1.0: load-bearing rationale, irreversible decision, non-obvious constraint
- 0.7-0.89: reusable pattern, documented gotcha, explicit preference with reason
- 0.5-0.69: project state worth knowing next session
- Below 0.5: skip — do not emit

Hard skips (omit even if an entry technically fits a type):
- Trivial tool invocations ("read file X", "ran ls").
- Transient debugging state (mid-investigation logs, throwaway hypotheses).
- Anything restated from prior memory — dedup runs later, but do not repeat yourself within one output.
- "Bugfix" entries when the only edited files are docs (.md, .rst, .txt, .adoc) — the post-write detector is noisy on doc prose.
- Anything that would embarrass the user if leaked.
- Hallucinated descriptions: do not describe what the project does from its name. Do not invent decisions that were not made. Do not generalize a single action into a "pattern".

Anti-hallucination guards:
- Only extract what the transcript explicitly shows. If you have to infer, you are guessing.
- If the transcript is short and uneventful, return [].
- "The user and Claude discussed X" is not a memory — was a decision actually reached? Was a preference actually stated?
- Prefer one precise memory over three vague ones.

Example of a well-formed entry:
{
  "type": "risk",
  "title": "Stop hook state was global, caused cross-session hijacks",
  "body": "Prior to v1.11.0, persist-execute kept one global state file. Any session could flip it active, and the Stop hook then fired in every other session regardless of project. Fixed by keying state to sha256(cwd).",
  "salience": 0.9,
  "why": "Global mutable state shared across unrelated sessions — a class of bug worth recognizing elsewhere."
}

Example of correctly returning nothing:
Session was: opened a file, read two others, asked a clarifying question, conversation ended. No decisions reached, no preferences stated, no patterns uncovered. Return [].

Format:
- Respond with ONLY the JSON array. No preamble, no trailing prose, no code fences.
- Return [] when nothing meets the bar. Empty is correct; better than noise.
- The assistant turn is pre-filled with '[' — continue the array from that point and close with ']'."""


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
    transcript: str, model: str, api_key: str, timeout: float = 60.0
) -> dict[str, Any] | None:
    # Prefill assistant with '[' so Haiku starts a JSON array instead of drifting
    # into prose. The API returns only what the model generates *after* the
    # prefill, so the caller must prepend '[' before parsing.
    payload = {
        "model": model,
        "max_tokens": 4096,
        "system": [
            {
                "type": "text",
                "text": SYSTEM_PROMPT,
                "cache_control": {"type": "ephemeral"},
            }
        ],
        "messages": [
            {"role": "user", "content": transcript},
            {"role": "assistant", "content": "["},
        ],
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


def dump_raw(tag: str, raw: str) -> None:
    """Append a labeled raw-response block to summarize-raw.log in CWD/.memorizer/."""
    try:
        raw_log = Path.cwd() / ".memorizer" / "summarize-raw.log"
        raw_log.parent.mkdir(parents=True, exist_ok=True)
        with raw_log.open("a", encoding="utf-8") as f:
            ts = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            f.write(f"---- {tag} {ts} ----\n")
            f.write(raw)
            f.write("\n")
    except Exception as err:  # best-effort only
        log(f"dump_raw failed: {err}")


def _find_json_array(text: str) -> str | None:
    """Locate a JSON-shaped array in free-form text.

    Anchors on '[' followed by optional whitespace then '{' (array of objects)
    or ']' (empty array) — avoids grabbing prose tags like '[tool:Read ...]'
    or '[assistant]'. Returns the balanced [...] slice or None.
    """
    anchor = re.search(r"\[\s*(?:\{|\])", text)
    if not anchor:
        return None
    i = anchor.start()
    # Walk forward from the '[' tracking depth, respecting string quoting and
    # JSON escapes. Returns the matching closing ']'.
    depth = 0
    in_str = False
    esc = False
    for j in range(i, len(text)):
        c = text[j]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            continue
        if c == '"':
            in_str = True
        elif c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
            if depth == 0:
                return text[i : j + 1]
    return None


def parse_memories(raw: str) -> list[dict[str, Any]]:
    # Response may be prefilled with '[' — the API returns only what the model
    # generated after the prefill, so prepend '[' if the text looks like it
    # continues an array (i.e., doesn't already start with one).
    raw = raw.strip()
    if not raw:
        log("parse: empty response text")
        return []
    # Strip optional ```json fences
    if raw.startswith("```"):
        raw = re.sub(r"^```[a-zA-Z]*\s*", "", raw)
        raw = re.sub(r"\s*```$", "", raw)
        raw = raw.strip()
    if not raw.startswith("["):
        # Haiku prefill was '[' — add it back so parser sees a full array.
        raw = "[" + raw

    # 1. Try parsing the whole response first (the common, well-behaved case).
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        data = None

    # 2. Fall back to anchored array extraction if the whole-parse failed.
    if data is None:
        candidate = _find_json_array(raw)
        if candidate is None:
            log(f"parse: no JSON array anchor in response ({len(raw)} chars)")
            dump_raw("no-array", raw)
            return []
        try:
            data = json.loads(candidate)
        except json.JSONDecodeError as err:
            log(f"parse: JSONDecodeError at pos {err.pos}: {err.msg}")
            dump_raw("decode-error", raw)
            return []

    if not isinstance(data, list):
        log(f"parse: top-level JSON is {type(data).__name__}, not list")
        dump_raw("not-list", raw)
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
    stop_reason = response.get("stop_reason")
    in_tok = usage.get("input_tokens") or 0
    out_tok = usage.get("output_tokens") or 0
    cache_read = usage.get("cache_read_input_tokens") or 0
    cache_create = usage.get("cache_creation_input_tokens") or 0
    log(
        "usage: in={} out={} cache_read={} cache_create={} stop_reason={}".format(
            in_tok, out_tok, cache_read, cache_create, stop_reason
        )
    )
    if stop_reason == "max_tokens":
        log("WARN: hit max_tokens ceiling — response likely truncated")
    if cache_create == 0 and cache_read == 0:
        # Caching silently no-ops if the cacheable prefix is below the model's
        # minimum (1024 tokens for all current Claude models). Note it once.
        log(
            "WARN: cache_control had no effect — system prompt likely < 1024 tokens "
            "(Anthropic's caching minimum)"
        )
    text = extract_text(response)
    memories = parse_memories(text)
    log(f"parsed {len(memories)} valid memories from response ({len(text)} chars)")
    return memories


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
