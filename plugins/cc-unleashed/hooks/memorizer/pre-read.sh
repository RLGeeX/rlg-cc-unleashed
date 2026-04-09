#!/usr/bin/env bash
#
# Memorizer Hook: PreToolUse Read
# Highest-value hook — injects file descriptions and warns on re-reads.
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

# Skip .memorizer/ internal files
is_memorizer_path "$file_path" && exit 0

rel_path=$(get_relative_path "$file_path")
base=$(basename "$file_path")

SESSION_FILE="${MEM_DIR}/_session.json"
ANATOMY_FILE="${MEM_DIR}/anatomy.json"

# Load session
session=$(read_json "$SESSION_FILE")

# Re-read check
prev_count=$(echo "$session" | jq -r --arg p "$rel_path" '.files_read[$p].count // 0' 2>/dev/null)
if [[ "$prev_count" -gt 0 ]]; then
  prev_tokens=$(echo "$session" | jq -r --arg p "$rel_path" '.files_read[$p].tokens // 0' 2>/dev/null)
  tok_info=""
  [[ "$prev_tokens" -gt 0 ]] && tok_info=" (~${prev_tokens} tok)"
  echo "⚡ Memorizer: ${base} was already read this session${tok_info}. Consider using existing knowledge." >&2

  # Increment count and warned
  session=$(echo "$session" | jq --arg p "$rel_path" '
    .files_read[$p].count += 1 |
    .repeated_reads_warned += 1')
  write_json "$SESSION_FILE" "$session"
  exit 0
fi

# Anatomy lookup
if [[ -f "$ANATOMY_FILE" ]]; then
  anatomy_entry=$(jq -r --arg p "$rel_path" '.files[$p] // empty' "$ANATOMY_FILE" 2>/dev/null)
  if [[ -n "$anatomy_entry" ]]; then
    desc=$(echo "$anatomy_entry" | jq -r '.description // empty')
    tokens=$(echo "$anatomy_entry" | jq -r '.tokens // 0')
    [[ -n "$desc" ]] && echo "📋 Memorizer: ${base} — ${desc} (~${tokens} tok)" >&2
    session=$(echo "$session" | jq '.anatomy_hits += 1')
  else
    session=$(echo "$session" | jq '.anatomy_misses += 1')
  fi
else
  session=$(echo "$session" | jq '.anatomy_misses += 1')
fi

# Record initial read entry
session=$(echo "$session" | jq --arg p "$rel_path" --arg ts "$(timestamp)" '
  .files_read[$p] = {count: 1, tokens: 0, first_read: $ts}')

write_json "$SESSION_FILE" "$session"
exit 0
