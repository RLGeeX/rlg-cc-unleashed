#!/usr/bin/env bash
#
# Initialize a persist-execute state file scoped to the current cwd.
#
# Usage:
#   init.sh --plan-path <path> --prompt <text> [options]
#
# Options:
#   --plan-path PATH           (required) plan directory
#   --prompt TEXT              (required) execution prompt re-fed each iteration
#   --max-iterations N         hard iteration cap (default: 10)
#   --timeout-minutes M        wall-clock cap in minutes (default: 60)
#   --completion-promise TEXT  output text that signals completion (default: PERSIST_COMPLETE)
#   --mode MODE                automated|supervised (default: automated)
#   --notes TEXT               free-form notes
#   --stop-at-chunk N          optional chunk index at which to halt
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLAN_PATH=""
PROMPT=""
MAX_ITERATIONS=10
TIMEOUT_MINUTES=60
COMPLETION_PROMISE="PERSIST_COMPLETE"
MODE="automated"
NOTES=""
STOP_AT_CHUNK=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plan-path)          PLAN_PATH="$2"; shift 2;;
        --prompt)             PROMPT="$2"; shift 2;;
        --max-iterations)     MAX_ITERATIONS="$2"; shift 2;;
        --timeout-minutes)    TIMEOUT_MINUTES="$2"; shift 2;;
        --completion-promise) COMPLETION_PROMISE="$2"; shift 2;;
        --mode)               MODE="$2"; shift 2;;
        --notes)              NOTES="$2"; shift 2;;
        --stop-at-chunk)      STOP_AT_CHUNK="$2"; shift 2;;
        *) echo "ERROR: unknown option: $1" >&2; exit 1;;
    esac
done

[[ -z "$PLAN_PATH" ]] && { echo "ERROR: --plan-path required" >&2; exit 1; }
[[ -z "$PROMPT" ]]    && { echo "ERROR: --prompt required" >&2; exit 1; }

STATE_FILE=$("${SCRIPT_DIR}/state-path.sh")
mkdir -p "$(dirname "$STATE_FILE")"

now=$(date +%s)
timeout_seconds=$((TIMEOUT_MINUTES * 60))
session_id="${CLAUDE_SESSION_ID:-unknown}"
project_cwd=$(pwd -P)

# One-time migration: archive any legacy global state file. The new hook
# ignores it, so leaving it would just be confusing cruft.
LEGACY_FILE="${HOME}/.claude/persist-execute-state.json"
if [[ -f "$LEGACY_FILE" ]]; then
    mv "$LEGACY_FILE" "${LEGACY_FILE}.legacy.bak.${now}" 2>/dev/null && \
        echo "Archived legacy global state to: ${LEGACY_FILE}.legacy.bak.${now}" >&2 || true
fi

if [[ -n "$STOP_AT_CHUNK" ]]; then
    jq -n \
        --arg cwd "$project_cwd" \
        --arg planPath "$PLAN_PATH" \
        --arg prompt "$PROMPT" \
        --arg promise "$COMPLETION_PROMISE" \
        --arg mode "$MODE" \
        --arg notes "$NOTES" \
        --arg session "$session_id" \
        --argjson maxIter "$MAX_ITERATIONS" \
        --argjson timeout "$timeout_seconds" \
        --argjson now "$now" \
        --argjson stopAt "$STOP_AT_CHUNK" \
        '{
            active: true,
            cwd: $cwd,
            planPath: $planPath,
            prompt: $prompt,
            iteration: 0,
            maxIterations: $maxIter,
            timeoutSeconds: $timeout,
            startTime: $now,
            lastHeartbeat: $now,
            completionPromise: $promise,
            mode: $mode,
            sessionId: $session,
            notes: $notes,
            stopAtChunk: $stopAt
        }' > "$STATE_FILE"
else
    jq -n \
        --arg cwd "$project_cwd" \
        --arg planPath "$PLAN_PATH" \
        --arg prompt "$PROMPT" \
        --arg promise "$COMPLETION_PROMISE" \
        --arg mode "$MODE" \
        --arg notes "$NOTES" \
        --arg session "$session_id" \
        --argjson maxIter "$MAX_ITERATIONS" \
        --argjson timeout "$timeout_seconds" \
        --argjson now "$now" \
        '{
            active: true,
            cwd: $cwd,
            planPath: $planPath,
            prompt: $prompt,
            iteration: 0,
            maxIterations: $maxIter,
            timeoutSeconds: $timeout,
            startTime: $now,
            lastHeartbeat: $now,
            completionPromise: $promise,
            mode: $mode,
            sessionId: $session,
            notes: $notes
        }' > "$STATE_FILE"
fi

echo "Initialized persist-execute state."
echo "  state file: $STATE_FILE"
echo "  project:    $project_cwd"
echo "  plan:       $PLAN_PATH"
echo "  safeguards: ${MAX_ITERATIONS} iterations, ${TIMEOUT_MINUTES}min timeout"
