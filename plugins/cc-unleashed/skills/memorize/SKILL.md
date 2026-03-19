---
name: memorize
description: User-invoked skill that extracts high-value knowledge from the current session and stores it in Memorizer (PostgreSQL + pgvector). Classifies memories by type, assigns salience scores, deduplicates, and stores via Memorizer MCP tools. Run before ending a session or after making important decisions.
---

# /memorize — Session Memory Extraction

## Overview

Extract and store the most valuable knowledge from this session into the Memorizer memory database. This is the primary way session knowledge persists beyond the current context window.

**Announce at start:** "I'm using the /memorize skill to extract session knowledge."

**Prerequisite:** Memorizer MCP server must be registered. Run `scripts/setup-memory.sh` if tools aren't available.

---

## Step 1: Determine Project Scope

Before extracting, identify which Memorizer project to store memories in.

1. Check the current working directory (cwd)
2. Derive org/project: strip `~/prj/` prefix, take first two path segments
   - e.g., `~/prj/rlgeex/rlg-cc/...` → workspace: `rlgeex`, project: `rlg-cc`
3. Call `get_project_context` with `query: "[project-name]"` to find the project UUID
4. If found, use `projectId` when storing. If not found, store without scoping (Unfiled).

---

## Step 2: Review Conversation

Scan the full conversation for content worth storing. Focus on:

| What to look for | Why it matters |
|-----------------|----------------|
| Architectural decisions made | Prevents re-litigating same decisions |
| Bugs found and root causes | Avoids same bugs next session |
| User preferences stated | Builds accurate mental model of user style |
| Technical patterns discovered | Reusable solutions across sessions |
| Constraints or gotchas | "Don't do X because Y" knowledge |
| Corrections the user made | High-signal: Claude was wrong, now knows better |
| Configuration or environment facts | Avoids repeated discovery |
| Tasks deferred to later | Continuity across sessions |

---

## Step 3: Classify and Score

For each candidate memory, assign:

**Cell type** (use as tag):
- `fact` — Technical fact or configuration detail
- `decision` — Architecture or design decision made
- `preference` — User or team preference/style
- `pattern` — Reusable solution pattern
- `risk` — Risk, gotcha, or "don't do X" constraint
- `task` — Deferred work item

**Salience score** (use as `confidence` in Memorizer):

| Score | Meaning | Example |
|-------|---------|---------|
| 1.0 | Critical constraint or fundamental decision | "Never include co-authored-by in commits" |
| 0.9 | Important, frequently-applicable pattern | "Always use Vault → ESO for secrets in k8s" |
| 0.8 | Significant fact or decision | "Memorizer v2.0.0 endpoint is at /mcp not /" |
| 0.7 | Useful fact with moderate reuse potential | "CNPG cluster has 2-replica async replication" |
| 0.5 | Standard fact, limited future reuse | "Used helm install for this deployment" |
| 0.3 | Minor detail | "Checked status on 2026-02-19" |
| 0.1 | Ephemeral, session-specific only | "Ran ls to verify directory" |

**Filter:** Only store items with salience ≥ 0.5. Low-salience items don't justify database writes.

---

## Step 4: Deduplicate

Before storing each memory, check for existing similar memories:

```
search_memories(
  query: "[memory title or key phrase]",
  limit: 3,
  minSimilarity: 0.85,   ← higher threshold for dedup check
  projectId: "[project-id]"  ← if scoped
)
```

If a similar memory exists:
- **Very similar (≥ 0.92):** Skip storing, or use `edit` to update existing
- **Somewhat similar (0.85–0.92):** Use judgment — store as new if meaningfully different, otherwise skip
- **Below threshold:** Store as new

---

## Step 5: Store Memories

For each memory to store, call `store`:

```
store(
  type: "reference",          ← use "reference" for facts/patterns/decisions
  title: "[Concise, searchable title]",
  text: "[Full memory content — include context, not just the fact]",
  source: "LLM",
  tags: ["[cell-type]", "[project-name]", "session-extract"],
  confidence: [salience-score],
  projectId: "[project-id]"   ← if determined in Step 1
)
```

**Title guidelines:**
- Searchable and specific: "Memorizer v2.0.0 MCP endpoint is /mcp not /"
- Not vague: ~~"Important endpoint fact"~~

**Text guidelines:**
- Include enough context to be useful without the conversation
- For decisions: include the why, not just the what
- For patterns: include when to apply it

**For correction memories**, use extra metadata:
```
tags: ["correction", "preference", "session-extract"]
confidence: 0.9  ← corrections are high-salience by default
```

---

## Step 6: Report

After storing, report a summary:

```
Memorized X items for [workspace/project]:

✓ [title] (decision, 0.9)
✓ [title] (pattern, 0.8)
✓ [title] (correction, 0.9)
⏭ [title] — skipped (duplicate found)
⏭ [title] — skipped (salience < 0.5)

Run /memory-management to view, edit, or search stored memories.
```

---

## Key Rules

| Rule | Detail |
|------|--------|
| Salience gate | Only store ≥ 0.5 |
| Dedup check | Always search before storing |
| Source field | Always `"LLM"` for extracted memories |
| Title quality | Specific + searchable |
| Text quality | Self-contained context |
| Corrections | Always tag with `"correction"`, salience ≥ 0.9 |
| Never over-store | 3–8 memories per session is typical; 15+ means you're storing noise |
