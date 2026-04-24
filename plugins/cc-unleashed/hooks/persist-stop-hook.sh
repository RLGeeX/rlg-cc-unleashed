#!/usr/bin/env bash
#
# CC-Unleashed Persist Stop Hook
#
# Project-scoped persistence for plan execution.
#
# State path: ~/.claude/persist-execute-state/<sha256(cwd)[:16]>.json
# Hook reads stdin (Claude Code Stop hook input) for cwd, session_id,
# transcript_path; falls back to env / $PWD when stdin is empty.
#
# Behavior:
#   - No state file for current cwd  -> exit 0 (allow exit)
#   - State.active != true            -> exit 0
#   - lastHeartbeat older than ${PERSIST_HEARTBEAT_TIMEOUT:-1800}s
#                                     -> deactivate (heartbeat_stale), exit 0
#   - Wall clock past timeoutSeconds  -> deactivate (timeout), exit 0
#   - Iteration >= maxIterations      -> deactivate (max_iterations), exit 0
#   - Last assistant msg in transcript contains completionPromise
#                                     -> deactivate (completion_promise), exit 0
#   - Otherwise increment iteration, update lastHeartbeat, emit
#     {decision: block, reason: ...} JSON to keep the session alive.
#

set -uo pipefail

STATE_DIR="${HOME}/.claude/persist-execute-state"
HEARTBEAT_TIMEOUT_SECONDS="${PERSIST_HEARTBEAT_TIMEOUT:-1800}"

# Read stop-hook input (best-effort; never block).
HOOK_INPUT=$(cat 2>/dev/null || echo "{}")
[[ -z "$HOOK_INPUT" ]] && HOOK_INPUT="{}"

cwd=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
session_id=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")
transcript_path=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")

[[ -z "$cwd" ]]        && cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
[[ -z "$session_id" ]] && session_id="${CLAUDE_SESSION_ID:-unknown}"

# Resolve symlinks to match how init.sh keys the state file.
if [[ -d "$cwd" ]]; then
    cwd_resolved=$(cd "$cwd" 2>/dev/null && pwd -P || echo "$cwd")
else
    cwd_resolved="$cwd"
fi

if command -v shasum >/dev/null 2>&1; then
    key=$(printf '%s' "$cwd_resolved" | shasum -a 256 | cut -c1-16)
elif command -v sha256sum >/dev/null 2>&1; then
    key=$(printf '%s' "$cwd_resolved" | sha256sum | cut -c1-16)
else
    # No hash tool -> fail safe by allowing exit
    exit 0
fi

STATE_FILE="${STATE_DIR}/${key}.json"

# No state for this project -> normal exit. Sessions in unrelated projects
# can never be hijacked by an active state in another project.
[[ -f "$STATE_FILE" ]] || exit 0

state=$(cat "$STATE_FILE" 2>/dev/null || echo "{}")
active=$(echo "$state" | jq -r '.active // false' 2>/dev/null || echo "false")
[[ "$active" == "true" ]] || exit 0

iteration=$(echo "$state" | jq -r '.iteration // 0')
max_iterations=$(echo "$state" | jq -r '.maxIterations // 10')
prompt=$(echo "$state" | jq -r '.prompt // ""')
completion_promise=$(echo "$state" | jq -r '.completionPromise // "PERSIST_COMPLETE"')
plan_path=$(echo "$state" | jq -r '.planPath // ""')
start_time=$(echo "$state" | jq -r '.startTime // 0')
timeout_seconds=$(echo "$state" | jq -r '.timeoutSeconds // 3600')
last_heartbeat=$(echo "$state" | jq -r '.lastHeartbeat // .startTime // 0')

current_time=$(date +%s)
elapsed=$((current_time - start_time))
since_heartbeat=$((current_time - last_heartbeat))

write_state() {
    local jq_expr="$1"
    jq "$jq_expr" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null \
        && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# Heartbeat staleness: catches sessions that crashed mid-execution.
if [[ "$last_heartbeat" -gt 0 ]] && (( since_heartbeat > HEARTBEAT_TIMEOUT_SECONDS )); then
    write_state '.active = false | .exitReason = "heartbeat_stale"'
    exit 0
fi

# Wall-clock timeout
if (( elapsed >= timeout_seconds )); then
    write_state '.active = false | .exitReason = "timeout"'
    exit 0
fi

# Hard iteration cap
if (( iteration >= max_iterations )); then
    write_state '.active = false | .exitReason = "max_iterations"'
    exit 0
fi

# Output-string cancellation: if the transcript's most recent assistant
# message contains the completion promise text, deactivate and allow exit.
if [[ -n "$transcript_path" && -f "$transcript_path" && -n "$completion_promise" ]]; then
    last_assistant=$(tail -n 400 "$transcript_path" 2>/dev/null \
        | jq -r 'select(.type == "assistant") | (.message.content // []) | .[]? | select(.type == "text") | .text' 2>/dev/null \
        | tail -n 200 || echo "")
    if [[ -n "$last_assistant" ]] && echo "$last_assistant" | grep -qF "$completion_promise"; then
        write_state '.active = false | .exitReason = "completion_promise"'
        exit 0
    fi
fi

# Continue: increment iteration, refresh heartbeat, record session id.
new_iteration=$((iteration + 1))
write_state "$(printf '.iteration = %d | .lastHeartbeat = %d | .lastSessionId = "%s"' \
    "$new_iteration" "$current_time" "$session_id")"

remaining_time=$((timeout_seconds - elapsed))
remaining_mins=$((remaining_time / 60))

reason="PERSIST-EXECUTE ACTIVE (iteration ${new_iteration}/${max_iterations}, ${remaining_mins}min remaining)

Project: ${cwd_resolved}
Plan:    ${plan_path}

${prompt}

---
Safeguards:
- Iterations: ${new_iteration} of ${max_iterations} used
- Timeout:    ${remaining_mins} minutes remaining
- To cancel:  output '${completion_promise}' as the final line of your reply, or run /cc-unleashed:persist-cancel

Review previous work and continue where you left off. Check git status and test results."

cat <<EOF
{
  "decision": "block",
  "reason": $(echo "$reason" | jq -Rs .)
}
EOF
