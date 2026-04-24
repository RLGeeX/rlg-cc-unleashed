#!/usr/bin/env bash
#
# Compute the persist-execute state file path for a given cwd.
# Default cwd is the current working directory.
#
# Usage: state-path.sh [cwd]
#
# Output: absolute path to the state JSON file (does not create it).
#

set -euo pipefail

cwd="${1:-${PWD}}"

# Resolve symlinks so /tmp and /private/tmp on macOS hash to the same key.
if [[ -d "$cwd" ]]; then
    cwd_resolved=$(cd "$cwd" 2>/dev/null && pwd -P || echo "$cwd")
else
    cwd_resolved="$cwd"
fi

# Hash the resolved cwd. shasum is on macOS, sha256sum on most Linuxes.
if command -v shasum >/dev/null 2>&1; then
    hash=$(printf '%s' "$cwd_resolved" | shasum -a 256 | cut -c1-16)
elif command -v sha256sum >/dev/null 2>&1; then
    hash=$(printf '%s' "$cwd_resolved" | sha256sum | cut -c1-16)
else
    echo "ERROR: neither shasum nor sha256sum available" >&2
    exit 1
fi

echo "${HOME}/.claude/persist-execute-state/${hash}.json"
