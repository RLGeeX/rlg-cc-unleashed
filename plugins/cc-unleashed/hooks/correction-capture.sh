#!/usr/bin/env bash
#
# CC-Unleashed Correction Capture Hook - UserPromptSubmit
#
# Detects when the user is correcting Claude and injects a note prompting
# Claude to acknowledge the correction and offer to memorize it.
#
# Corrections are high-value memories — they represent cases where Claude
# was wrong about something project-specific. Storing them prevents the
# same mistake in future sessions.
#
# This hook only flags; the user runs /memorize to actually store.
#

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat 2>/dev/null || echo "{}")
prompt=$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null || echo "")

[[ -z "$prompt" ]] && exit 0

# Lowercase for pattern matching
prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

# Correction patterns — ordered most-specific to least
CORRECTION_PATTERNS=(
    "no, actually"
    "no, that's wrong"
    "no, that's incorrect"
    "that's not right"
    "that's not correct"
    "you're wrong"
    "you are wrong"
    "you're incorrect"
    "you are incorrect"
    "you made a mistake"
    "wait, that should be"
    "wait, that's"
    "not quite right"
    "not quite,"
    "let me correct"
    "to clarify,"
    "actually, it"
    "actually, the"
    "actually, we"
    "actually, i"
    "actually, that"
)

matched=false
for pattern in "${CORRECTION_PATTERNS[@]}"; do
    if [[ "$prompt_lower" == *"$pattern"* ]]; then
        matched=true
        break
    fi
done

[[ "$matched" == "false" ]] && exit 0

context="[CORRECTION DETECTED] The user appears to be correcting a previous response. This is a high-value learning moment.

After addressing the correction, briefly offer: \"Would you like me to memorize this correction so it's available in future sessions? Run /memorize at any time.\""

printf '{"additionalContext":%s}' "$(printf '%s' "$context" | jq -Rs .)"
