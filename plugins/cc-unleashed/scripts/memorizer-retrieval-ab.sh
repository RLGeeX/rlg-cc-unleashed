#!/usr/bin/env bash
#
# CC-Unleashed Memory Retrieval Hook — A/B Harness
#
# Runs a fixed set of realistic prompts against two versions of the retrieval
# hook and reports injection-payload size deltas. Used to validate that hook
# tuning keeps the injection inside an agreed token budget.
#
# Default OLD baseline simulates the pre-4.7 hook:
#   limit=3, minSimilarity=0.72, first-3-lines + 300-char body cap
# Default NEW is the current on-disk hook.
#
# Both run with minSimilarity lowered to 0.4 and project scope disabled so
# the comparison uses the same global candidate pool — the point is format
# and filtering deltas, not server-side scoring.
#
# Usage:
#   ./memorizer-retrieval-ab.sh                 # compare OLD shim vs current hook
#   ./memorizer-retrieval-ab.sh <hook-path>     # compare OLD shim vs specified hook
#   ./memorizer-retrieval-ab.sh --baseline      # baseline only (no NEW run)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_HOOK="$SCRIPT_DIR/../hooks/memory-retrieval.sh"
MEMORIZER_URL="https://memorizer.rlgeex.com/mcp"
MIN_SIM_AB="0.4"

# Fixed prompt corpus — vary topics so we average across easy + hard queries
PROMPTS=(
    "memory retrieval hook"
    "marketplace plugin structure"
    "bash compatibility council"
    "session auto capture stop hook"
    "pre-commit hook configuration"
    "how to write a skill for memorizer"
    "claude code plugin development workflow"
)

# ── OLD baseline shim ──────────────────────────────────────────────────────
#
# Reproduces pre-4.7 hook behavior independently of disk state.

run_old_baseline() {
    local prompt="$1"
    local sim="${2:-$MIN_SIM_AB}"

    local search_args request resp content mcount
    search_args=$(jq -n --arg q "$prompt" --argjson sim "$sim" \
        '{query:$q,limit:3,minSimilarity:$sim}')
    request=$(jq -n --argjson args "$search_args" \
        '{jsonrpc:"2.0",method:"tools/call",id:1,params:{name:"search_memories",arguments:$args}}')
    resp=$(curl -s --max-time 5 -X POST "$MEMORIZER_URL" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -d "$request" | grep '^data:' | head -1 | sed 's/^data: //')
    content=$(echo "$resp" | jq -r '.result.content[0].text // empty')
    [[ -z "$content" ]] && return 0
    echo "$content" | grep -q '^No memories found' && return 0
    mcount=$(echo "$content" | grep -c '^ID:' || true)
    [[ "$mcount" -eq 0 ]] && return 0

    local formatted
    formatted=$(echo "$content" | awk '
        /^ID:/       { if (entry) emit(); entry=1; title=""; type=""; conf=""; text=""; tcap=0; next }
        /^Title:/    { sub(/^Title: /,""); title=$0; next }
        /^Type:/     { sub(/^Type: /,""); type=$0; next }
        /^Confidence:/ { sub(/^Confidence: Confidence: /,""); conf=$0; next }
        /^Text:/     { sub(/^Text: /,""); text=$0; tcap=1; next }
        /^Source:|^Tags:|^Similarity:|^Created:|^URL:|^Owner:|^Archetype:/ { tcap=0; next }
        tcap==1      { text=text "\n" $0; next }
        END          { if (entry) emit() }
        function emit(   first3, snip) {
            n=split(text,lines,"\n")
            first3=lines[1]
            if (n>=2) first3=first3 "\n" lines[2]
            if (n>=3) first3=first3 "\n" lines[3]
            snip=substr(first3,1,300)
            printf("[%s] **%s** (%s | confidence: %s)\n%s\n", NR, title, type, conf, snip)
        }
    ')

    printf '[MEMORIZER: %d relevant memories for global]\n\n%s\n\n---' "$mcount" "$formatted"
}

# ── NEW hook runner ────────────────────────────────────────────────────────
#
# Wraps the on-disk hook with the same AB-friendly overrides (relax floor,
# drop project scoping) so results are comparable to the baseline.

run_new_hook() {
    local hook_path="$1"
    local prompt="$2"

    local tmp
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' RETURN

    sed -E "s/^MIN_SIMILARITY=[0-9.]+/MIN_SIMILARITY=${MIN_SIM_AB}/" "$hook_path" > "$tmp"
    # Drop project scope for apples-to-apples candidate pool
    # Using python for portable multiline replace since BSD sed differs from GNU
    python3 - "$tmp" <<'PY'
import re, sys
p = sys.argv[1]
with open(p) as f: text = f.read()
text = re.sub(
    r'if \[\[ -n "\$project_id" && "\$project_id" != "null" \]\]; then',
    'if false; then',
    text,
)
with open(p, 'w') as f: f.write(text)
PY

    chmod +x "$tmp"
    local input ctx
    input=$(jq -n --arg p "$prompt" --arg c "/Users/jfogarty/prj/rlgeex/rlg-cc" \
        '{prompt:$p,cwd:$c}')
    ctx=$(echo "$input" | bash "$tmp" 2>/dev/null | jq -r '.additionalContext // ""' 2>/dev/null || echo "")
    printf '%s' "$ctx"
}

# ── Main ───────────────────────────────────────────────────────────────────

HOOK_PATH="${1:-$DEFAULT_HOOK}"
BASELINE_ONLY=0
if [[ "$HOOK_PATH" == "--baseline" ]]; then
    BASELINE_ONLY=1
fi

echo "== Memorizer Retrieval A/B =="
echo "Endpoint:    $MEMORIZER_URL"
echo "minSim (AB): $MIN_SIM_AB (project-scope disabled for fair pool)"
if [[ $BASELINE_ONLY -eq 0 ]]; then
    echo "NEW hook:    $HOOK_PATH"
fi
echo "Prompts:     ${#PROMPTS[@]}"
echo

total_old=0
total_new=0
over_old=0
over_new=0
printf "%-44s %8s %8s %7s\n" "prompt" "OLD(B)" "NEW(B)" "Δ"
printf "%-44s %8s %8s %7s\n" "------" "------" "------" "------"

for q in "${PROMPTS[@]}"; do
    old_out=$(run_old_baseline "$q" "$MIN_SIM_AB")
    old_size=${#old_out}
    total_old=$((total_old + old_size))
    [[ $old_size -gt 0 ]] && over_old=$((over_old + 1))

    if [[ $BASELINE_ONLY -eq 1 ]]; then
        printf "%-44s %8d %8s %7s\n" "${q:0:44}" "$old_size" "-" "-"
        continue
    fi

    new_ctx=$(run_new_hook "$HOOK_PATH" "$q")
    new_size=${#new_ctx}
    total_new=$((total_new + new_size))
    [[ $new_size -gt 0 ]] && over_new=$((over_new + 1))

    if [[ $old_size -gt 0 ]]; then
        delta_pct=$(awk -v o="$old_size" -v n="$new_size" 'BEGIN{printf "%+.0f%%", (n/o - 1)*100}')
    else
        delta_pct="-"
    fi
    printf "%-44s %8d %8d %7s\n" "${q:0:44}" "$old_size" "$new_size" "$delta_pct"
done

echo
echo "== Summary =="
n=${#PROMPTS[@]}
avg_old=$((total_old / n))
echo "OLD avg: ${avg_old} B (~$((avg_old / 4)) tok) over ${over_old}/${n} prompts with hits"
if [[ $BASELINE_ONLY -eq 0 ]]; then
    avg_new=$((total_new / n))
    echo "NEW avg: ${avg_new} B (~$((avg_new / 4)) tok) over ${over_new}/${n} prompts with hits"
    if [[ $avg_old -gt 0 ]]; then
        awk -v o="$avg_old" -v n="$avg_new" \
            'BEGIN{printf "Δ avg: %+.1f%% (target window 900-1500 B)\n", (n/o - 1)*100}'
    fi
fi
