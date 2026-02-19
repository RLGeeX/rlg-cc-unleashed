#!/usr/bin/env bash
#
# CC-Unleashed Memory Retrieval Hook - UserPromptSubmit
#
# Searches Memorizer for relevant memories and injects them into Claude's
# context before every user prompt. This is the highest-leverage piece of
# the memory integration — automatic retrieval without user intervention.
#
# Transport: Memorizer uses MCP Streamable HTTP (SSE) at /mcp
# Output: {"additionalContext": "..."} injected as system context
# Fallback: exits 0 silently if Memorizer is unreachable or no results
#
# Setup: Run scripts/setup-memory.sh once per machine to register the MCP server
# Cache: ~/.claude/memorizer-project-cache.json (workspace/project → UUID)
#

set -euo pipefail

MEMORIZER_URL="https://memorizer.rlgeex.com/mcp"
CACHE_FILE="${HOME}/.claude/memorizer-project-cache.json"
TIMEOUT=3
MAX_RESULTS=3
MIN_SIMILARITY=0.72
PRJ_ROOT="${HOME}/prj"

# ── Helpers ────────────────────────────────────────────────────────────────

# Call a Memorizer MCP tool. Parses the SSE response and returns content text.
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

# Extract content[0].text from MCP tool response JSON
extract_content_text() {
    jq -r '.result.content[0].text // empty' 2>/dev/null
}

# ── Bail-out guard ─────────────────────────────────────────────────────────

# Require jq and curl
command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

# ── Read hook input ────────────────────────────────────────────────────────

input=$(cat 2>/dev/null || echo "{}")

prompt=$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null || echo "")
cwd=$(echo "$input" | jq -r '.cwd // ""' 2>/dev/null || echo "")

# Nothing to search with
[[ -z "$prompt" ]] && exit 0

# Trim prompt to first 500 chars for the search query (avoid sending huge context)
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

    # Check cache first
    if [[ -f "$CACHE_FILE" ]]; then
        project_id=$(jq -r --arg k "$cache_key" '.[$k] // ""' "$CACHE_FILE" 2>/dev/null || echo "")
    fi

    # Not cached — look it up from Memorizer
    if [[ -z "$project_id" && -n "$project" ]]; then
        lookup_resp=$(call_memorizer "get_project_context" \
            "$(jq -n --arg q "$project" '{query:$q}')")

        if [[ -n "$lookup_resp" ]]; then
            content=$(echo "$lookup_resp" | extract_content_text)
            # get_project_context returns plain text; extract UUID from "ID: <uuid>" line
            project_id=$(echo "$content" | grep -oP 'ID:\s*\K[0-9a-f-]{36}' | head -1 || echo "")

            # Cache if found
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

# ── Search Memorizer ────────────────────────────────────────────────────────

search_args=$(jq -n \
    --arg q "$query" \
    --argjson limit "$MAX_RESULTS" \
    --argjson sim "$MIN_SIMILARITY" \
    '{query:$q,limit:$limit,minSimilarity:$sim}')

# Add project scope if we have an ID
if [[ -n "$project_id" && "$project_id" != "null" ]]; then
    search_args=$(echo "$search_args" | \
        jq --arg pid "$project_id" '. + {projectId:$pid}')
fi

search_resp=$(call_memorizer "search_memories" "$search_args")
[[ -z "$search_resp" ]] && exit 0

content_text=$(echo "$search_resp" | extract_content_text)
[[ -z "$content_text" ]] && exit 0

# Parse memory count
memory_count=$(echo "$content_text" | jq -r '
    if type == "array" then length
    elif .memories then (.memories | length)
    else 0
    end
' 2>/dev/null || echo "0")

[[ "$memory_count" == "0" || "$memory_count" == "null" ]] && exit 0

# ── Format context injection ────────────────────────────────────────────────

formatted=$(echo "$content_text" | jq -r '
    (if type == "array" then . elif .memories then .memories else [] end) |
    to_entries[] |
    "[\(.key + 1)] **\(.value.title // "Untitled")** (\(.value.type // "reference")" +
    (if .value.confidence then " | confidence: \(.value.confidence)" else "" end) + ")\n" +
    (.value.text // "" | split("\n") | .[0:3] | join("\n") | .[0:300])
' 2>/dev/null || echo "")

[[ -z "$formatted" ]] && exit 0

context="[MEMORIZER: ${memory_count} relevant memories for ${project_label}]

${formatted}

---"

printf '{"additionalContext":%s}' "$(printf '%s' "$context" | jq -Rs .)"
