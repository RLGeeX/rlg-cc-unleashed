---
name: jira-plan
description: Creates Jira Epic → Stories → Sub-tasks hierarchy for an existing plan by delegating to @jira-specialist agent
---

# Jira Plan Integration

Creates a complete Jira issue hierarchy (Epic → Stories → Sub-tasks) for an existing implementation plan. Delegates all Jira operations to the @jira-specialist agent with explicit MCP tool patterns.

**Announce at start:** "I'm using the jira-plan skill to create Jira issues for your plan."

## Prerequisites

- Plan must already exist in `.claude/plans/[feature-name]/`
- Plan must have `plan-meta.json` with `phases` array
- Jira MCP server must be available (jira-pcc, jira-rlg, or jira-ti)
- User must have Jira project access

## Input

- **Feature name** - Directory name in `.claude/plans/`
- Example: If plan is in `.claude/plans/oauth-login/`, feature name is "oauth-login"

## Workflow

### Step 1: Validate Plan Exists

```
1. Read .claude/plans/[feature-name]/plan-meta.json
2. Verify file exists and is valid JSON
3. Verify phases array exists
4. Count total chunks
5. Extract from plan-meta.json:
   - feature (name)
   - description
   - phases[] with chunk mappings
   - executionConfig.chunkComplexity[] for story points
6. If validation fails:
   - Error: "Plan not found or invalid. Run write-plan skill first."
   - Exit
```

### Step 2: Pre-flight MCP Connection Check

Test Jira MCP connection before proceeding:

```
Try: Call Jira MCP tool (e.g., getAccessibleAtlassianResources)

Known MCP Error Patterns (trigger error handling flow):
- "accessibleResources.filter is not a function" → MCP server needs restart
- "Authentication failed" / 401 Unauthorized → MCP server needs restart or re-auth
- "Unauthorized" in error message → MCP server needs restart or re-auth
- "Failed to fetch tenant info" / Status: 404 → Invalid cloudId or MCP needs restart
- Connection timeout or no response → MCP server unavailable

If ANY of these errors occur (connection fails):
  Use AskUserQuestion tool:

  Question: "Jira MCP server is unavailable. How would you like to proceed?"
  Options:
    - "Restart MCP Server" → Save to TodoList, tell user to run `/mcp restart [server-name]`
    - "Retry Connection" → Wait 5 seconds, retry (max 3 attempts)
    - "Skip Jira Integration" → Exit gracefully
    - "Abort" → Exit without changes

  If "Restart MCP Server":
    - Add to TodoList: "Resume Jira integration for [feature-name]"
    - Tell user: "Please run `/mcp restart [server-name]` then ask me to resume"
    - Exit

  If "Retry Connection":
    - Loop: max 3 attempts with 5-second delays
    - If all retries fail → Ask again with same options

  If "Skip" or "Abort":
    - Exit gracefully
```

### Step 3: Get Jira Configuration

Get available projects and user preferences:

```
1. Call Jira MCP: getAccessibleAtlassianResources
2. Extract available projects and cloudId
3. Use AskUserQuestion tool:

   Question 1: "Which Jira project should I use?"
   Options: [List of available projects from MCP]

   Question 2: "Which label should I apply to all issues?" (optional)
   Header: "Label"
   Options:
     - "No label" (default)
     - "Other" (user can type custom label)

4. Store configuration:
   - projectKey (e.g., "RLGEEX")
   - cloudId (from MCP response)
   - label (optional, e.g., "oauth-feature")
```

### Step 4: Discover Story Points Field

**CRITICAL: Story points is a custom field that varies by project.**

```
1. Call getJiraProjectIssueTypesMetadata:
   - cloudId: [cloudId]
   - projectIdOrKey: [projectKey]

2. Find the "Story" issue type ID from response

3. Call getJiraIssueTypeMetaWithFields:
   - cloudId: [cloudId]
   - projectIdOrKey: [projectKey]
   - issueTypeId: [story issue type ID]

4. Search response for story points field:
   - Look for field with name containing "Story Points" or "Story point"
   - Common field IDs: customfield_10026, customfield_10016, customfield_10028
   - Store the field key (e.g., "customfield_10026")

5. If story points field not found:
   - Log warning: "Story points field not found, skipping SP assignment"
   - Continue without story points
```

### Step 5: Delegate to @jira-specialist

Launch @jira-specialist subagent with explicit MCP tool instructions:

```
Use Task tool with subagent_type: "jira-specialist"

Prompt:
  "Create Jira hierarchy for implementation plan using explicit MCP tool calls.

  ## Context

  Plan Location: .claude/plans/[feature-name]/
  Project Key: [projectKey]
  Cloud ID: [cloudId]
  Label: [label] (or 'none')
  Story Points Field: [storyPointsFieldId] (or 'not available')

  ## Plan Data (from plan-meta.json)

  Feature: [feature name]
  Description: [description]
  Total Chunks: [N]

  Phases:
  [List each phase with name, chunk numbers, and total story points]

  Chunk Complexity:
  [List each chunk with complexity and story points]

  ## CRITICAL: Use These Exact MCP Tool Patterns

  ### 1. Create Epic

  Use createJiraIssue:
  ```
  cloudId: [cloudId]
  projectKey: [projectKey]
  issueTypeName: 'Epic'
  summary: '[feature name]'
  description: '[feature description with phases overview]'
  ```

  Store returned issue key as epicKey.

  ### 2. Create Stories (one per phase)

  For EACH phase, use createJiraIssue:
  ```
  cloudId: [cloudId]
  projectKey: [projectKey]
  issueTypeName: 'Story'
  summary: '[phase name]'
  description: '[phase overview with chunk list]'
  additional_fields: {
    'customfield_10014': '[epicKey]',  // Epic Link field
    '[storyPointsFieldId]': [sum of chunk story points]  // Only if field available
  }
  ```

  Store returned issue key as storyKey for this phase.

  ### 3. Create Sub-tasks (one per chunk)

  For EACH chunk in EACH phase, use createJiraIssue:
  ```
  cloudId: [cloudId]
  projectKey: [projectKey]
  issueTypeName: 'Sub-task'
  summary: 'Chunk [N]: [chunk-name from filename]'
  description: 'Plan chunk: .claude/plans/[feature]/chunk-[NNN]-[name].md\n\nTasks: [brief task summary]'
  parent: '[storyKey for this phase]'
  additional_fields: {
    '[storyPointsFieldId]': [chunk story points]  // Only if field available
  }
  ```

  Store returned issue key as subtaskKey.

  ## Issue Creation Order

  1. Create Epic FIRST → get epicKey
  2. Create Stories in phase order → get storyKeys
  3. Create Sub-tasks per story → get subtaskKeys

  ## After All Issues Created

  1. Update plan-meta.json with jira section:
  ```json
  {
    \"jira\": {
      \"project\": \"[projectKey]\",
      \"epic\": {
        \"key\": \"[epicKey]\",
        \"summary\": \"[feature name]\"
      },
      \"stories\": [
        {
          \"key\": \"[storyKey]\",
          \"phase\": \"[phase name]\",
          \"chunks\": [[chunk numbers]],
          \"storyPoints\": [sum],
          \"subtasks\": [
            {\"chunk\": 1, \"key\": \"[subtaskKey]\"},
            {\"chunk\": 2, \"key\": \"[subtaskKey]\"}
          ]
        }
      ],
      \"createdAt\": \"[ISO timestamp]\"
    }
  }
  ```

  2. Update each chunk-*.md file header:
  ```
  **Status:** pending
  **Jira:** [subtaskKey]
  **Phase:** [phase name]
  ```

  ## Error Handling

  - If any createJiraIssue fails, log the error and continue with remaining issues
  - Track all successfully created issues
  - Report partial success if some issues failed

  ## Return Summary

  Return a structured summary:
  - Epic: [key] - [summary]
  - Stories created: [count]
  - Sub-tasks created: [count]
  - Any failures: [list]
  - Jira URL: https://[site].atlassian.net/browse/[epicKey]"
```

### Step 6: Verify Results in Jira

**CRITICAL: Verify actual Jira issues exist, not just plan file updates.**

```
1. Read updated plan-meta.json
2. Extract epic key from jira.epic.key
3. Call getJiraIssue for the epic:
   - cloudId: [cloudId]
   - issueIdOrKey: [epicKey]
4. Verify epic exists and has correct summary
5. Count subtasks field on stories to verify sub-tasks were created
6. If verification fails:
   - Report discrepancy to user
   - Offer to retry failed creations
```

### Step 7: Report Results

Display summary to user:

```
✅ Jira Integration Complete

Epic: [epicKey] - [Feature Name]
Link: https://[site].atlassian.net/browse/[epicKey]

Stories Created: [count]
| Story | Phase | Sub-tasks | Story Points |
|-------|-------|-----------|--------------|
| [key] | [phase] | [count] | [SP] |

Total Sub-tasks: [count]

Next Steps:
- Execute plan: /cc-unleashed:plan-next
- View in Jira: [epic URL]

If errors occurred:
- [List any failures]
- Use /cc-unleashed:jira-plan [feature] to retry
```

## MCP Tool Reference

### Required Tools

| Tool | Purpose |
|------|---------|
| getAccessibleAtlassianResources | Get cloudId and validate connection |
| getVisibleJiraProjects | List available projects |
| getJiraProjectIssueTypesMetadata | Get issue types for project |
| getJiraIssueTypeMetaWithFields | Discover custom fields (story points) |
| createJiraIssue | Create Epic, Story, Sub-task |
| getJiraIssue | Verify created issues |

### Issue Type Names

| Type | issueTypeName | Notes |
|------|---------------|-------|
| Epic | `Epic` | Top-level feature container |
| Story | `Story` | Phase-level work item |
| Sub-task | `Sub-task` | Chunk-level task, requires `parent` field |

### Linking Issues

| Relationship | How to Link |
|--------------|-------------|
| Story → Epic | Use `additional_fields: { 'customfield_10014': epicKey }` |
| Sub-task → Story | Use `parent: storyKey` parameter |

## MCP Error Handling Strategy

**Connection Errors:**
- Pre-flight check catches connection issues early
- User chooses how to handle (restart, retry, skip, abort)
- State saved to TodoList for resume capability

**Partial Failures:**
- Track successfully created issues
- Continue with remaining creations where possible
- Report partial success to user
- Offer retry for failed items

**Resume Pattern:**
```
User runs: /cc-unleashed:jira-plan oauth-login (after MCP restart)

Check plan-meta.json for existing jira section:
  - If partial: "Resuming from [last successful point]..."
  - If none: Start fresh

Continue from last successful issue creation
```

## Example Flow

```
User: /cc-unleashed:jira-plan oauth-login
Assistant: Running jira-plan skill for "oauth-login"...

1. Validating plan exists... ✓
   - Feature: oauth-login
   - Phases: 3
   - Chunks: 10

2. Checking Jira MCP connection... ✓

3. Getting Jira configuration...
   [User selects project: "RLGEEX"]
   [User selects label: "No label"]

4. Discovering story points field... ✓
   - Found: customfield_10026

5. Delegating to @jira-specialist...
   Creating Epic... ✓ RLGEEX-100
   Creating Story 1/3... ✓ RLGEEX-101
     Creating Sub-task 1/3... ✓ RLGEEX-102
     Creating Sub-task 2/3... ✓ RLGEEX-103
     Creating Sub-task 3/3... ✓ RLGEEX-104
   Creating Story 2/3... ✓ RLGEEX-105
     Creating Sub-task 1/5... ✓ RLGEEX-106
     [...]
   Creating Story 3/3... ✓ RLGEEX-115
     [...]

   Updating plan-meta.json... ✓
   Updating chunk files... ✓

6. Verifying in Jira... ✓
   - Epic exists: RLGEEX-100
   - Stories: 3
   - Sub-tasks: 10

7. ✅ Jira Integration Complete!

   Epic: RLGEEX-100 - Add OAuth 2.0 Login
   Link: https://rlgeex.atlassian.net/browse/RLGEEX-100

   | Story | Phase | Sub-tasks | SP |
   |-------|-------|-----------|-----|
   | RLGEEX-101 | Setup & Dependencies | 3 | 5 |
   | RLGEEX-105 | Core Implementation | 5 | 13 |
   | RLGEEX-115 | Testing & Docs | 2 | 3 |

   Total Sub-tasks: 10

   Next Steps:
   - Execute plan: /cc-unleashed:plan-next
   - View in Jira: https://rlgeex.atlassian.net/browse/RLGEEX-100
```

## Notes

- Jira integration is completely optional
- Can be run at any time (before, during, or after plan execution)
- MCP errors are handled gracefully with user control
- All Jira operations delegated to @jira-specialist with explicit MCP patterns
- plan-meta.json is the source of truth for phase structure
- Verification step confirms actual Jira issues exist
