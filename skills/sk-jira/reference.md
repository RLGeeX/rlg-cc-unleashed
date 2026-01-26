# sk-jira Reference

Detailed reference for Jira field mappings, spec-kit formats, and state schema.

---

## Spec-Kit File Formats

### spec.md Format

```markdown
# Feature Name

Brief description of the feature.

## Summary

1-2 paragraph overview of what this feature accomplishes.

## User Stories

### US1: First User Story Title

As a [user type], I want [capability] so that [benefit].

**Acceptance Criteria:**
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

### US2: Second User Story Title

As a [user type], I want [capability] so that [benefit].

**Acceptance Criteria:**
- [ ] Criterion 1
- [ ] Criterion 2

## Success Criteria

- Overall success metric 1
- Overall success metric 2
```

### tasks.md Format

```markdown
# Tasks

## Setup Phase

[T001] [P] [Setup] Initialize project structure
[T002] [P] [Setup] Configure dependencies
[T003] [Setup] Set up CI/CD pipeline
  Depends: T001, T002

## US1: First User Story

[T004] [US1] Create data models
  Depends: T003
[T005] [P] [US1] Implement API endpoints
  Depends: T004
[T006] [P] [US1] Add validation logic
  Depends: T004
[T007] [US1] Write unit tests
  Depends: T005, T006

## US2: Second User Story

[T008] [US2] Build UI components
  Depends: T003
[T009] [US2] Integrate with API
  Depends: T005, T008
[T010] [US2] Add E2E tests
  Depends: T009
```

### Task Format Breakdown

```
[T001] [P] [US1] Task description
  │     │    │         │
  │     │    │         └── Task description text
  │     │    └── Parent: US1, US2, Setup, Foundational
  │     └── [P] = Parallelizable (optional)
  └── Task ID: T + 3-digit number
```

---

## Jira Field Mappings

### Standard Fields

| Jira Field | Source |
|------------|--------|
| Summary | Task description or US title |
| Description | Full context with acceptance criteria |
| Issue Type | Epic, Story, or Sub-task |
| Parent | Story key (for sub-tasks) |

### Custom Fields (vary by project)

| Purpose | Common Field IDs |
|---------|------------------|
| Epic Link | customfield_10014 |
| Story Points | customfield_10026, customfield_10016, customfield_10028 |
| Sprint | customfield_10020 |

**Discovery:** Use `getJiraIssueTypeMetaWithFields` to find actual field IDs.

### Issue Type Names

| Type | issueTypeName | Parent Required |
|------|---------------|-----------------|
| Epic | `Epic` | No |
| Story | `Story` | No (linked to Epic via field) |
| Sub-task | `Sub-task` | Yes (`parent` parameter) |

---

## sk-state.json Schema

### Initial State (after sk-jira)

```json
{
  "feature": "001-user-auth",
  "createdAt": "2026-01-26T10:00:00Z",
  "status": "ready",
  "jiraServer": "jira-pcc",
  "jira": {
    "cloudId": "abc123-def456",
    "project": "PCC",
    "epic": "PCC-100",
    "stories": {
      "US1": "PCC-101",
      "US2": "PCC-102"
    },
    "tasks": {
      "T001": { "key": "PCC-103", "story": "Setup", "status": "todo" },
      "T002": { "key": "PCC-104", "story": "Setup", "status": "todo" },
      "T003": { "key": "PCC-105", "story": "Setup", "status": "todo" },
      "T004": { "key": "PCC-106", "story": "US1", "status": "todo" },
      "T005": { "key": "PCC-107", "story": "US1", "status": "todo" }
    }
  },
  "dependencies": {
    "T003": ["T001", "T002"],
    "T004": ["T003"],
    "T005": ["T004"]
  }
}
```

### Status Values

| Status | Meaning |
|--------|---------|
| `ready` | Jira issues created, ready for execution |
| `in-progress` | Execution started |
| `paused` | Execution paused (user intervention) |
| `complete` | All tasks done |
| `error` | Unrecoverable error occurred |

---

## MCP Tool Reference

### Required Tools

| Tool | Purpose | Schema Check |
|------|---------|--------------|
| getAccessibleAtlassianResources | Get cloudId | `mcp-cli info jira-*/getAccessibleAtlassianResources` |
| getVisibleJiraProjects | List projects | `mcp-cli info jira-*/getVisibleJiraProjects` |
| getJiraProjectIssueTypesMetadata | Get issue types | `mcp-cli info jira-*/getJiraProjectIssueTypesMetadata` |
| getJiraIssueTypeMetaWithFields | Discover fields | `mcp-cli info jira-*/getJiraIssueTypeMetaWithFields` |
| createJiraIssue | Create issues | `mcp-cli info jira-*/createJiraIssue` |
| getJiraIssue | Verify creation | `mcp-cli info jira-*/getJiraIssue` |
| editJiraIssue | Update issues | `mcp-cli info jira-*/editJiraIssue` |

### Example MCP Calls

**Get Cloud ID:**
```bash
mcp-cli call jira-pcc/getAccessibleAtlassianResources '{}'
```

**Create Epic:**
```bash
mcp-cli call jira-pcc/createJiraIssue '{
  "cloudId": "abc123",
  "projectKey": "PCC",
  "issueTypeName": "Epic",
  "summary": "User Authentication Feature",
  "description": "Implement OAuth 2.0 authentication flow"
}'
```

**Create Story linked to Epic:**
```bash
mcp-cli call jira-pcc/createJiraIssue '{
  "cloudId": "abc123",
  "projectKey": "PCC",
  "issueTypeName": "Story",
  "summary": "US1: User Login",
  "description": "As a user, I want to log in...",
  "additional_fields": {
    "customfield_10014": "PCC-100"
  }
}'
```

**Create Sub-task:**
```bash
mcp-cli call jira-pcc/createJiraIssue '{
  "cloudId": "abc123",
  "projectKey": "PCC",
  "issueTypeName": "Sub-task",
  "summary": "[T004] Create user data model",
  "description": "Task from spec-kit",
  "parent": "PCC-101"
}'
```

---

## Parsing Algorithms

### Extract User Stories from spec.md

```
1. Read file line by line
2. Find lines matching: /^### (US\d+): (.+)$/
3. Extract US ID and title
4. Capture description until next ### or ## heading
5. Find "Acceptance Criteria:" section
6. Capture checklist items until next section
```

### Extract Tasks from tasks.md

```
1. Read file line by line
2. Find lines matching: /^\[T(\d{3})\]\s*(\[P\])?\s*\[([^\]]+)\]\s*(.+)$/
3. Extract:
   - Task ID (T + number)
   - Parallel flag (if [P] present)
   - Parent (US1, US2, Setup, etc.)
   - Description
4. Check next line for "Depends:" prefix
5. Parse dependency list (comma-separated task IDs)
```

### Build Dependency Graph

```
1. Create adjacency list from dependencies
2. Topological sort to determine execution order
3. Group parallel tasks ([P] flag + same phase + no inter-dependencies)
```

---

## Error Recovery

### Partial State Recovery

If sk-state.json exists with some Jira keys:

```
1. Read existing state
2. For each expected item:
   - If key exists in state: verify with getJiraIssue
   - If key missing: mark for creation
3. Only create missing items
4. Update state with new keys
```

### Duplicate Detection

Before creating:
```
1. Search Jira: project = "PCC" AND summary ~ "<feature name>" AND type = Epic
2. If found: Ask user (Use existing / Create new / Abort)
3. If using existing: Populate state from existing issues
```

---

## Story Points Calculation

Default heuristics (can be overridden):

| Task Characteristics | Story Points |
|---------------------|--------------|
| Simple task (1 dependency, no [P]) | 1 |
| Standard task (2-3 dependencies) | 2 |
| Complex task (4+ dependencies or integration) | 3 |
| Parallel group (reduces total) | Sum * 0.7 |

Story SP = Sum of child task SPs
