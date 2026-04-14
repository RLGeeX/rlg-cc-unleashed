#!/usr/bin/env bash
#
# CC-Unleashed Memory Retrieval Hook — UserPromptSubmit
#
# Phase 4.7 chunk 4: client-side tightening. Fetches 5 candidates, ranks by
# salience (confidence) × recency, injects only the top 3 with truncated
# bodies. ~40%+ token reduction vs pre-4.7 baseline with no server changes.
#
# Transport: Memorizer MCP Streamable HTTP (SSE) at /mcp
# Output: {"additionalContext": "..."} injected as system context
# Fallback: exits 0 silently if Memorizer is unreachable or no results meet floor
#

set -euo pipefail

MEMORIZER_URL="https://memorizer.rlgeex.com/mcp"
CACHE_FILE="${HOME}/.claude/memorizer-project-cache.json"
TIMEOUT=3
FETCH_LIMIT=5           # fetch this many, rank client-side, keep top INJECT_LIMIT
INJECT_LIMIT=2          # inject only top 2 highest-scoring memories
MIN_SIMILARITY=0.7      # score floor — drop noise before it hits the ranker
BODY_MAX_LINES=2        # keep first N lines of body per memory
BODY_MAX_CHARS=160      # per-memory body cap — prevents one outlier dominating
RECENCY_HALFLIFE_DAYS=30
PRJ_ROOT="${HOME}/prj"

# ── Helpers ────────────────────────────────────────────────────────────────

call_memorizer() {
    local tool_name="$1"
    local args_json="$2"
    local request
    request=$(jq -n \
        --arg tool "$tool_name" \
        --argjson args "$args_json" \
        '{jsonrpc:"2.0",method:"tools/call",id:1,params:{name:$tool,arguments:$args}}')

    curl -s --max-time "$TIMEOUT" -X POST "$MEMORIZER_URL" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -d "$request" \
        2>/dev/null \
        | grep '^data:' | head -1 | sed 's/^data: //'
}

extract_content_text() {
    jq -r '.result.content[0].text // empty' 2>/dev/null
}

# Parse Memorizer's plain-text search response into a JSON array.
# Server emits records separated by blank lines with keyed fields.
parse_memories_to_json() {
    awk '
    function esc(s) {
        gsub(/\\/, "\\\\", s)
        gsub(/"/,  "\\\"", s)
        gsub(/\n/, "\\n",  s)
        gsub(/\t/, "\\t",  s)
        gsub(/\r/, "",     s)
        return s
    }
    function flush() {
        if (!has) return
        if (!first) printf ","
        first = 0
        printf "{\"id\":\"%s\",\"title\":\"%s\",\"type\":\"%s\",\"confidence\":%s,\"similarity\":%s,\"created\":\"%s\",\"text\":\"%s\"}",
            esc(id), esc(title), esc(type),
            (conf  == "" ? "0.5" : conf),
            (sim   == "" ? "0"   : sim),
            esc(created), esc(text)
    }
    BEGIN { printf "["; first = 1; has = 0; tcap = 0 }
    /^ID: /        { flush(); has=1; id=substr($0,5); title=""; type=""; conf=""; sim=""; created=""; text=""; tcap=0; next }
    /^Title: /     { title=substr($0,8); next }
    /^Type: /      { type=substr($0,7); next }
    /^Confidence: Confidence: / { conf=substr($0,25); next }
    /^Similarity: / { sim=substr($0,13); sub(/%.*/, "", sim); if (sim != "") sim = sim/100; next }
    /^Created: /   { created=substr($0,10); next }
    /^Text: /      { text=substr($0,7); tcap=1; next }
    /^Source: |^Tags: |^Owner: |^Archetype: |^URL: / { tcap=0; next }
    tcap == 1      { text = (text == "" ? $0 : text "\n" $0); next }
    END            { flush(); printf "]" }
    '
}

# ── Bail-out guard ─────────────────────────────────────────────────────────

command -v jq   >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0
command -v awk  >/dev/null 2>&1 || exit 0

# ── Read hook input ────────────────────────────────────────────────────────

input=$(cat 2>/dev/null || echo "{}")
prompt=$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null || echo "")
cwd=$(echo "$input" | jq -r '.cwd // ""'    2>/dev/null || echo "")

[[ -z "$prompt" ]] && exit 0
query="${prompt:0:500}"

# ── Detect project from cwd ────────────────────────────────────────────────

project_id=""
project_label="global"

if [[ -n "$cwd" && "$cwd" == "${PRJ_ROOT}/"* ]]; then
    relative="${cwd#${PRJ_ROOT}/}"
    org=$(echo "$relative" | cut -d'/' -f1)
    project=$(echo "$relative" | cut -d'/' -f2)
    cache_key="${org}/${project}"
    project_label="$cache_key"

    if [[ -f "$CACHE_FILE" ]]; then
        project_id=$(jq -r --arg k "$cache_key" '.[$k] // ""' "$CACHE_FILE" 2>/dev/null || echo "")
    fi

    if [[ -z "$project_id" && -n "$project" ]]; then
        lookup_resp=$(call_memorizer "get_project_context" \
            "$(jq -n --arg q "$project" '{query:$q}')")

        if [[ -n "$lookup_resp" ]]; then
            content=$(echo "$lookup_resp" | extract_content_text)
            project_id=$(echo "$content" | grep -oE 'ID:[[:space:]]*[0-9a-f-]{36}' | head -1 | awk '{print $2}' || echo "")

            if [[ -n "$project_id" && "$project_id" != "null" ]]; then
                mkdir -p "$(dirname "$CACHE_FILE")"
                if [[ -f "$CACHE_FILE" ]]; then
                    jq --arg k "$cache_key" --arg v "$project_id" \
                        '.[$k] = $v' "$CACHE_FILE" \
                        > "${CACHE_FILE}.tmp" && mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
                else
                    jq -n --arg k "$cache_key" --arg v "$project_id" \
                        '{($k): $v}' > "$CACHE_FILE"
                fi
            fi
        fi
    fi
fi

# ── Search Memorizer (wide fetch, tight floor) ─────────────────────────────

search_args=$(jq -n \
    --arg q "$query" \
    --argjson limit "$FETCH_LIMIT" \
    --argjson sim "$MIN_SIMILARITY" \
    '{query:$q,limit:$limit,minSimilarity:$sim}')

if [[ -n "$project_id" && "$project_id" != "null" ]]; then
    search_args=$(echo "$search_args" | jq --arg pid "$project_id" '. + {projectId:$pid}')
fi

search_resp=$(call_memorizer "search_memories" "$search_args" || echo "")
[[ -z "$search_resp" ]] && exit 0

content_text=$(echo "$search_resp" | extract_content_text)
[[ -z "$content_text" ]] && exit 0

# "No memories found" sentinel — exit silently, don't inject noise
echo "$content_text" | grep -q '^No memories found' && exit 0

# ── Parse + rank client-side ───────────────────────────────────────────────

records=$(echo "$content_text" | parse_memories_to_json)
[[ -z "$records" || "$records" == "[]" ]] && exit 0

now_epoch=$(date +%s)
halflife_sec=$((RECENCY_HALFLIFE_DAYS * 86400))

ranked=$(echo "$records" | jq \
    --argjson now "$now_epoch" \
    --argjson halflife "$halflife_sec" \
    --argjson keep "$INJECT_LIMIT" \
    --argjson cap "$BODY_MAX_CHARS" \
    --argjson lines "$BODY_MAX_LINES" '
    map(
      . + {
        _created_epoch: ((.created | strptime("%Y-%m-%d %H:%M:%S") | mktime) // $now),
      }
    )
    | map(
      . + {
        _recency: (
          (($now - ._created_epoch) / $halflife)
          | if . >= 1 then 0 else (1.0 - .) end
        ),
        _salience: (.confidence // 0.5)
      }
    )
    | map(. + { _score: (._salience * 0.6 + ._recency * 0.4) })
    | sort_by(-._score)
    | .[0:$keep]
    | map(. + { text: (.text | split("\n") | .[0:$lines] | join("\n") | .[0:$cap]) })
')

hit_count=$(echo "$ranked" | jq 'length' 2>/dev/null || echo "0")
[[ "$hit_count" -eq 0 ]] && exit 0

# ── Format + emit ──────────────────────────────────────────────────────────

formatted=$(echo "$ranked" | jq -r '
    to_entries[]
    | "[\(.key + 1)] \(.value.title // "Untitled") (\(.value.type // "reference"))\n\(.value.text)"
')

context="[MEMORIZER: ${hit_count} relevant memories for ${project_label}]

${formatted}

---"

printf '{"additionalContext":%s}' "$(printf '%s' "$context" | jq -Rs .)"
