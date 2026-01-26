---
name: sk-jira
description: Creates Jira Epic → Stories → Sub-tasks hierarchy from spec-kit artifacts (spec.md, tasks.md)
---

# Spec-Kit Jira Integration

Creates a complete Jira issue hierarchy (Epic → Stories → Sub-tasks) from spec-kit artifacts. Reads `spec.md` for user stories and `tasks.md` for atomic work items, then creates corresponding Jira issues with persistent state tracking.

**Announce at start:** "I'm using the sk-jira skill to create Jira issues from your spec-kit feature."

## Prerequisites

- Spec-kit feature must exist in `specs/###-feature-name/`
- Must contain `spec.md` with user stories (US1, US2, etc.)
- Must contain `tasks.md` with task IDs and story assignments
- Jira MCP server must be available (jira-pcc, jira-rlg, jira-ti, etc.)

## Input

```
specs/###-feature-name/
├── spec.md      # User stories with acceptance criteria
└── tasks.md     # Tasks with [T001] [P] [US1] format
```

**Argument:** Feature path (e.g., `specs/001-user-auth/` or just `001-user-auth`)

---

## Workflow

### Step 1: Validate Spec-Kit Artifacts

```
1. Locate feature directory in specs/
2. Read spec.md:
   - Extract feature name from # heading
   - Extract summary/description
   - Parse user stories (## US1: ..., ## US2: ...)
   - Extract acceptance criteria per story
3. Read tasks.md:
   - Parse tasks with format: [T001] [P] [US1] Description
   - T001 = task ID
   - [P] = parallel flag (optional)
   - [US1] = parent user story
   - Extract dependencies (Depends: T001, T002)
4. If validation fails:
   - Error: "Invalid spec-kit structure. Expected spec.md and tasks.md"
   - Exit
```

### Step 2: Detect Jira MCP Server

```
1. Run: mcp-cli servers
2. Filter for servers starting with "jira-"
3. If multiple jira servers found:
   - Use AskUserQuestion:
     Question: "Multiple Jira servers available. Which one?"
     Options: [list of jira-* servers]
4. If single server: Use it
5. If no servers: Error and exit
6. Store selected server name (e.g., "jira-pcc")
```

### Step 3: Pre-flight MCP Connection Check

```
1. Run: mcp-cli info <jira-server>/getAccessibleAtlassianResources
2. Then: mcp-cli call <jira-server>/getAccessibleAtlassianResources '{}'

Known Error Patterns (trigger error handling):
- "accessibleResources.filter is not a function" → MCP needs restart
- "Authentication failed" / 401 → MCP needs restart or re-auth
- Connection timeout → MCP unavailable

If error:
  Use AskUserQuestion:
    Question: "Jira MCP server unavailable. How to proceed?"
    Options:
      - "Restart MCP Server" → Tell user to run /mcp restart
      - "Retry Connection" → Max 3 attempts with 5s delay
      - "Abort" → Exit
```

### Step 4: Get Jira Configuration

```
1. Call: mcp-cli call <jira-server>/getAccessibleAtlassianResources '{}'
2. Extract cloudId from response
3. Call: mcp-cli call <jira-server>/getVisibleJiraProjects '{"cloudId": "<cloudId>"}'
4. Use AskUserQuestion:
   Question: "Which Jira project?"
   Options: [List of projects with keys]

5. Store:
   - jiraServer (e.g., "jira-pcc")
   - cloudId
   - projectKey (e.g., "PCC")
```

### Step 5: Discover Custom Fields

```
1. Get issue types:
   mcp-cli call <jira-server>/getJiraProjectIssueTypesMetadata '{
     "cloudId": "<cloudId>",
     "projectIdOrKey": "<projectKey>"
   }'

2. Find Story issue type ID

3. Get fields for Story:
   mcp-cli call <jira-server>/getJiraIssueTypeMetaWithFields '{
     "cloudId": "<cloudId>",
     "projectIdOrKey": "<projectKey>",
     "issueTypeId": "<storyIssueTypeId>"
   }'

4. Search for:
   - Story Points field (customfield_100XX)
   - Epic Link field (customfield_10014 typically)

5. Store field IDs for later use
```

### Step 6: Create Jira Hierarchy

**Order is critical: Epic → Stories → Sub-tasks**

#### 6a. Create Epic

```
mcp-cli call <jira-server>/createJiraIssue '{
  "cloudId": "<cloudId>",
  "projectKey": "<projectKey>",
  "issueTypeName": "Epic",
  "summary": "<feature name from spec.md>",
  "description": "<feature summary + user story overview>"
}'

Store: epicKey (e.g., "PCC-100")
```

#### 6b. Create Stories (one per User Story)

For each US in spec.md:

```
mcp-cli call <jira-server>/createJiraIssue '{
  "cloudId": "<cloudId>",
  "projectKey": "<projectKey>",
  "issueTypeName": "Story",
  "summary": "<US title from spec.md>",
  "description": "<US description + acceptance criteria>",
  "additional_fields": {
    "<epicLinkField>": "<epicKey>",
    "<storyPointsField>": <calculated from task count>
  }
}'

Store: storyKey mapped to US ID (e.g., {"US1": "PCC-101"})
```

#### 6c. Create Sub-tasks (one per Task)

For each task in tasks.md:

```
mcp-cli call <jira-server>/createJiraIssue '{
  "cloudId": "<cloudId>",
  "projectKey": "<projectKey>",
  "issueTypeName": "Sub-task",
  "summary": "[<taskId>] <task description>",
  "description": "Task from spec-kit\n\nParent Story: <US ID>\nDependencies: <list>",
  "parent": "<storyKey for parent US>"
}'

Store: taskKey mapped to task ID (e.g., {"T001": "PCC-102"})
```

#### 6d. Create Dependency Links

For tasks with dependencies:

```
mcp-cli call <jira-server>/editJiraIssue '{
  "cloudId": "<cloudId>",
  "issueIdOrKey": "<dependentTaskKey>",
  "comment": "Blocked by: <blockerTaskKey>"
}'

Note: If project has issue linking enabled, use proper link type instead
```

### Step 7: Initialize sk-state.json

Create `specs/###-feature-name/sk-state.json`:

```json
{
  "feature": "###-feature-name",
  "createdAt": "<ISO timestamp>",
  "status": "ready",
  "jiraServer": "<jira-server>",
  "jira": {
    "cloudId": "<cloudId>",
    "project": "<projectKey>",
    "epic": "<epicKey>",
    "stories": {
      "US1": "<storyKey>",
      "US2": "<storyKey>"
    },
    "tasks": {
      "T001": { "key": "<taskKey>", "story": "US1", "status": "todo" },
      "T002": { "key": "<taskKey>", "story": "US1", "status": "todo" }
    }
  },
  "dependencies": {
    "T002": ["T001"],
    "T003": ["T001", "T002"]
  }
}
```

### Step 8: Verify Creation

```
1. Call getJiraIssue for epic to verify it exists
2. Check epic has expected number of child stories
3. Check stories have expected number of sub-tasks
4. Report any discrepancies
```

### Step 9: Report Results

```
Spec-Kit Jira Integration Complete

Epic: <epicKey> - <feature name>
Link: https://<site>.atlassian.net/browse/<epicKey>

Stories Created: <count>
| Story | User Story | Sub-tasks |
|-------|------------|-----------|
| <key> | US1: <title> | <count> |
| <key> | US2: <title> | <count> |

Total Sub-tasks: <count>

State saved to: specs/<feature>/sk-state.json

Next Steps:
- Execute tasks: /cc-unleashed:sk-execute <feature>
- View in Jira: <epic URL>
```

---

## Error Handling

### Partial Creation Failure

If Jira creation fails mid-process:

1. Save partial sk-state.json with what was created
2. Mark failed items in state
3. Use AskUserQuestion:
   - "Retry failed operation"
   - "Skip and continue"
   - "Abort (manual cleanup needed)"
4. Log failure for resume awareness

### Resume from Partial State

If sk-state.json exists with partial data:

1. Read existing state
2. Identify missing Jira issues
3. Ask user: "Resume from partial state?" (Yes/Start fresh)
4. If resume: Only create missing items

---

## See Also

- `reference.md` - Jira field mappings, spec.md/tasks.md format examples
- `/cc-unleashed:sk-execute` - Execute tasks after Jira creation
- `/cc-unleashed:jira-plan` - For cc-unleashed native plans (non-spec-kit)
