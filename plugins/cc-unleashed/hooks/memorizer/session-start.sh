#!/usr/bin/env bash
#
# Memorizer Hook: SessionStart
# Creates .memorizer/, initializes session state, hydrates anatomy from Memorizer.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared.sh"

MEM_DIR=$(get_memorizer_dir)

# Create .memorizer/ if it doesn't exist
[[ -d "$MEM_DIR" ]] || mkdir -p "$MEM_DIR"

# Clean up stale .tmp files from failed atomic writes
find "$MEM_DIR" -maxdepth 1 -name '*.tmp' -delete 2>/dev/null || true

# Create fresh session state
SESSION_FILE="${MEM_DIR}/_session.json"
SESSION_ID="session-$(date +%Y-%m-%d-%H%M)"

write_json "$SESSION_FILE" "$(jq -n \
  --arg id "$SESSION_ID" \
  --arg started "$(timestamp)" \
  '{
    session_id: $id,
    started: $started,
    files_read: {},
    files_written: [],
    edit_counts: {},
    anatomy_hits: 0,
    anatomy_misses: 0,
    repeated_reads_warned: 0
  }')"

# Retry flushing any queued sync entries from previous sessions
QUEUE_FILE="${MEM_DIR}/sync-queue.json"
if [[ -f "$QUEUE_FILE" ]]; then
  entry_count=$(jq '.entries | length' "$QUEUE_FILE" 2>/dev/null || echo "0")
  if [[ "$entry_count" -gt 0 ]]; then
    project_id=$(get_project_id_with_fallback 2>/dev/null || echo "")
    remaining="[]"
    for i in $(seq 0 $((entry_count - 1))); do
      entry=$(jq ".entries[$i]" "$QUEUE_FILE" 2>/dev/null) || continue
      entry_type=$(echo "$entry" | jq -r '.type // empty')
      entry_data=$(echo "$entry" | jq -r '.data | tojson')

      args=$(jq -n \
        --arg type "$([ "$entry_type" = "anatomy" ] && echo "reference" || echo "how-to")" \
        --arg text "$entry_data" \
        --arg title "$(echo "$entry" | jq -r 'if .type == "anatomy" then "Anatomy update" else "Bugfix: " + (.data.summary // "auto-detected") end')" \
        --arg source "memorizer-hooks" \
        '{type:$type, text:$text, title:$title, source:$source, confidence:0.8}')

      [[ -n "$project_id" ]] && args=$(echo "$args" | jq --arg pid "$project_id" '. + {projectId:$pid}')

      if ! call_memorizer "store" "$args" >/dev/null 2>&1; then
        remaining=$(echo "$remaining" | jq --argjson e "$entry" '. += [$e]')
      fi
    done
    write_json "$QUEUE_FILE" "$(jq -n --argjson entries "$remaining" '{entries:$entries}')"
  fi
fi

# Hydrate anatomy from Memorizer if missing or stale (>24h)
ANATOMY_FILE="${MEM_DIR}/anatomy.json"
needs_hydration=false

if [[ ! -f "$ANATOMY_FILE" ]]; then
  needs_hydration=true
else
  # Check if older than 24 hours (86400 seconds)
  if [[ "$(uname)" == "Darwin" ]]; then
    file_age=$(( $(date +%s) - $(stat -f %m "$ANATOMY_FILE") ))
  else
    file_age=$(( $(date +%s) - $(stat -c %Y "$ANATOMY_FILE") ))
  fi
  [[ $file_age -gt 86400 ]] && needs_hydration=true
fi

if [[ "$needs_hydration" == "true" ]]; then
  project_id=$(get_project_id_with_fallback 2>/dev/null || echo "")
  if [[ -n "$project_id" ]]; then
    result=$(call_memorizer "search_memories" \
      "$(jq -n --arg pid "$project_id" '{query:"file anatomy index",filterTags:["anatomy"],projectId:$pid,limit:1,minSimilarity:0.5}')" \
      2>/dev/null) || true

    if [[ -n "$result" ]]; then
      # Try to parse as anatomy JSON
      parsed=$(echo "$result" | jq 'if .files then . else empty end' 2>/dev/null) || true
      if [[ -n "$parsed" ]]; then
        write_json "$ANATOMY_FILE" "$(echo "$parsed" | jq --arg ts "$(timestamp)" '. + {last_updated:$ts}')"
      fi
    fi
  fi
fi

# Report anatomy status
if [[ -f "$ANATOMY_FILE" ]]; then
  file_count=$(jq '.files | length' "$ANATOMY_FILE" 2>/dev/null || echo "0")
  if [[ "$file_count" -gt 0 ]]; then
    echo "📋 Memorizer: ${file_count} files indexed." >&2
  else
    echo "💡 Memorizer: No file index yet. It will build automatically as you work." >&2
  fi
else
  echo "💡 Memorizer: No file index yet. It will build automatically as you work." >&2
fi

exit 0
