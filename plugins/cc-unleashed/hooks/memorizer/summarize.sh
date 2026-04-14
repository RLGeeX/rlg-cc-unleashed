#!/usr/bin/env bash
#
# Thin wrapper that invokes summarize.py with the same argv.
# Exists so shell callers don't need to know whether to use `python3`
# directly; always exits 0 even if Python is missing (swallowed by Stop hook).
#
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${SCRIPT_DIR}/summarize.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[summarize.sh] python3 not found" >&2
  echo "[]"
  exit 0
fi

python3 "$PY" "$@"
exit 0
