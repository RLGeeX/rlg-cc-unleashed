#!/usr/bin/env bash
#
# Memorizer Hook: PostToolUse Write/Edit
# Updates anatomy index, tracks edit counts, detects bug-fix patterns.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared.sh"

ensure_memorizer_dir
MEM_DIR=$(get_memorizer_dir)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Parse stdin
input=$(cat 2>/dev/null || echo "{}")
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[[ -n "$file_path" ]] || exit 0

is_memorizer_path "$file_path" && exit 0
is_env_file "$file_path" && exit 0

# Short-circuit when cwd doesn't resolve to a registered Memorizer project.
# Without a project_id, any queued capture gets filed under Unfiled (noise).
get_project_id >/dev/null 2>&1 || exit 0

# Resolve absolute path
[[ "$file_path" == /* ]] || file_path="${PROJECT_DIR}/${file_path}"

rel_path=$(get_relative_path "$file_path")
base=$(basename "$file_path")
tool_name=$(echo "$input" | jq -r '.tool_name // "Write"' 2>/dev/null)
old_string=$(echo "$input" | jq -r '.tool_input.old_string // empty' 2>/dev/null)
new_string=$(echo "$input" | jq -r '.tool_input.new_string // empty' 2>/dev/null)

# Classify whether file is a documentation/prose file. Used to gate the bugfix
# heuristic, which fires false positives on doc content that happens to mention
# "catch", "import", "await", etc.
is_doc_file=0
case "$base" in
  CLAUDE.md|README.md|readme.md|CHANGELOG.md|LICENSE|LICENSE.md) is_doc_file=1 ;;
esac
case "${base##*.}" in
  md|mdx|txt|rst|MD|MDX|TXT|RST) is_doc_file=1 ;;
esac
case "/${rel_path}" in
  */docs/*|*/doc/*|*/.claude/*) is_doc_file=1 ;;
esac

# ── 1. Update anatomy.json ────────────────────────────────────────────────────

ANATOMY_FILE="${MEM_DIR}/anatomy.json"
desc=$(extract_description "$file_path" 2>/dev/null || echo "")
tokens=$(estimate_tokens "$file_path" 2>/dev/null || echo "0")
ts=$(timestamp)

if [[ -f "$ANATOMY_FILE" ]]; then
  anatomy=$(jq --arg p "$rel_path" --arg d "$desc" --argjson t "$tokens" --arg ts "$ts" '
    .files[$p] = {description: $d, tokens: $t, updated: $ts} |
    .last_updated = $ts' "$ANATOMY_FILE" 2>/dev/null)
else
  anatomy=$(jq -n --arg p "$rel_path" --arg d "$desc" --argjson t "$tokens" --arg ts "$ts" '
    {version: 1, last_updated: $ts, files: {($p): {description: $d, tokens: $t, updated: $ts}}}')
fi

[[ -n "$anatomy" ]] && write_json "$ANATOMY_FILE" "$anatomy"

# ── 2. Track edit count ───────────────────────────────────────────────────────

SESSION_FILE="${MEM_DIR}/_session.json"
session=$(read_json "$SESSION_FILE")

action="create"
[[ "$tool_name" != "Write" ]] && action="edit"

session=$(echo "$session" | jq \
  --arg p "$rel_path" \
  --arg action "$action" \
  --argjson t "$tokens" \
  --arg ts "$ts" '
  .edit_counts[$p] = ((.edit_counts[$p] // 0) + 1) |
  .files_written += [{file: $p, action: $action, tokens: $t, at: $ts}]')

write_json "$SESSION_FILE" "$session"

# Warn if file edited 3+ times
edit_count=$(echo "$session" | jq -r --arg p "$rel_path" '.edit_counts[$p] // 0')
if [[ "$edit_count" -ge 3 ]]; then
  echo "⚠️ Memorizer: ${base} edited ${edit_count} times this session. If fixing a bug, consider /memorize to log it." >&2
fi

# ── 3. Auto-detect bug-fix patterns ──────────────────────────────────────────
# Source-code only. Doc files trip the keyword heuristics on unrelated prose.

if [[ -n "$old_string" && -n "$new_string" && "$is_doc_file" -eq 0 ]]; then
  category="" summary="" root_cause="" fix=""

  # Error handling added
  if echo "$new_string" | grep -q 'catch' && ! echo "$old_string" | grep -q 'catch'; then
    category="error-handling"
    summary="Missing error handling"
    root_cause="Code path had no error handling"
    fix="Added try/catch block"
  # Null safety
  elif echo "$new_string" | grep -q '\?\.' && ! echo "$old_string" | grep -q '\.'; then
    category="null-safety"
    summary="Null/undefined access risk"
    root_cause="Property access on potentially null/undefined value"
    fix="Added null safety"
  elif echo "$new_string" | grep -q '??' && ! echo "$old_string" | grep -q '??'; then
    category="null-safety"
    summary="Null/undefined access risk"
    root_cause="Missing nullish coalescing"
    fix="Added nullish coalescing operator"
  # Missing await
  elif echo "$new_string" | grep -q 'await ' && ! echo "$old_string" | grep -q 'await '; then
    category="async-fix"
    summary="Missing await"
    root_cause="Async call without await"
    fix="Added await"
  # Missing import
  elif echo "$new_string" | grep -q '^import\|^from.*import' && ! echo "$old_string" | grep -q '^import\|^from.*import'; then
    category="missing-import"
    summary="Missing import"
    root_cause="Module not imported"
    fix="Added import"
  fi

  if [[ -n "$category" ]]; then
    queue_memorizer_sync "$(jq -n \
      --arg type "bugfix" \
      --arg ts "$ts" \
      --arg file "$rel_path" \
      --arg summary "$summary" \
      --arg category "$category" \
      --arg rootCause "$root_cause" \
      --arg fix "$fix" \
      '{type:$type, timestamp:$ts, data:{file:$file, summary:$summary, category:$category, rootCause:$rootCause, fix:$fix}}')"
  fi
fi

exit 0
