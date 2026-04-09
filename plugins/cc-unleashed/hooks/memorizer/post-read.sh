#!/usr/bin/env bash
#
# Memorizer Hook: PostToolUse Read
# Records actual token estimates after a file is read.
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

rel_path=$(get_relative_path "$file_path")

# Estimate tokens from file size (PostToolUse doesn't include file content in stdin)
tokens=0
if [[ -f "$file_path" ]]; then
  tokens=$(estimate_tokens "$file_path")
fi

# Fallback to anatomy estimate
if [[ "$tokens" -eq 0 ]]; then
  ANATOMY_FILE="${MEM_DIR}/anatomy.json"
  if [[ -f "$ANATOMY_FILE" ]]; then
    tokens=$(jq -r --arg p "$rel_path" '.files[$p].tokens // 0' "$ANATOMY_FILE" 2>/dev/null || echo "0")
  fi
fi

# Update session state
SESSION_FILE="${MEM_DIR}/_session.json"
session=$(read_json "$SESSION_FILE")

session=$(echo "$session" | jq --arg p "$rel_path" --argjson t "$tokens" --arg ts "$(timestamp)" '
  if .files_read[$p] then
    .files_read[$p].tokens = $t
  else
    .files_read[$p] = {count: 1, tokens: $t, first_read: $ts}
  end')

write_json "$SESSION_FILE" "$session"
exit 0
