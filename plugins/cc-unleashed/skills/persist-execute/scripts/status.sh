#!/usr/bin/env bash
#
# List persist-execute state across all projects.
#
# Usage: status.sh
#

set -euo pipefail

STATE_DIR="${HOME}/.claude/persist-execute-state"
LEGACY_FILE="${HOME}/.claude/persist-execute-state.json"

if [[ -f "$LEGACY_FILE" ]]; then
    echo "WARNING: legacy global state file present at $LEGACY_FILE"
    echo "         (ignored by current hook; safe to delete)"
    echo
fi

if [[ ! -d "$STATE_DIR" ]]; then
    echo "No persist-execute state directory yet."
    exit 0
fi

shopt -s nullglob
files=("$STATE_DIR"/*.json)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
    echo "No persist-execute state files."
    exit 0
fi

now=$(date +%s)

for f in "${files[@]}"; do
    active=$(jq -r '.active // false' "$f")
    cwd=$(jq -r '.cwd // "unknown"' "$f")
    plan=$(jq -r '.planPath // "unknown"' "$f")
    iter=$(jq -r '.iteration // 0' "$f")
    max=$(jq -r '.maxIterations // 0' "$f")
    last_hb=$(jq -r '.lastHeartbeat // 0' "$f")
    age=$((now - last_hb))
    age_min=$((age / 60))

    if [[ "$active" == "true" ]]; then
        echo "[ACTIVE]   $cwd"
    else
        exit_reason=$(jq -r '.exitReason // "unknown"' "$f")
        echo "[inactive: $exit_reason]   $cwd"
    fi
    echo "    plan:    $plan"
    echo "    iter:    $iter / $max"
    echo "    last hb: ${age_min}min ago"
    echo "    file:    $f"
    echo
done
