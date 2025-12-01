---
description: Create Hugo blog story from Jira ticket with multi-agent review
argument-hint: JIRA-KEY
---

# Hugo Story Automation

You are now running the Hugo Story automation workflow.

## Your Task

Create a blog story for the rlg-hugo site from a Jira ticket using the `hugo-story` skill.

**Jira Ticket**: $ARGUMENTS

## Process

1. **Load the hugo-story skill** using the Skill tool
2. **Follow the skill's workflow**:
   - Fetch the Jira ticket
   - Dispatch @ghost-writer to create the story
   - Dispatch @copy-editor and @content-reviewer to review
   - Iterate until consensus (max 3 rounds)
   - Commit, push, and monitor Cloud Build

## Key Points

- The story goes in: `hugo/content/news/[slug].md`
- Use placeholder image: `/images/news/placeholder.svg`
- Author is always: "Chris Fogarty"
- Git repo is at: `/home/jfogarty/git/rlgeex/rlg-hugo`

## If No Jira Key Provided

If $ARGUMENTS is empty, ask the user:

```
AskUserQuestion:
{
  "question": "Which Jira ticket should I create a story from?",
  "header": "Jira Key",
  "multiSelect": false,
  "options": [
    {"label": "Enter ticket key", "description": "Provide the Jira issue key (e.g., PROJ-123)"},
    {"label": "Manual topic", "description": "Provide topic details without Jira"},
    {"label": "Cancel", "description": "Exit without creating story"}
  ]
}
```

Start the workflow now.
