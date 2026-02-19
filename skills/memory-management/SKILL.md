---
name: memory-management
description: Natural language interface for managing Memorizer memories — search, list, view, edit, delete, archive, and relate memories across workspaces and projects. Use when you want to explore, curate, or organize what's been stored in Memorizer.
---

# /memory-management — Memory Operations

## Overview

Manage memories stored in Memorizer (PostgreSQL + pgvector) using natural language. Wraps the Memorizer MCP tools with a guided workflow.

**Announce at start:** "I'm using the /memory-management skill."

**Prerequisite:** Memorizer MCP server must be registered (`scripts/setup-memory.sh`).

---

## Common Operations

### Search memories
> "show me memories about ArgoCD"
> "find memories tagged decision"
> "what do I know about CNPG?"

```
search_memories(query: "[topic]", limit: 10, minSimilarity: 0.65)
```
With project scoping: add `projectId` for the current project.

---

### List project memories
> "list all memories for rlg-k8s-lab"
> "what's been memorized for this project?"

```
get_project_context(query: "[project-name]", includeMemories: true)
```
Then display the memory list with titles and types.

---

### View a memory
> "show me that memory about Vault secrets"
> "read memory [id]"

```
get(id: "[uuid]", includeVersionHistory: true, includeSimilar: true)
```
Display full content plus version history and similar memories.

---

### Edit a memory
> "update the memory about Memorizer endpoint — it's /mcp not /"
> "fix the title of memory [id]"

For content changes:
```
get(id: "[uuid]")   ← read first, always
edit(id: "[uuid]", old_text: "...", new_text: "...")
```

For metadata only (title, tags, confidence):
```
update_metadata(id: "[uuid]", title: "...", tags: [...], confidence: 0.9)
```

---

### Delete a memory
> "delete the memory about X"
> "remove that outdated memory"

```
search_memories(query: "[description]")  ← find it first
delete(id: "[uuid]")
```
**Confirm with user before deleting** — permanent, no undo.

---

### Archive a memory
> "archive old memories about the old cluster setup"
> "mark that memory as obsolete"

```
archive_memory(id: "[uuid]")
```
Archived memories are hidden from searches but preserved for history. Safer than delete.

---

### Relate two memories
> "link the ArgoCD decision to the GitOps pattern memory"
> "relate memory X to memory Y as 'example-of'"

```
create_reference(fromId: "[uuid]", toId: "[uuid]", type: "explains|example-of|related-to")
```

---

### Move memories to a project
> "move these memories to the rlg-k8s-lab project"

```
get_project_context(query: "[project-name]")  ← get project UUID
move_memory(memoryIds: ["[uuid]", ...], projectId: "[project-uuid]")
```

---

### Restore an archived memory
> "restore the archived memory about X"

```
list_archived(projectId: "[project-uuid]")  ← find it
restore_memory(id: "[uuid]")
```

---

## Workflow: Memory Audit

When asked to "clean up memories" or "audit project memories":

1. `get_project_context("[project]", includeMemories: true)` — get full list
2. For each memory with low confidence (< 0.5): offer to archive
3. `search_memories` to find near-duplicates (similarity ≥ 0.9) — offer to merge
4. Report: kept / archived / merged counts

---

## Key Rules

| Rule | Detail |
|------|--------|
| Read before edit | Always call `get` before `edit` |
| Confirm before delete | Permanent — ask user first |
| Archive over delete | Prefer archive for potentially useful but outdated content |
| Project scope | Always try to scope searches to current project |
| Show IDs | When listing memories, show truncated UUIDs for user reference |
