#!/usr/bin/env bash
#
# Isolation + behavior test for persist-stop-hook.sh and helper scripts.
#
# Verifies the regression that motivated the rewrite: state for project A
# must NOT cause the hook to block exit when fired from project B.
#
# Run directly:  bash scripts/test-isolation.sh
# All side-effects land in $TMPDIR; the user's real ~/.claude is untouched
# because we override $HOME for the test.
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${PLUGIN_ROOT}/hooks/persist-stop-hook.sh"
INIT="${SCRIPT_DIR}/init.sh"
CANCEL="${SCRIPT_DIR}/cancel.sh"
STATE_PATH="${SCRIPT_DIR}/state-path.sh"
STATUS="${SCRIPT_DIR}/status.sh"

# Sandbox HOME so we never touch the real one.
TEST_ROOT=$(mktemp -d -t persist-test-XXXXXX)
export HOME="${TEST_ROOT}/home"
mkdir -p "${HOME}/.claude"

PROJECT_A="${TEST_ROOT}/project-a"
PROJECT_B="${TEST_ROOT}/project-b"
mkdir -p "$PROJECT_A" "$PROJECT_B"

PASS=0; FAIL=0
declare -a FAIL_NAMES

assert() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "        expected: $expected"
        echo "        actual:   $actual"
        FAIL=$((FAIL + 1))
        FAIL_NAMES+=("$label")
    fi
}

contains() {
    local label="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label  (needle '$needle' not found)"
        echo "        haystack: $haystack"
        FAIL=$((FAIL + 1))
        FAIL_NAMES+=("$label")
    fi
}

fire_hook() {
    local cwd="$1" transcript="${2:-}"
    local input
    if [[ -n "$transcript" ]]; then
        input=$(jq -n --arg cwd "$cwd" --arg sid "test-session" --arg t "$transcript" \
            '{cwd: $cwd, session_id: $sid, transcript_path: $t, stop_hook_active: true}')
    else
        input=$(jq -n --arg cwd "$cwd" --arg sid "test-session" \
            '{cwd: $cwd, session_id: $sid, stop_hook_active: true}')
    fi
    echo "$input" | "$HOOK" 2>/dev/null
}

echo "=== persist-execute isolation tests ==="
echo "Sandbox HOME: $HOME"
echo

# -----------------------------------------------------------------------
# Test 1: hook with no state files -> exits 0, no output
# -----------------------------------------------------------------------
echo "Test 1: hook with no state files"
out=$(fire_hook "$PROJECT_A")
assert "no output when no state" "" "$out"
echo

# -----------------------------------------------------------------------
# Test 2: state for project A; hook fired from project B -> NO hijack
# This is the core regression test for the chain-mountain incident.
# -----------------------------------------------------------------------
echo "Test 2: cross-project isolation (the regression)"
(cd "$PROJECT_A" && "$INIT" \
    --plan-path "$PROJECT_A/.claude/plans/plan-a" \
    --prompt "Continue plan A" \
    --max-iterations 5 \
    --timeout-minutes 60 >/dev/null)

out_b=$(fire_hook "$PROJECT_B")
assert "hook from project B sees no state" "" "$out_b"
echo

# -----------------------------------------------------------------------
# Test 3: hook fired from project A -> blocks and includes plan A
# -----------------------------------------------------------------------
echo "Test 3: same-project hook fires"
out_a=$(fire_hook "$PROJECT_A")
contains "block decision emitted"    '"decision": "block"' "$out_a"
contains "plan A path in reason"     "plan-a"             "$out_a"
contains "iteration counter present" "iteration 1/5"       "$out_a"

state_a=$("$STATE_PATH" "$PROJECT_A")
iter=$(jq -r '.iteration' "$state_a")
assert "iteration incremented to 1" "1" "$iter"
echo

# -----------------------------------------------------------------------
# Test 4: cancel.sh deactivates state for current cwd
# -----------------------------------------------------------------------
echo "Test 4: cancel for current cwd"
(cd "$PROJECT_A" && "$CANCEL" >/dev/null)
active=$(jq -r '.active' "$state_a")
exit_reason=$(jq -r '.exitReason' "$state_a")
assert "active flipped to false"      "false"          "$active"
assert "exitReason = user_cancelled"  "user_cancelled" "$exit_reason"

# Hook should now allow exit
out=$(fire_hook "$PROJECT_A")
assert "hook allows exit after cancel" "" "$out"
echo

# -----------------------------------------------------------------------
# Test 5: stale heartbeat auto-deactivation
# -----------------------------------------------------------------------
echo "Test 5: stale heartbeat auto-deactivates"
(cd "$PROJECT_A" && "$INIT" \
    --plan-path "$PROJECT_A/.claude/plans/plan-a" \
    --prompt "Continue plan A" \
    --max-iterations 5 \
    --timeout-minutes 60 >/dev/null)

# Backdate lastHeartbeat to 1 hour ago
old_ts=$(($(date +%s) - 3600))
jq --argjson ts "$old_ts" '.lastHeartbeat = $ts' "$state_a" > "${state_a}.tmp" && mv "${state_a}.tmp" "$state_a"

# Use 1800s default (30min) — 1 hour ago should be stale
out=$(fire_hook "$PROJECT_A")
assert "stale heartbeat allows exit" "" "$out"
exit_reason=$(jq -r '.exitReason' "$state_a")
assert "exitReason = heartbeat_stale" "heartbeat_stale" "$exit_reason"
echo

# -----------------------------------------------------------------------
# Test 6: max iterations
# -----------------------------------------------------------------------
echo "Test 6: max iterations enforced"
(cd "$PROJECT_A" && "$INIT" \
    --plan-path "$PROJECT_A/.claude/plans/plan-a" \
    --prompt "Continue" \
    --max-iterations 2 \
    --timeout-minutes 60 >/dev/null)

fire_hook "$PROJECT_A" >/dev/null  # iter -> 1
fire_hook "$PROJECT_A" >/dev/null  # iter -> 2
out=$(fire_hook "$PROJECT_A")       # iter == max, should allow exit
assert "max-iterations allows exit"  "" "$out"
exit_reason=$(jq -r '.exitReason' "$state_a")
assert "exitReason = max_iterations" "max_iterations" "$exit_reason"
echo

# -----------------------------------------------------------------------
# Test 7: completion-promise in transcript triggers exit
# -----------------------------------------------------------------------
echo "Test 7: completion-promise via transcript"
(cd "$PROJECT_A" && "$INIT" \
    --plan-path "$PROJECT_A/.claude/plans/plan-a" \
    --prompt "Continue" \
    --max-iterations 5 \
    --timeout-minutes 60 \
    --completion-promise "ALL_DONE_NOW" >/dev/null)

# Build a fake JSONL transcript with an assistant message containing the promise
transcript="${TEST_ROOT}/transcript.jsonl"
jq -n -c '{type:"user",  message:{content:[{type:"text",text:"go"}]}}' > "$transcript"
jq -n -c '{type:"assistant", message:{content:[{type:"text",text:"work done. ALL_DONE_NOW"}]}}' >> "$transcript"

out=$(fire_hook "$PROJECT_A" "$transcript")
assert "promise in transcript allows exit" "" "$out"
exit_reason=$(jq -r '.exitReason' "$state_a")
assert "exitReason = completion_promise" "completion_promise" "$exit_reason"
echo

# -----------------------------------------------------------------------
# Test 8: --all cancels everything
# -----------------------------------------------------------------------
echo "Test 8: cancel --all"
(cd "$PROJECT_A" && "$INIT" --plan-path "$PROJECT_A/p" --prompt "x" >/dev/null)
(cd "$PROJECT_B" && "$INIT" --plan-path "$PROJECT_B/p" --prompt "y" >/dev/null)

"$CANCEL" --all >/dev/null

state_b=$("$STATE_PATH" "$PROJECT_B")
a_active=$(jq -r '.active' "$state_a")
b_active=$(jq -r '.active' "$state_b")
assert "project A inactive after --all" "false" "$a_active"
assert "project B inactive after --all" "false" "$b_active"
echo

# -----------------------------------------------------------------------
# Test 9: legacy global file is archived by init.sh
# -----------------------------------------------------------------------
echo "Test 9: legacy global file migration"
echo '{"active":true,"planPath":"/some/old/plan"}' > "${HOME}/.claude/persist-execute-state.json"
(cd "$PROJECT_A" && "$INIT" --plan-path "$PROJECT_A/p" --prompt "x" >/dev/null 2>&1)
[[ ! -f "${HOME}/.claude/persist-execute-state.json" ]] && legacy_gone="yes" || legacy_gone="no"
assert "legacy global file archived" "yes" "$legacy_gone"
backups=$(ls -1 "${HOME}/.claude/" | grep -c "persist-execute-state.json.legacy.bak" || echo 0)
[[ "$backups" -ge 1 ]] && backup_made="yes" || backup_made="no"
assert "legacy backup file present" "yes" "$backup_made"
echo

# -----------------------------------------------------------------------
# Cleanup + summary
# -----------------------------------------------------------------------
echo "================================================="
echo "  PASSED: $PASS"
echo "  FAILED: $FAIL"
if (( FAIL > 0 )); then
    echo "  Failures:"
    for n in "${FAIL_NAMES[@]}"; do
        echo "    - $n"
    done
fi
echo "================================================="

rm -rf "$TEST_ROOT"

(( FAIL == 0 ))
