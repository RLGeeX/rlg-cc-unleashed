#!/usr/bin/env bash
#
# Memorizer A/B Compare — auto-capture rate, pre-4.7 vs post-4.7
#
# Queries Memorizer over a time window and counts memories grouped by source:
#   - stop-hook-synthesis (new, post-chunk-2)  → Phase 4.7 semantic auto-capture
#   - memorizer-hooks     (pre-4.7 baseline)   → Phase 4B anatomy/bugfix capture
#   - LLM                 (manual /memorize)   → User-invoked
#
# The MCP search_memories tool does not support filtering by source or by
# date directly, so this script samples a broad query (up to 200 memories)
# and groups client-side. Window is inclusive on both ends, UTC-naive
# matching the server's "Created:" format (YYYY-MM-DD HH:MM:SS).
#
# Usage:
#   memorizer-ab-compare.sh [--sample-query QUERY] \
#                          [--before-start DATE] [--before-end DATE] \
#                          [--after-start DATE]  [--after-end DATE] \
#                          [--project-id UUID]
#
# Defaults:
#   --sample-query    "session decision preference pattern bug fix"
#   Windows:          before = [now-14d, 2026-04-14 00:00)  (pre-chunk-2 landing)
#                     after  = [2026-04-14 00:00, now]
#   --project-id      global (no scope) — pass UUID for per-project counts

set -euo pipefail

MEMORIZER_URL="https://memorizer.rlgeex.com/mcp"
SAMPLE_LIMIT=200
SAMPLE_QUERY="session decision preference pattern bug fix"

# Chunk 2 landed 2026-04-14. Default pivot accordingly.
PIVOT="2026-04-14 00:00:00"
BEFORE_START=""
BEFORE_END="$PIVOT"
AFTER_START="$PIVOT"
AFTER_END=""
PROJECT_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sample-query)   SAMPLE_QUERY="$2"; shift 2;;
        --before-start)   BEFORE_START="$2"; shift 2;;
        --before-end)     BEFORE_END="$2";   shift 2;;
        --after-start)    AFTER_START="$2";  shift 2;;
        --after-end)      AFTER_END="$2";    shift 2;;
        --project-id)     PROJECT_ID="$2";   shift 2;;
        -h|--help)
            sed -n '/^# Usage:/,/^set /p' "$0" | sed 's/^# \{0,1\}//' | head -n -1
            exit 0;;
        *) echo "unknown option: $1" >&2; exit 2;;
    esac
done

# Fill default 14-day pre-pivot window
if [[ -z "$BEFORE_START" ]]; then
    # 14 days before pivot — portable across GNU/BSD date
    BEFORE_START=$(python3 -c "
from datetime import datetime, timedelta
pivot = datetime.fromisoformat('$PIVOT'.replace(' ', 'T'))
print((pivot - timedelta(days=14)).strftime('%Y-%m-%d %H:%M:%S'))
")
fi
if [[ -z "$AFTER_END" ]]; then
    AFTER_END=$(date -u +"%Y-%m-%d %H:%M:%S")
fi

# ── Call Memorizer ─────────────────────────────────────────────────────────

call_memorizer() {
    local args_json="$1"
    local request
    request=$(jq -n --argjson args "$args_json" \
        '{jsonrpc:"2.0",method:"tools/call",id:1,params:{name:"search_memories",arguments:$args}}')
    curl -s --max-time 10 -X POST "$MEMORIZER_URL" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -d "$request" | grep '^data:' | head -1 | sed 's/^data: //'
}

search_args=$(jq -n \
    --arg q "$SAMPLE_QUERY" \
    --argjson limit "$SAMPLE_LIMIT" \
    '{query:$q, limit:$limit, minSimilarity:0.0}')

if [[ -n "$PROJECT_ID" ]]; then
    search_args=$(echo "$search_args" | jq --arg pid "$PROJECT_ID" '. + {projectId:$pid}')
fi

resp=$(call_memorizer "$search_args")
content=$(echo "$resp" | jq -r '.result.content[0].text // empty')

if [[ -z "$content" ]] || echo "$content" | grep -q '^No memories found'; then
    echo "No memories returned for sample query. Either Memorizer is empty for this scope or unreachable." >&2
    exit 1
fi

# ── Tally client-side ──────────────────────────────────────────────────────

python3 - <<PY
import re, sys
from datetime import datetime

content = """$content"""

before_start = "$BEFORE_START"
before_end   = "$BEFORE_END"
after_start  = "$AFTER_START"
after_end    = "$AFTER_END"
scope        = "project $PROJECT_ID" if "$PROJECT_ID" else "global"

def parse_dt(s):
    try: return datetime.fromisoformat(s.replace(' ', 'T'))
    except Exception: return None

bs, be, as_, ae = map(parse_dt, (before_start, before_end, after_start, after_end))

# Split records on blank-line between memories, preserving blocks
blocks = re.split(r'\n(?=ID:\s)', content)
records = []
for block in blocks:
    rec = {}
    for line in block.splitlines():
        m = re.match(r'^([A-Za-z ]+):\s?(.*)$', line)
        if not m: continue
        k, v = m.group(1), m.group(2).strip()
        if k == 'Source':     rec['source']   = v
        elif k == 'Type':     rec['type']     = v
        elif k == 'Title':    rec['title']    = v
        elif k == 'Created':  rec['created']  = parse_dt(v)
        elif k == 'Tags':     rec['tags']     = v
    if 'source' in rec and 'created' in rec and rec['created']:
        records.append(rec)

def in_window(rec, start, end):
    if not rec['created']: return False
    if start and rec['created'] < start: return False
    if end and rec['created'] > end: return False
    return True

def tally(window_name, start, end):
    by_source = {}
    type_breakdown = {}
    for rec in records:
        if not in_window(rec, start, end): continue
        s = rec['source']
        by_source[s] = by_source.get(s, 0) + 1
        if s == 'stop-hook-synthesis':
            tags = rec.get('tags', '').lower()
            for t in ('decision','preference','pattern','risk','task','fact'):
                if t in tags: type_breakdown[t] = type_breakdown.get(t, 0) + 1
    return by_source, type_breakdown

print(f"== Memorizer A/B — {scope} ==\n")
print(f"Sample query: {'$SAMPLE_QUERY'}")
print(f"Sample size:  {len(records)} memories parsed from {'$SAMPLE_LIMIT'} returned\n")

pre_src,  pre_types  = tally("pre",  bs,  be)
post_src, post_types = tally("post", as_, ae)

def fmt_src(d):
    if not d: return "    (none)"
    rows = []
    for k in sorted(d, key=lambda k: -d[k]):
        rows.append(f"    {k:<24} {d[k]}")
    return "\n".join(rows)

print(f"--- Pre-4.7 window  [{before_start}  →  {before_end}] ---")
print(fmt_src(pre_src))
print()

print(f"--- Post-4.7 window [{after_start}  →  {after_end}] ---")
print(fmt_src(post_src))
if post_types:
    print("    stop-hook-synthesis type breakdown:")
    for k in sorted(post_types, key=lambda k: -post_types[k]):
        print(f"      {k:<20} {post_types[k]}")
print()

pre_auto  = pre_src.get('stop-hook-synthesis', 0)  + pre_src.get('memorizer-hooks', 0)
post_auto = post_src.get('stop-hook-synthesis', 0) + post_src.get('memorizer-hooks', 0)

print("--- Auto-capture totals (synthesis + hooks) ---")
print(f"    pre-4.7:  {pre_auto}")
print(f"    post-4.7: {post_auto}")
if pre_auto > 0:
    ratio = post_auto / pre_auto
    verdict = "HIT" if ratio >= 3.0 else "below"
    print(f"    ratio:    {ratio:.2f}x  (target ≥3.0x — {verdict})")
elif post_auto > 0:
    print("    ratio:    ∞  (pre-window had zero auto-captures in sample)")
else:
    print("    ratio:    n/a  (zero auto-captures in both windows — synthesis not yet firing in production)")
PY
