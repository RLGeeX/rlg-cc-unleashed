#!/usr/bin/env bash
#
# Memorizer Hook: PreToolUse Write/Edit
# Checks Memorizer for do-not-repeat patterns before writes.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared.sh"

ensure_memorizer_dir
MEM_DIR=$(get_memorizer_dir)

# Parse stdin
input=$(cat 2>/dev/null || echo "{}")
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[[ -n "$file_path" ]] || exit 0

is_memorizer_path "$file_path" && exit 0

content=$(echo "$input" | jq -r '.tool_input.content // empty' 2>/dev/null)
old_string=$(echo "$input" | jq -r '.tool_input.old_string // empty' 2>/dev/null)
new_string=$(echo "$input" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
all_content="${content}${old_string}${new_string}"

[[ -n "$all_content" ]] || exit 0

base=$(basename "$file_path")

# Check do-not-repeat cache (populated on first call per session)
CACHE_FILE="${MEM_DIR}/do-not-repeat.json"

if [[ ! -f "$CACHE_FILE" ]] || [[ -n "$(find "$CACHE_FILE" -mmin +10 2>/dev/null)" ]]; then
  # Fetch from Memorizer
  project_id=$(get_project_id 2>/dev/null || echo "")
  if [[ -n "$project_id" ]]; then
    # Build query from filename + first 200 chars of content
    query="${base} ${all_content:0:200}"
    search_args=$(jq -n \
      --arg q "$query" \
      --arg pid "$project_id" \
      '{query:$q, filterTags:["correction","risk","do-not-repeat"], projectId:$pid, limit:5, minSimilarity:0.75}')

    result=$(call_memorizer "search_memories" "$search_args" 2 2>/dev/null) || true

    if [[ -n "$result" ]]; then
      # Parse and cache
      entries=$(echo "$result" | jq '
        (if type == "array" then . elif .memories then .memories else [] end) |
        [.[] | {title: (.title // "Untitled"), text: (.text // ""), similarity: (.similarity // 0)}]
      ' 2>/dev/null || echo "[]")
      write_json "$CACHE_FILE" "$(jq -n --argjson e "$entries" --arg ts "$(timestamp)" '{fetched:$ts, entries:$e}')"
    else
      write_json "$CACHE_FILE" "$(jq -n --arg ts "$(timestamp)" '{fetched:$ts, entries:[]}')"
    fi
  fi
fi

# Surface warnings from cache (max 2)
if [[ -f "$CACHE_FILE" ]]; then
  warnings=0
  entry_count=$(jq '.entries | length' "$CACHE_FILE" 2>/dev/null || echo "0")

  for i in $(seq 0 $((entry_count - 1))); do
    [[ $warnings -ge 2 ]] && break

    title=$(jq -r ".entries[$i].title" "$CACHE_FILE" 2>/dev/null)
    text=$(jq -r ".entries[$i].text" "$CACHE_FILE" 2>/dev/null)
    sim=$(jq -r ".entries[$i].similarity // 0" "$CACHE_FILE" 2>/dev/null)

    # Check relevance: high similarity or filename match
    relevant=false
    if echo "$title $text" | grep -qi "$base" 2>/dev/null; then
      relevant=true
    fi
    # High similarity always shows
    if awk "BEGIN{exit !($sim >= 0.85)}" 2>/dev/null; then
      relevant=true
    fi

    if [[ "$relevant" == "true" ]]; then
      preview=$(echo "$text" | head -1 | cut -c1-100)
      echo "⚠️ Memorizer: ${title} — ${preview}" >&2
      warnings=$((warnings + 1))
    fi
  done
fi

exit 0
