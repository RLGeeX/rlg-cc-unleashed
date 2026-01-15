#!/usr/bin/env bash
#
# CC-Unleashed Persist Stop Hook
#
# Implements Ralph Wiggum-style persistence for plan execution.
# Checks for active persist-execute session and blocks exit if:
# - Session is active
# - Under max iterations
# - Completion promise not found
#
# State file: ~/.claude/persist-execute-state.json
#

set -euo pipefail

STATE_FILE="${HOME}/.claude/persist-execute-state.json"

# If no state file, allow normal exit
if [[ ! -f "$STATE_FILE" ]]; then
    exit 0
fi

# Read state
state=$(cat "$STATE_FILE")

# Check if session is active
active=$(echo "$state" | jq -r '.active // false')
if [[ "$active" != "true" ]]; then
    exit 0
fi

# Get current iteration and max
iteration=$(echo "$state" | jq -r '.iteration // 0')
max_iterations=$(echo "$state" | jq -r '.maxIterations // 10')
prompt=$(echo "$state" | jq -r '.prompt // ""')
completion_promise=$(echo "$state" | jq -r '.completionPromise // "PERSIST_COMPLETE"')
plan_path=$(echo "$state" | jq -r '.planPath // ""')
start_time=$(echo "$state" | jq -r '.startTime // 0')
timeout_seconds=$(echo "$state" | jq -r '.timeoutSeconds // 3600')

# Check timeout (default 1 hour)
current_time=$(date +%s)
elapsed=$((current_time - start_time))
if [[ $elapsed -ge $timeout_seconds ]]; then
    # Timeout reached - deactivate and allow exit
    jq '.active = false | .exitReason = "timeout"' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    exit 0
fi

# Check max iterations
if [[ $iteration -ge $max_iterations ]]; then
    # Max iterations reached - deactivate and allow exit
    jq '.active = false | .exitReason = "max_iterations"' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    exit 0
fi

# Increment iteration counter
new_iteration=$((iteration + 1))
jq --argjson iter "$new_iteration" '.iteration = $iter' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# Calculate remaining
remaining=$((max_iterations - new_iteration))
remaining_time=$((timeout_seconds - elapsed))
remaining_mins=$((remaining_time / 60))

# Build reason to continue
reason="PERSIST-EXECUTE ACTIVE (iteration $new_iteration/$max_iterations, ${remaining_mins}min remaining)

Continue executing the plan at: $plan_path

$prompt

---
Safeguards:
- Iterations: $new_iteration of $max_iterations used
- Timeout: ${remaining_mins} minutes remaining
- To cancel: Output '$completion_promise' or run /cc-unleashed:persist-cancel

Review previous work and continue where you left off. Check git status and test results."

# Output JSON to block exit and provide continuation reason
cat <<EOF
{
  "decision": "block",
  "reason": $(echo "$reason" | jq -Rs .)
}
EOF
