---
name: hugo-story
description: Autonomous Hugo blog story creation from Jira tickets. Orchestrates ghost-writer, copy-editor, and content-reviewer agents with iterative review until consensus. Commits, pushes, and monitors Cloud Build. Use when user wants to write a blog post from a Jira ticket.
---

# Hugo Story Automation

Autonomous workflow for creating Hugo blog stories from Jira tickets with multi-agent review and Cloud Build deployment.

## Prerequisites

1. **Jira MCP Server**: Connected (jira-pcc or jira-ti)
2. **Git**: Configured for rlg-hugo repository
3. **gcloud CLI**: Authenticated for Cloud Build monitoring

## Workflow Overview

```
Jira Ticket → Ghost Writer → Copy Editor + Content Reviewer
                    ↑                    ↓
                    ← ← ← (iterate until consensus) ← ← ←
                                         ↓
                              Git Commit/Push → Cloud Build → Done
```

## Process

### Phase 1: Jira Intake

**Step 1.1: Detect Jira MCP Server**

Check which Jira MCP server is available:

```bash
# The skill should dynamically detect available Jira MCP tools
# Look for either jira-pcc or jira-ti prefixes in available tools
```

**Step 1.2: Fetch Jira Ticket**

Use the detected MCP server to fetch the ticket:
- Call `getJiraIssue` with the provided ticket key
- Extract: summary, description, labels, acceptance criteria

**Step 1.3: Validate Ticket Content**

Ensure ticket has sufficient detail for story writing:
- Summary provides clear topic
- Description has enough context
- If unclear, use AskUserQuestion to gather more details

```
AskUserQuestion:
{
  "question": "The Jira ticket needs more context. What additional details should be included?",
  "header": "Story Details",
  "multiSelect": false,
  "options": [
    {"label": "Target audience", "description": "Who should read this article?"},
    {"label": "Key points", "description": "What must be covered?"},
    {"label": "Tone", "description": "Technical, casual, or executive?"},
    {"label": "All of above", "description": "Provide comprehensive details"}
  ]
}
```

### Phase 2: Story Creation

**Step 2.1: Generate Slug**

Create URL-friendly slug from title:
```bash
# Example: "The Rise of AI" → "the-rise-of-ai"
slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
```

**Step 2.2: Dispatch Ghost Writer**

Use Task tool to dispatch @ghost-writer:

```
Task:
{
  "subagent_type": "ghost-writer",
  "description": "Write Hugo blog story",
  "prompt": "Create a blog article for the rlg-hugo site based on this Jira ticket:

TICKET: [JIRA-KEY]
TITLE: [summary]
REQUIREMENTS: [description]
LABELS: [labels]

Use the Hugo story template with proper frontmatter.

Output location: hugo/content/news/[slug].md

TEMPLATE:
---
title: \"[title]\"
date: [today's date YYYY-MM-DD]
description: \"[150-160 char description]\"
featured_image: \"/images/news/placeholder.svg\"
excerpt: \"[80-100 char excerpt]\"
author: \"Chris Fogarty\"
categories: [\"[primary category]\"]
tags: [\"tag1\", \"tag2\", \"tag3\"]
---

[Content following standard structure: Introduction, 3-5 main sections, Conclusion]"
}
```

**Step 2.3: Write Draft File**

After ghost-writer returns, write the content to:
`/home/jfogarty/git/rlgeex/rlg-hugo/hugo/content/news/[slug].md`

### Phase 3: Review Loop

**Maximum 3 iterations** to prevent infinite loops.

**Step 3.1: Copy Editor Review**

Dispatch @copy-editor:

```
Task:
{
  "subagent_type": "copy-editor",
  "description": "Review story for grammar and style",
  "prompt": "Review this Hugo blog story for grammar, spelling, style, and readability.

FILE: hugo/content/news/[slug].md

Provide structured feedback:
1. CRITICAL issues (must fix)
2. IMPORTANT issues (should fix)
3. MINOR suggestions (nice to have)

End with VERDICT:
- APPROVED: Ready for publication
- CHANGES NEEDED: List specific issues"
}
```

**Step 3.2: Content Reviewer Review**

Dispatch @content-reviewer (can run in parallel with copy-editor):

```
Task:
{
  "subagent_type": "content-reviewer",
  "description": "Review story for structure and engagement",
  "prompt": "Review this Hugo blog story for structure, engagement, SEO, and Hugo compliance.

FILE: hugo/content/news/[slug].md

Check:
1. Structure and logical flow
2. Engagement (hook, examples, takeaways)
3. Hugo frontmatter validity
4. SEO elements (title, description, tags)

End with VERDICT:
- APPROVED: Ready for publication
- CHANGES NEEDED: List specific issues"
}
```

**Step 3.3: Process Feedback**

If EITHER reviewer has CHANGES NEEDED:
1. Combine all feedback
2. Dispatch @ghost-writer with revision request
3. Increment iteration counter
4. Return to Step 3.1

If BOTH reviewers return APPROVED:
- Proceed to Phase 4

**Step 3.4: Iteration Limit Reached**

If iteration >= 3 and no consensus:

1. Save current version to drafts:
   `hugo/content/drafts/[slug].md`

2. Present options to user:

```
AskUserQuestion:
{
  "question": "After 3 revision rounds, reviewers still have concerns. How would you like to proceed?",
  "header": "No Consensus",
  "multiSelect": false,
  "options": [
    {"label": "Publish as-is", "description": "Accept current version and deploy"},
    {"label": "Continue manually", "description": "Save draft for manual editing"},
    {"label": "Discard", "description": "Delete draft and cancel"}
  ]
}
```

### Phase 4: Internal Consensus Check

Before deployment, confirm all agents agree:

**Step 4.1: Final Approval Request**

Ask each agent one final time:

```
For each agent (ghost-writer, copy-editor, content-reviewer):
Task:
{
  "subagent_type": "[agent]",
  "description": "Final approval check",
  "prompt": "Final review of hugo/content/news/[slug].md

This is the FINAL check before publication.

Respond with EXACTLY one of:
- APPROVED: Ready to publish
- CHANGES NEEDED: [specific remaining issue]"
}
```

**Step 4.2: Consensus Evaluation**

- 3/3 APPROVED → Proceed to Phase 5
- Any CHANGES NEEDED → Return to Phase 3 (within limit)

### Phase 5: Deployment

**Step 5.1: Git Operations**

```bash
cd /home/jfogarty/git/rlgeex/rlg-hugo

# Add the story file
git add hugo/content/news/[slug].md

# Commit with conventional format
git commit -m "feat(blog): add [title]

Created from Jira ticket [JIRA-KEY]

[Generated by Hugo Story Automation]"

# Push to trigger Cloud Build
git push origin main
```

**Step 5.2: Confirm Push Success**

Verify the push succeeded before monitoring pipeline.

### Phase 6: Pipeline Monitoring

**Step 6.1: Find Build**

```bash
# Wait a moment for Cloud Build trigger
sleep 5

# Get the latest build for rlg-hugo
gcloud builds list \
  --project=rlg-gcp-sandbox \
  --filter="source.repoSource.repoName='rlg-hugo'" \
  --limit=1 \
  --format="value(id,status,createTime)"
```

**Step 6.2: Monitor Build Progress**

Poll every 30 seconds until complete:

```bash
BUILD_ID="[from previous step]"

while true; do
  STATUS=$(gcloud builds describe $BUILD_ID \
    --project=rlg-gcp-sandbox \
    --format="value(status)")

  case $STATUS in
    SUCCESS)
      echo "Build completed successfully!"
      break
      ;;
    FAILURE|TIMEOUT|CANCELLED)
      echo "Build failed with status: $STATUS"
      # Fetch logs for debugging
      gcloud builds log $BUILD_ID --project=rlg-gcp-sandbox
      break
      ;;
    *)
      echo "Build status: $STATUS - waiting..."
      sleep 30
      ;;
  esac
done
```

**Step 6.3: Update Jira Ticket**

On SUCCESS:
- Call Jira MCP to transition ticket to "Done" (if workflow supports)
- Add comment with deployed URL

On FAILURE:
- Alert user with build logs
- Keep ticket in current state

### Phase 7: Completion Report

Provide summary to user:

```markdown
## Hugo Story Published

**Article**: [title]
**File**: hugo/content/news/[slug].md
**Jira**: [JIRA-KEY] → Done
**Build**: [build-id] - SUCCESS
**URL**: https://rlg-hugo.pages.dev/news/[slug]/

### Review Summary
- Iterations: [count]
- Ghost Writer: APPROVED
- Copy Editor: APPROVED
- Content Reviewer: APPROVED

### Next Steps
- Verify article at production URL
- Share on social media
- Close Jira ticket if not auto-transitioned
```

## Error Handling

### Jira MCP Not Available
- Inform user no Jira MCP server detected
- Offer to proceed with manual topic input

### Git Push Fails
- Show error message
- Check for uncommitted changes or conflicts
- Offer to retry or save locally

### Cloud Build Fails
- Fetch and display build logs
- Common issues: Hugo version, theme missing, frontmatter error
- Offer to fix and retry

### Agent Dispatch Fails
- Retry once with same parameters
- If still fails, alert user and offer manual mode

## Files

- `SKILL.md` - This file (main orchestration)
- `templates/story-template.md` - Hugo story template
- `scripts/monitor-cloudbuild.sh` - Build monitoring utility
