---
name: persist-cancel
description: Cancel an active persist-execute session
---

# Cancel Persist-Execute

Immediately deactivates any active persist-execute session, allowing normal exit.

## Action

1. Check for state file at `~/.claude/persist-execute-state.json`
2. If exists and active:
   - Set `active` to `false`
   - Set `exitReason` to `"user_cancelled"`
   - Report: "Persist-execute session cancelled. Normal exit now allowed."
3. If not exists or not active:
   - Report: "No active persist-execute session found."

## Implementation

```bash
STATE_FILE="$HOME/.claude/persist-execute-state.json"

if [[ -f "$STATE_FILE" ]]; then
    active=$(jq -r '.active // false' "$STATE_FILE")
    if [[ "$active" == "true" ]]; then
        jq '.active = false | .exitReason = "user_cancelled"' "$STATE_FILE" > "${STATE_FILE}.tmp"
        mv "${STATE_FILE}.tmp" "$STATE_FILE"
        echo "Persist-execute session cancelled."
        echo "Iterations used: $(jq -r '.iteration' "$STATE_FILE")"
        echo "Normal exit now allowed."
    else
        echo "No active persist-execute session."
    fi
else
    echo "No persist-execute state file found."
fi
```

Run the above bash script to cancel.
