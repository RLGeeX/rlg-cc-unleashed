# Hugo Story - Reference Documentation

Detailed templates, scripts, and implementation details for the hugo-story skill.

## Table of Contents

1. [Task Templates](#task-templates)
2. [AskUserQuestion Templates](#askuserquestion-templates)
3. [Bash Scripts](#bash-scripts)
4. [Output Templates](#output-templates)
5. [Error Handling Patterns](#error-handling-patterns)

---

## Task Templates

### Ghost Writer - Initial Draft

```json
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

### Ghost Writer - Revision

```json
{
  "subagent_type": "ghost-writer",
  "description": "Revise Hugo blog story",
  "prompt": "Revise the blog article based on reviewer feedback:

FILE: hugo/content/news/[slug].md

FEEDBACK FROM COPY EDITOR:
[copy-editor feedback]

FEEDBACK FROM CONTENT REVIEWER:
[content-reviewer feedback]

Apply all CRITICAL and IMPORTANT fixes. Consider MINOR suggestions.

Return the complete revised article."
}
```

### Copy Editor Review

```json
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

### Content Reviewer Review

```json
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

### Final Approval Check

```json
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

---

## AskUserQuestion Templates

### Ticket Needs More Context

```json
{
  "questions": [{
    "question": "The Jira ticket needs more context. What additional details should be included?",
    "header": "Story Details",
    "multiSelect": false,
    "options": [
      {"label": "Target audience", "description": "Who should read this article?"},
      {"label": "Key points", "description": "What must be covered?"},
      {"label": "Tone", "description": "Technical, casual, or executive?"},
      {"label": "All of above", "description": "Provide comprehensive details"}
    ]
  }]
}
```

### No Consensus After Max Iterations

```json
{
  "questions": [{
    "question": "After 3 revision rounds, reviewers still have concerns. How would you like to proceed?",
    "header": "No Consensus",
    "multiSelect": false,
    "options": [
      {"label": "Publish as-is", "description": "Accept current version and deploy"},
      {"label": "Continue manually", "description": "Save draft for manual editing"},
      {"label": "Discard", "description": "Delete draft and cancel"}
    ]
  }]
}
```

### Git Push Failed

```json
{
  "questions": [{
    "question": "Git push failed. How would you like to proceed?",
    "header": "Push Error",
    "multiSelect": false,
    "options": [
      {"label": "Retry push", "description": "Try git push again"},
      {"label": "Pull and retry", "description": "Pull latest changes, then push"},
      {"label": "Save locally", "description": "Keep changes local for manual handling"}
    ]
  }]
}
```

### Cloud Build Failed

```json
{
  "questions": [{
    "question": "Cloud Build failed. How would you like to proceed?",
    "header": "Build Error",
    "multiSelect": false,
    "options": [
      {"label": "View logs", "description": "Show full build logs for debugging"},
      {"label": "Fix and retry", "description": "Attempt to fix the issue and rebuild"},
      {"label": "Revert commit", "description": "Undo the commit and investigate"}
    ]
  }]
}
```

---

## Bash Scripts

### Slug Generation

```bash
# Generate URL-friendly slug from title
# Example: "The Rise of AI" → "the-rise-of-ai"
slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
```

### Jira MCP Detection

```bash
# Look for any available Jira MCP tools in the current session
# Examples: mcp__jira-pcc__getJiraIssue, mcp__jira-rlg__getJiraIssue, etc.
# The prefix pattern is: mcp__jira-{instance}__getJiraIssue

# Use whichever Jira MCP server is connected - the tool name reveals the instance
# e.g., mcp__jira-rlg__getJiraIssue means use jira-rlg server
```

### Git Operations

```bash
# Add the story file
git add hugo/content/news/[slug].md

# Commit with conventional format
git commit -m "feat(blog): add [title]

Created from Jira ticket [JIRA-KEY]

[Generated by Hugo Story Automation]"

# Push to trigger Cloud Build
git push origin main
```

### Cloud Build - Find Latest Build

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

### Cloud Build - Monitor Progress

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

---

## Output Templates

### Completion Report

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

### Draft Saved (No Consensus)

```markdown
## Hugo Story Draft Saved

**Article**: [title]
**Draft Location**: hugo/content/drafts/[slug].md
**Jira**: [JIRA-KEY] (unchanged)

### Review Summary
- Iterations: 3 (max reached)
- Ghost Writer: [status]
- Copy Editor: [status]
- Content Reviewer: [status]

### Remaining Concerns
[List outstanding issues from reviewers]

### Next Steps
- Review draft manually
- Address remaining concerns
- Move to hugo/content/news/ when ready
- Run /cc-unleashed:hugo-story to retry automation
```

---

## Error Handling Patterns

| Error | Detection | Recovery |
|-------|-----------|----------|
| Jira MCP not available | No `mcp__jira*` tools found | Offer manual topic input |
| Ticket not found | Jira API returns 404 | Ask user to verify ticket key |
| Insufficient ticket detail | Description too short | Use AskUserQuestion for more context |
| Agent dispatch fails | Task tool returns error | Retry once, then alert user |
| Git push fails | Non-zero exit code | Show error, offer retry/pull/save options |
| Cloud Build fails | Status = FAILURE/TIMEOUT | Fetch logs, offer fix/retry/revert |
| Max iterations reached | iteration >= 3 | Save to drafts, ask user how to proceed |

### Jira MCP Not Available

```python
# Check for Jira tools
jira_tools = [t for t in available_tools if t.startswith("mcp__jira")]

if not jira_tools:
    # Offer manual mode
    ask_user({
        "question": "No Jira MCP server detected. Proceed with manual topic input?",
        "options": [
            {"label": "Enter topic manually", "description": "Provide article details directly"},
            {"label": "Cancel", "description": "Stop and configure Jira MCP first"}
        ]
    })
```

### Agent Dispatch Retry Logic

```python
max_retries = 1

for attempt in range(max_retries + 1):
    result = dispatch_agent(agent_type, prompt)

    if result.success:
        return result

    if attempt < max_retries:
        log_warning(f"Agent dispatch failed, retrying... ({attempt + 1}/{max_retries})")
    else:
        alert_user(f"Agent {agent_type} failed after {max_retries + 1} attempts")
        return ask_user_for_manual_mode()
```
