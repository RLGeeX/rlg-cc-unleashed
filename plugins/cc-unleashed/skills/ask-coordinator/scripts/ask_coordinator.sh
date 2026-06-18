#!/bin/bash
#
# ask_coordinator.sh - POST a worker STOP to the broker coordinator-oracle and
#                      return its verdict. The cc-unleashed half of the
#                      worker -> coordinator channel (ai-broker chunk-003).
#
# The broker persists BOTH the STOP and the verdict to the v3 a2a_messages
# table by construction, so this script does NOT log a2a itself -- it just
# calls the endpoint and surfaces the verdict for the worker lane to act on.
#
# Contract (broker side already built -- broker/coordinator/api.py):
#   POST {BROKER_URL}/a2a/coordinator/ask
#   request  (AskRequest):  { ticket_id, rid, stack, plan_dir, worker_role, stop_body }
#   response (AskResponse): { verdict }
#
# Usage:
#   ask_coordinator.sh \
#     --ticket-id RLG-123 \
#     --rid run-abc123 \
#     --stack rlg \
#     --plan-dir .claude/plans/ai-broker \
#     --worker-role dev \
#     --stop-file /path/to/stop-envelope.md
#
#   # stop_body may also be piped on stdin instead of --stop-file:
#   cat stop.md | ask_coordinator.sh --ticket-id ... --rid ... --stack ... \
#     --plan-dir ... --worker-role dev
#
# Flags:
#   --broker-url URL   Override BROKER_URL for this call.
#   --dry-run          Print the JSON payload that WOULD be POSTed; do not send.
#
# Config:
#   BROKER_URL   Broker base URL (default: http://localhost:8080).
#   ASK_TIMEOUT  curl --max-time seconds (default: 120; oracle verifies live state).
#
# Written for macOS bash 3.2 and Linux/WSL -- no bash-4-only features.

set -euo pipefail

DEFAULT_BROKER_URL="http://localhost:8080"
BROKER_URL="${BROKER_URL:-$DEFAULT_BROKER_URL}"
TIMEOUT_SECS="${ASK_TIMEOUT:-120}"

TICKET_ID=""
RID=""
STACK=""
PLAN_DIR=""
WORKER_ROLE=""
STOP_FILE=""
DRY_RUN=0

err() { echo "[ERROR] $1" >&2; }

usage() {
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-1}"
}

# --- parse args -------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ticket-id)   TICKET_ID="${2:-}"; shift 2 ;;
        --rid)         RID="${2:-}"; shift 2 ;;
        --stack)       STACK="${2:-}"; shift 2 ;;
        --plan-dir)    PLAN_DIR="${2:-}"; shift 2 ;;
        --worker-role) WORKER_ROLE="${2:-}"; shift 2 ;;
        --stop-file)   STOP_FILE="${2:-}"; shift 2 ;;
        --broker-url)  BROKER_URL="${2:-}"; shift 2 ;;
        --dry-run)     DRY_RUN=1; shift ;;
        -h|--help)     usage 0 ;;
        *) err "unknown argument: $1"; usage 1 ;;
    esac
done

# --- dependencies -----------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
    err "jq is required (brew install jq)"; exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
    err "curl is required"; exit 1
fi

# --- validate required fields ----------------------------------------------
missing=""
[[ -z "$TICKET_ID" ]]   && missing="$missing --ticket-id"
[[ -z "$RID" ]]         && missing="$missing --rid"
[[ -z "$STACK" ]]       && missing="$missing --stack"
[[ -z "$PLAN_DIR" ]]    && missing="$missing --plan-dir"
[[ -z "$WORKER_ROLE" ]] && missing="$missing --worker-role"
if [[ -n "$missing" ]]; then
    err "missing required flag(s):$missing"; usage 1
fi

# --- read the STOP body (file or stdin) -------------------------------------
STOP_BODY=""
if [[ -n "$STOP_FILE" ]]; then
    if [[ ! -f "$STOP_FILE" ]]; then
        err "stop-file not found: $STOP_FILE"; exit 1
    fi
    STOP_BODY="$(cat "$STOP_FILE")"
elif [[ ! -t 0 ]]; then
    STOP_BODY="$(cat)"
fi
if [[ -z "${STOP_BODY// }" ]]; then
    err "stop_body is empty -- pass --stop-file or pipe the STOP envelope on stdin"
    exit 1
fi

# --- build the request payload ---------------------------------------------
PAYLOAD=$(jq -n \
    --arg ticket_id   "$TICKET_ID" \
    --arg rid         "$RID" \
    --arg stack       "$STACK" \
    --arg plan_dir    "$PLAN_DIR" \
    --arg worker_role "$WORKER_ROLE" \
    --arg stop_body   "$STOP_BODY" \
    '{ticket_id:$ticket_id, rid:$rid, stack:$stack, plan_dir:$plan_dir, worker_role:$worker_role, stop_body:$stop_body}')

ENDPOINT="${BROKER_URL%/}/a2a/coordinator/ask"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] would POST to: $ENDPOINT"
    echo "$PAYLOAD" | jq .
    exit 0
fi

# --- POST and capture body + HTTP status ------------------------------------
TMP_BODY="$(mktemp)"
trap 'rm -f "$TMP_BODY"' EXIT

set +e
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TMP_BODY" \
    --max-time "$TIMEOUT_SECS" \
    -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>/dev/null)
CURL_RC=$?
set -e

if [[ "$CURL_RC" -ne 0 || -z "$HTTP_CODE" || "$HTTP_CODE" == "000" ]]; then
    err "could not reach broker at $ENDPOINT (connection failed / timeout)"
    err "is the broker running and BROKER_URL correct? (current: $BROKER_URL)"
    exit 1
fi

if [[ "$HTTP_CODE" != "200" ]]; then
    detail="$(jq -r '.detail // .message // empty' "$TMP_BODY" 2>/dev/null || true)"
    err "coordinator returned HTTP $HTTP_CODE${detail:+ - $detail}"
    exit 1
fi

VERDICT=$(jq -r '.verdict // empty' "$TMP_BODY" 2>/dev/null || true)
if [[ -z "$VERDICT" ]]; then
    err "200 OK but no verdict field in response:"
    cat "$TMP_BODY" >&2
    exit 1
fi

# --- emit the verdict for the lane to act on --------------------------------
echo "=== COORDINATOR VERDICT (ticket=$TICKET_ID rid=$RID) ==="
echo "$VERDICT"
