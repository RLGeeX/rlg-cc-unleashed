---
name: jira-plan
description: Creates Jira Epic → Stories → Sub-tasks hierarchy for an existing plan by delegating to @jira-specialist agent
---

# Jira Plan Integration

Creates a complete Jira issue hierarchy (Epic → Stories → Sub-tasks) for an existing implementation plan. Delegates all Jira operations to the @jira-specialist agent.

**Announce at start:** "I'm using the jira-plan skill to create Jira issues for your plan."

## Prerequisites

- Plan must already exist in `.claude/plans/[feature-name]/`
- Plan must have `plan-meta.json` with `phases` array
- Jira MCP server (jira-pcc) must be available
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
5. If validation fails:
   - Error: "Plan not found or invalid. Run write-plan skill first."
   - Exit
```

### Step 2: Pre-flight MCP Connection Check

Test Jira MCP connection before proceeding:

```
Try: Call jira-pcc MCP tool (e.g., getAccessibleAtlassianResources)

If connection fails:
  Use AskUserQuestion tool:

  Question: "Jira MCP server is unavailable. How would you like to proceed?"
  Options:
    - "Restart MCP Server" → Save to TodoList, tell user to run `/mcp restart jira-pcc`
    - "Retry Connection" → Wait 5 seconds, retry (max 3 attempts)
    - "Skip Jira Integration" → Exit gracefully
    - "Abort" → Exit without changes

  If "Restart MCP Server":
    - Add to TodoList: "Resume Jira integration for [feature-name]"
    - Tell user: "Please run `/mcp restart jira-pcc` then ask me to resume"
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
1. Call jira-pcc MCP: getAccessibleAtlassianResources
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

### Step 4: Delegate to @jira-specialist

Launch @jira-specialist subagent with all context:

```
Use Task tool with subagent_type: "jira-specialist"

Prompt:
  "Create Jira hierarchy for implementation plan.

  Plan Location: .claude/plans/[feature-name]/
  Project Key: [projectKey]
  Cloud ID: [cloudId]
  Label: [label] (optional)

  Instructions:
  1. Read plan-meta.json to understand:
     - Feature name and description
     - Total chunks
     - Phases array with chunk groupings

  2. Create Jira hierarchy:
     - Epic (feature-level):
       * Title: Feature name from plan-meta.json
       * Description: Feature description
       * Project: [projectKey]
       * Label: [label] if provided

     - Stories (one per phase):
       * Title: Phase name from plan-meta.json
       * Description: Brief overview of phase
       * Link to Epic
       * Label: [label] if provided

     - Sub-tasks (one per chunk):
       * Title: \"Chunk N: [chunk-name]\"
       * Description: Link to chunk file, tasks summary
       * Link to parent Story
       * Label: [label] if provided

  3. Update plan files:
     - Add jiraTracking section to plan-meta.json:
       {
         \"jiraTracking\": {
           \"enabled\": true,
           \"projectKey\": \"[projectKey]\",
           \"cloudId\": \"[cloudId]\",
           \"label\": \"[label]\",
           \"epicKey\": \"PROJ-100\",
           \"stories\": [
             {
               \"storyKey\": \"PROJ-110\",
               \"phase\": \"Setup & Dependencies\",
               \"chunks\": [
                 {\"chunk\": 1, \"subtaskKey\": \"PROJ-111\"},
                 {\"chunk\": 2, \"subtaskKey\": \"PROJ-112\"}
               ]
             }
           ]
         }
       }

     - Add jiraIssueKey to each chunk-*.md file:
       **Status:** pending
       **jiraIssueKey:** PROJ-111
       **Phase:** Setup & Dependencies

  4. Handle MCP errors gracefully:
     - If MCP disconnects during creation, offer same options as Step 2
     - Track which issues were created successfully
     - Allow resume from last successful point

  5. Return summary:
     - Epic key and URL
     - Story keys and URLs
     - Total sub-tasks created
     - Any errors encountered"
```

### Step 5: Verify and Report Results

After @jira-specialist completes:

```
1. Read updated plan-meta.json to verify jiraTracking section exists
2. Verify chunk files were updated with jiraIssueKey
3. Display summary to user:

   ✅ Jira Integration Complete

   Epic: PROJ-100 - [Feature Name]
   Link: https://your-domain.atlassian.net/browse/PROJ-100

   Stories Created:
   - PROJ-110: Setup & Dependencies (3 sub-tasks)
   - PROJ-120: Core Implementation (5 sub-tasks)
   - PROJ-130: Testing & Documentation (2 sub-tasks)

   Total Sub-tasks: 10

   Next Steps:
   - Execute plan: /cc-unleashed:plan-next
   - View in Jira: [epic-url]

4. If errors occurred:
   - Report which issues were created successfully
   - Report which failed and why
   - Offer to retry failed creations
```

## MCP Error Handling Strategy

All Jira MCP operations include error handling:

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

Check TodoList for existing state:
  - If found: "Resuming from [last successful point]..."
  - If not found: Start fresh

Continue from last successful issue creation
```

## Example Flow

```
User: /cc-unleashed:jira-plan oauth-login
Assistant: Running jira-plan skill for "oauth-login"...

1. Validating plan exists... ✓
2. Checking Jira MCP connection... ✓
3. Getting Jira configuration...

   [User selects project: "RLGEEX"]
   [User selects label: "oauth-feature"]

4. Delegating to @jira-specialist...

   Creating Epic... ✓ RLGEEX-100
   Creating 3 Stories... ✓
     - RLGEEX-110: Setup & Dependencies
     - RLGEEX-120: Core Implementation
     - RLGEEX-130: Testing & Documentation
   Creating 10 Sub-tasks... ✓

   Updating plan-meta.json... ✓
   Updating chunk files... ✓

5. ✅ Jira Integration Complete\!

   Epic: RLGEEX-100 - Add OAuth 2.0 Login
   Link: https://your-domain.atlassian.net/browse/RLGEEX-100

   Stories Created:
   - RLGEEX-110: Setup & Dependencies (3 sub-tasks)
   - RLGEEX-120: Core Implementation (5 sub-tasks)
   - RLGEEX-130: Testing & Documentation (2 sub-tasks)

   Total Sub-tasks: 10

   Next Steps:
   - Execute plan: /cc-unleashed:plan-next
   - View in Jira: https://your-domain.atlassian.net/browse/RLGEEX-100
```

## Notes

- Jira integration is completely optional
- Can be run at any time (before, during, or after plan execution)
- MCP errors are handled gracefully with user control
- All Jira operations delegated to @jira-specialist for consistency
- plan-meta.json is the source of truth for phase structure
