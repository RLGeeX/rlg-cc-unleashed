---
name: hugo-story
description: Autonomous Hugo blog story creation from Jira tickets. Orchestrates ghost-writer, copy-editor, and content-reviewer agents with iterative review until consensus. Commits, pushes, and monitors Cloud Build. Use when user wants to write a blog post from a Jira ticket.
---

# Hugo Story Automation

Autonomous workflow for creating Hugo blog stories from Jira tickets with multi-agent review and Cloud Build deployment.

## Prerequisites

- **Working Directory**: Hugo project root
- **Jira MCP Server**: Any connected (jira-pcc, jira-ti, jira-rlg, etc.)
- **Git**: Configured for Hugo repository
- **gcloud CLI**: Authenticated for Cloud Build monitoring

## Workflow Overview

```
Jira Ticket → Ghost Writer → Copy Editor + Content Reviewer
                    ↑                    ↓
                    ← ← ← (iterate until consensus) ← ← ←
                                         ↓
                              Git Commit/Push → Cloud Build → Done
```

---

## The Process

### Phase 1: Jira Intake

1. **Detect Jira MCP**: Find available `mcp__jira*` tools
2. **Fetch ticket**: Call `getJiraIssue` with ticket key
3. **Validate content**: Ensure sufficient detail for story writing
   - If unclear, use AskUserQuestion to gather more details
4. **Transition to "In Progress" (MANDATORY)**:
   ```
   mcp__jira-{instance}__transitionJiraIssue(issueKey, "In Progress")
   ```
   - If transition fails: Ask user (Restart MCP / Retry / Skip Jira / Abort)

### Phase 2: Story Creation

1. **Generate slug**: Create URL-friendly slug from title
2. **Dispatch @ghost-writer**: Create initial draft with Hugo frontmatter
3. **Write draft file**: Save to `hugo/content/news/[slug].md`

See `reference.md` for ghost-writer prompt template.

### Phase 3: Review Loop

**Maximum 3 iterations** to prevent infinite loops.

1. **Dispatch @copy-editor**: Review grammar, spelling, style, readability
2. **Dispatch @content-reviewer**: Review structure, engagement, SEO, Hugo compliance
   - Can run in parallel with copy-editor

3. **Process feedback**:
   - If EITHER has CHANGES NEEDED → dispatch @ghost-writer for revision → repeat
   - If BOTH return APPROVED → proceed to Phase 4

4. **If max iterations reached** without consensus:
   - Save to `hugo/content/drafts/[slug].md`
   - Ask user: Publish as-is / Continue manually / Discard

See `reference.md` for reviewer prompt templates.

### Phase 4: Internal Consensus Check

Before deployment, get final approval from all agents:

1. **Final approval request**: Ask each agent one last time (APPROVED or CHANGES NEEDED)
2. **Consensus evaluation**:
   - 3/3 APPROVED → proceed to Phase 5
   - Any CHANGES NEEDED → return to Phase 3 (within limit)

### Phase 5: Deployment

1. **Git operations**:
   - `git add hugo/content/news/[slug].md`
   - `git commit` with conventional format
   - `git push origin main`

2. **Verify push success** before monitoring pipeline

### Phase 6: Pipeline Monitoring

1. **Find build**: Query Cloud Build for latest rlg-hugo build
2. **Monitor progress**: Poll every 30 seconds until complete
3. **On build result**:
   - **SUCCESS**: Proceed to Phase 7
   - **FAILURE**: Alert user with build logs, offer fix/retry/revert options

See `reference.md` for gcloud commands.

### Phase 7: Jira Completion (MANDATORY on SUCCESS)

1. **Transition to "Done"**:
   ```
   mcp__jira-{instance}__transitionJiraIssue(issueKey, "Done")
   ```
2. **Add comment** with published URL:
   ```
   mcp__jira-{instance}__editJiraIssue(issueKey, comment: "Published: [URL]")
   ```
3. If transition fails: Ask user (Restart MCP / Retry / Skip Jira / Continue anyway)

### Phase 8: Completion Report

Provide summary: article details, Jira status, build result, review summary, next steps.

---

## Jira Integration (MANDATORY)

Jira transitions are **woven into the main workflow**:

| Phase | Jira Action | Timing |
|-------|-------------|--------|
| Phase 1 | **Transition to "In Progress"** | After fetching ticket, BEFORE story creation |
| Phase 7 | **Transition to "Done"** | After build SUCCESS |
| Phase 7 | **Add comment with URL** | After transition to Done |

**Error handling:** Jira errors should NOT block the workflow unless user chooses to abort. Ask user: Restart MCP / Retry / Skip Jira / Abort.

---

## Error Handling

| Error | Action |
|-------|--------|
| Jira MCP not available | Offer manual topic input |
| Ticket not found | Ask user to verify ticket key |
| Git push fails | Show error, offer retry/pull/save options |
| Cloud Build fails | Fetch logs, offer fix/retry/revert |
| Agent dispatch fails | Retry once, then alert user |
| Max iterations (3) | Save to drafts, ask user how to proceed |

See `reference.md` for detailed error handling patterns and AskUserQuestion templates.

---

## Red Flags

**NEVER:**
- Skip the review loop
- Push without consensus (unless user explicitly approves)
- Exceed 3 iterations without user input
- Skip Jira transition to "In Progress" before starting work
- Skip Jira transition to "Done" after successful deployment
- Leave Jira ticket in wrong state after completion

**ALWAYS:**
- Transition Jira to "In Progress" in Phase 1 (BEFORE story creation)
- Run both copy-editor AND content-reviewer
- Get explicit approval before publishing
- Transition Jira to "Done" in Phase 7 (AFTER build success)
- Add Jira comment with published URL
- Provide completion report with all details

---

## References

See `reference.md` for:
- Task tool prompt templates (ghost-writer, copy-editor, content-reviewer)
- AskUserQuestion JSON templates
- Bash scripts (slug generation, git operations, Cloud Build monitoring)
- Output templates (completion report, draft saved)
- Error handling patterns
