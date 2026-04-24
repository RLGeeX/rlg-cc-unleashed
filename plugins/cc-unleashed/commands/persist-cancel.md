---
name: persist-cancel
description: Cancel an active persist-execute session
---

# Cancel Persist-Execute

Deactivates the persist-execute state for the current project so the next exit attempt is no longer blocked.

## How It Works

State is keyed by current working directory: `~/.claude/persist-execute-state/<sha256(cwd)[:16]>.json`. Cancelling only touches the file matching this project — other projects' active sessions are not affected.

## Usage

Invoke the helper script. By default it cancels the state for the current cwd:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/persist-execute/scripts/cancel.sh"
```

To cancel every active persist-execute across all projects:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/persist-execute/scripts/cancel.sh" --all
```

To cancel a specific project's state without `cd`'ing to it:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/persist-execute/scripts/cancel.sh" --cwd /path/to/project
```

## Output

- "Cancelled persist-execute for: …" — state was active and is now deactivated.
- "No persist-execute state for: …" — there was nothing to cancel here.
- "Persist-execute already inactive for: …" — state file exists but already deactivated (e.g., max-iterations or timeout already fired).

## Related

- `${CLAUDE_PLUGIN_ROOT}/skills/persist-execute/scripts/status.sh` — list active sessions across all projects.
- See `skills/persist-execute/SKILL.md` for the full lifecycle.
