#!/usr/bin/env bash
#
# Memorizer Hook: Stop
# Flushes sync queue to Memorizer and emits session summary.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared.sh"

ensure_memorizer_dir
MEM_DIR=$(get_memorizer_dir)

# Read stdin (Stop hook receives session info as JSON)
HOOK_INPUT=$(cat 2>/dev/null || echo "{}")
SESSION_ID="${CLAUDE_SESSION_ID:-}"
if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")
fi

SESSION_FILE="${MEM_DIR}/_session.json"
session=$(read_json "$SESSION_FILE")

read_count=$(echo "$session" | jq '.files_read | length' 2>/dev/null || echo "0")
write_count=$(echo "$session" | jq '.files_written | length' 2>/dev/null || echo "0")

# Skip if no activity
[[ "$read_count" -gt 0 || "$write_count" -gt 0 ]] || exit 0

# Flush sync queue
QUEUE_FILE="${MEM_DIR}/sync-queue.json"
if [[ -f "$QUEUE_FILE" ]]; then
  entry_count=$(jq '.entries | length' "$QUEUE_FILE" 2>/dev/null || echo "0")
  if [[ "$entry_count" -gt 0 ]]; then
    project_id=$(get_project_id 2>/dev/null || echo "")
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

# --- Session synthesis (Phase 4.7) -------------------------------------------
# Summarize transcript via Haiku, dedup, and store as typed memories.
# Silently no-ops when ANTHROPIC_API_KEY or SESSION_ID is missing.
if [[ -n "${ANTHROPIC_API_KEY:-}" && -n "$SESSION_ID" ]]; then
  synth_project_id=$(get_project_id 2>/dev/null || echo "")
  if [[ -n "$synth_project_id" ]]; then
    mem_log="${MEM_DIR}/summarize.log"
    memories=$("${SCRIPT_DIR}/summarize.py" \
      --session-id "$SESSION_ID" \
      --project-id "$synth_project_id" \
      2>>"$mem_log" || echo "[]")

    mem_count=$(echo "$memories" | jq 'length' 2>/dev/null || echo "0")
    [[ "$mem_count" =~ ^[0-9]+$ ]] || mem_count=0
    stored=0

    if [[ "$mem_count" -gt 0 ]]; then
      for i in $(seq 0 $((mem_count - 1))); do
        memory=$(echo "$memories" | jq ".[$i]" 2>/dev/null) || continue
        if store_with_dedup "$memory" "$synth_project_id"; then
          stored=$((stored + 1))
        fi
      done
      echo "🧠 Memorizer: synthesized ${stored}/${mem_count} memories from session" >&2
    fi
  fi
fi

# Calculate stats
repeated_warns=$(echo "$session" | jq '.repeated_reads_warned // 0' 2>/dev/null)
anatomy_hits=$(echo "$session" | jq '.anatomy_hits // 0' 2>/dev/null)

total_read_tokens=$(echo "$session" | jq '[.files_read[].tokens] | add // 0' 2>/dev/null)
total_write_tokens=$(echo "$session" | jq '[.files_written[].tokens] | add // 0' 2>/dev/null)

# Estimate savings: anatomy hits save ~200 tok each, re-reads blocked save their token count
saved_from_anatomy=$(( anatomy_hits * 200 ))
saved_from_repeats=$(echo "$session" | jq '
  [.files_read | to_entries[] | select(.value.count > 1) | .value.tokens * (.value.count - 1)] | add // 0
' 2>/dev/null)
total_saved=$(( saved_from_anatomy + saved_from_repeats ))

# Emit session summary
parts="${read_count} reads"
[[ "$repeated_warns" -gt 0 ]] && parts="${parts}, ${repeated_warns} re-reads warned"
parts="${parts}, ${write_count} writes"
[[ "$total_saved" -gt 0 ]] && parts="${parts}, ~${total_saved} tok saved"
parts="${parts}, ~$(( total_read_tokens + total_write_tokens )) tok total"

echo "📊 Memorizer session: ${parts}" >&2

# Warn about heavily-edited files
multi_edit_files=$(echo "$session" | jq -r '
  [.edit_counts | to_entries[] | select(.value >= 3) | .key | split("/") | last] | join(", ")
' 2>/dev/null)

if [[ -n "$multi_edit_files" ]]; then
  echo "💡 Memorizer: ${multi_edit_files} edited 3+ times. Consider /memorize to capture learnings." >&2
fi

exit 0
