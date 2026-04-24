#!/usr/bin/env bash
#
# Cancel persist-execute state.
#
# Usage:
#   cancel.sh                  cancel state for current cwd
#   cancel.sh --cwd PATH       cancel state for given cwd
#   cancel.sh --all            cancel every active state across all projects
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${HOME}/.claude/persist-execute-state"

deactivate_file() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    local active
    active=$(jq -r '.active // false' "$file" 2>/dev/null || echo "false")
    if [[ "$active" != "true" ]]; then
        return 2
    fi
    jq '.active = false | .exitReason = "user_cancelled"' "$file" \
        > "${file}.tmp" && mv "${file}.tmp" "$file"
    return 0
}

mode="cwd"
target_cwd="$PWD"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) mode="all"; shift;;
        --cwd) mode="cwd"; target_cwd="$2"; shift 2;;
        *) echo "ERROR: unknown option: $1" >&2; exit 1;;
    esac
done

if [[ "$mode" == "all" ]]; then
    cancelled=0
    if [[ -d "$STATE_DIR" ]]; then
        for f in "$STATE_DIR"/*.json; do
            [[ -f "$f" ]] || continue
            if deactivate_file "$f"; then
                cwd=$(jq -r '.cwd // "unknown"' "$f")
                iter=$(jq -r '.iteration // 0' "$f")
                echo "Cancelled: $cwd (after $iter iterations)"
                cancelled=$((cancelled + 1))
            fi
        done
    fi
    echo "Cancelled $cancelled active session(s)."
    exit 0
fi

state_file=$("${SCRIPT_DIR}/state-path.sh" "$target_cwd")
set +e
deactivate_file "$state_file"
rc=$?
set -e

case "$rc" in
    0)
        iter=$(jq -r '.iteration // 0' "$state_file")
        echo "Cancelled persist-execute for: $target_cwd"
        echo "Iterations used: $iter"
        echo "Normal exit now allowed."
        ;;
    1) echo "No persist-execute state for: $target_cwd";;
    2) echo "Persist-execute already inactive for: $target_cwd";;
esac
