# sk-execute Reference

Agent detection rules, state schema, and constitution validation details.

---

## Agent Detection Heuristics

### File Path Patterns

| Pattern | Primary Agent | Notes |
|---------|---------------|-------|
| `*.py`, `requirements.txt` | `@python-pro` | |
| `*.tf`, `*.tfvars` | `@terraform-specialist` | |
| `*.ts`, `*.tsx` | See disambiguation | React or Next.js |
| `*.cs`, `*.csproj` | See disambiguation | C# or .NET Core |
| `Dockerfile`, `docker-compose*` | `@devops-engineer` | |
| `*.sql`, migrations | See disambiguation | Postgres default |
| `*.md` (docs) | `@documentation-engineer` | |
| `*test*`, `*spec*` | See disambiguation | Test vs QA |
| `*.yaml`, `*.yml` (k8s) | `@k8s-architect` | If k8s context |
| `*.go` | `@fullstack-developer` | |
| `*.rs` | `@fullstack-developer` | |

### Keyword Patterns

| Keywords in Task | Agent |
|------------------|-------|
| "API", "endpoint", "REST", "GraphQL" | `@api-architect` |
| "schema", "model", "entity", "database" | `@backend-architect` |
| "component", "UI", "frontend", "page" | `@frontend-developer` |
| "infrastructure", "deploy", "cloud" | `@cloud-architect` |
| "security", "auth", "RBAC", "SSO" | `@security-engineer` |
| "performance", "optimize", "cache" | `@backend-architect` |
| "CI/CD", "pipeline", "workflow" | `@devops-engineer` |
| "helm", "chart", "kubernetes" | `@helm-specialist` |
| "terraform", "IaC", "module" | `@terraform-specialist` |

---

## Agent Disambiguation Rules

### TypeScript/TSX Files

```
1. Check for Next.js indicators:
   - next.config.js exists
   - next.config.mjs exists
   - next.config.ts exists
   - app/layout.tsx exists
   - pages/_app.tsx exists

2. Check plan.md for mentions:
   - "Next.js" → @nextjs-specialist
   - "Vite" or "Create React App" → @react-specialist

3. Default: @react-specialist
```

### C#/.NET Files

```
1. Check plan.md for mentions:
   - "ASP.NET" → @dotnet-core-expert
   - "Web API" → @dotnet-core-expert
   - "minimal API" → @dotnet-core-expert
   - "Blazor" → @dotnet-core-expert

2. Check *.csproj for OutputType:
   - <OutputType>Exe</OutputType> (console) → @csharp-developer
   - <OutputType>Library</OutputType> → @csharp-developer
   - No OutputType (web default) → @dotnet-core-expert

3. Default: @csharp-developer
```

### SQL/Database Files

```
1. Check plan.md for database type:
   - "PostgreSQL", "Postgres" → @postgres-pro
   - "MySQL", "MariaDB" → @database-administrator
   - "SQL Server", "MSSQL" → @database-administrator
   - "MongoDB" → @database-administrator

2. Check docker-compose.yml for images:
   - postgres:* → @postgres-pro
   - mysql:* → @database-administrator
   - mongo:* → @database-administrator

3. Default: @postgres-pro
```

### Test Files

```
1. Check task description:
   - "write tests", "add tests", "unit test" → @test-automator
   - "test strategy", "QA", "quality" → @qa-expert
   - "E2E", "integration test", "playwright" → @playwright-specialist

2. Check file patterns:
   - *.spec.ts, *.test.ts → @test-automator
   - *e2e*, *playwright* → @playwright-specialist

3. Default: @test-automator
```

### Still Ambiguous

If disambiguation rules don't resolve:

```
1. Include top 2-3 candidates in AskUserQuestion options
2. Add "(Recommended)" to the most likely based on plan.md context
3. Always include "Other" for user to specify
```

---

## Constitution Validation

### How to Evaluate Principles

For each principle in constitution.md:

1. **Extract the principle statement** (after "I.", "II.", etc.)
2. **Identify key constraints** (MUST, NEVER, ALWAYS keywords)
3. **Scan spec.md and plan.md** for violations
4. **Report with evidence**

### Example Principle Evaluation

**Principle:** "I. Prompt-First Architecture - All functionality MUST be pure markdown/YAML prompts. No build tools."

**Check:**
- Scan plan.md for: "compile", "build step", "webpack", "npm run build"
- Scan for: CI/CD that runs build commands
- Scan for: Dockerfile with build steps

**Output:**
```json
{
  "principle": "I. Prompt-First Architecture",
  "status": "pass",
  "reason": "Plan uses markdown prompts only, no build tools mentioned"
}
```

or

```json
{
  "principle": "I. Prompt-First Architecture",
  "status": "fail",
  "reason": "plan.md line 45 mentions 'npm run build' step",
  "evidence": "Step 3: Run npm run build to compile TypeScript"
}
```

### Violation Report Format

```
CONSTITUTION VALIDATION FAILED

The following principles are violated:

1. I. Prompt-First Architecture
   Violation: plan.md mentions build step
   Evidence: "Step 3: Run npm run build to compile TypeScript"
   Location: plan.md line 45

2. V. Safety Standards
   Violation: No timeout limits specified for autonomous execution
   Evidence: Missing safeguards section
   Location: spec.md

EXECUTION BLOCKED

Resolution required:
- Update plan.md to remove build steps
- Add safeguards section to spec.md

After fixing, re-run: /cc-unleashed:sk-execute <feature>
```

---

## sk-state.json Full Schema

### During Execution

```json
{
  "feature": "001-user-auth",
  "createdAt": "2026-01-26T10:00:00Z",
  "status": "in-progress",
  "jiraServer": "jira-pcc",

  "constitutionValidation": {
    "validated": true,
    "timestamp": "2026-01-26T10:05:00Z",
    "results": [
      { "principle": "I. Prompt-First", "status": "pass", "reason": "..." },
      { "principle": "II. Persona-Based", "status": "pass", "reason": "..." }
    ]
  },

  "jira": {
    "cloudId": "abc123",
    "project": "PCC",
    "epic": "PCC-100",
    "stories": {
      "Setup": "PCC-101",
      "US1": "PCC-102",
      "US2": "PCC-103"
    },
    "tasks": {
      "T001": { "key": "PCC-110", "story": "Setup", "status": "done", "agent": "@python-pro" },
      "T002": { "key": "PCC-111", "story": "Setup", "status": "done", "agent": "@devops-engineer" },
      "T003": { "key": "PCC-112", "story": "US1", "status": "in-progress", "agent": "@react-specialist" },
      "T004": { "key": "PCC-113", "story": "US1", "status": "todo" },
      "T005": { "key": "PCC-114", "story": "US2", "status": "todo" }
    }
  },

  "dependencies": {
    "T003": ["T001", "T002"],
    "T004": ["T003"],
    "T005": ["T003"]
  },

  "agentAssignments": {
    "T001": "@python-pro",
    "T002": "@devops-engineer",
    "T003": "@react-specialist"
  },

  "currentPhase": "US1",
  "currentTask": "T003",

  "phases": {
    "Setup": "complete",
    "US1": "in-progress",
    "US2": "pending"
  },

  "reviewGates": {
    "Setup": {
      "status": "passed",
      "reviewer": "@code-reviewer",
      "timestamp": "2026-01-26T11:00:00Z",
      "notes": "Clean implementation, good test coverage"
    }
  },

  "executionLog": [
    {
      "task": "T001",
      "agent": "@python-pro",
      "started": "2026-01-26T10:10:00Z",
      "completed": "2026-01-26T10:25:00Z",
      "duration": "15m",
      "status": "success"
    },
    {
      "task": "T002",
      "agent": "@devops-engineer",
      "started": "2026-01-26T10:25:00Z",
      "completed": "2026-01-26T10:40:00Z",
      "duration": "15m",
      "status": "success"
    }
  ]
}
```

### Completion State

```json
{
  "feature": "001-user-auth",
  "createdAt": "2026-01-26T10:00:00Z",
  "completedAt": "2026-01-26T14:30:00Z",
  "status": "complete",
  "jiraServer": "jira-pcc",

  "summary": {
    "totalTasks": 10,
    "completedTasks": 10,
    "totalDuration": "4h 30m",
    "phases": ["Setup", "US1", "US2"],
    "agents": ["@python-pro", "@react-specialist", "@test-automator"]
  },

  "constitutionValidation": { ... },
  "jira": { ... },
  "reviewGates": { ... },
  "executionLog": [ ... ]
}
```

---

## Phase Detection

### Identifying Phase Boundaries

From tasks.md structure:

```markdown
## Setup Phase
[T001] ...
[T002] ...

## US1: User Login
[T003] ...
[T004] ...
```

**Phase transition occurs when:**
- All tasks in current phase are "done"
- Next pending task has different parent (Setup → US1)

### Phase Order

Typical order (from tasks.md headers):
1. Setup
2. Foundational (optional)
3. US1, US2, US3... (in order)
4. Integration (optional)
5. Testing/QA (optional)

---

## Parallel Task Detection

### Criteria for Parallel Execution

Tasks can run in parallel if:

1. **Same phase** (e.g., both in US1)
2. **Have [P] flag** in tasks.md
3. **No inter-dependencies** (T005 doesn't depend on T006 and vice versa)
4. **All external dependencies satisfied**

### Example

```markdown
## US1: User Login
[T004] [US1] Create data model
  Depends: T003
[T005] [P] [US1] Implement login endpoint
  Depends: T004
[T006] [P] [US1] Implement logout endpoint
  Depends: T004
[T007] [US1] Write tests
  Depends: T005, T006
```

**Parallel group:** T005 and T006
- Both have [P]
- Both depend on T004 (external, satisfied)
- Neither depends on each other
- Both in US1 phase

---

## MCP Tool Reference

### Jira Transitions

```bash
# Get available transitions
mcp-cli call jira-pcc/getTransitionsForJiraIssue '{
  "cloudId": "<cloudId>",
  "issueIdOrKey": "<key>"
}'

# Execute transition
mcp-cli call jira-pcc/transitionJiraIssue '{
  "cloudId": "<cloudId>",
  "issueIdOrKey": "<key>",
  "transitionName": "In Progress"
}'
```

### Adding Comments

```bash
mcp-cli call jira-pcc/addCommentToJiraIssue '{
  "cloudId": "<cloudId>",
  "issueIdOrKey": "<key>",
  "comment": "Task completed by @python-pro\n\nChanges:\n- Created user model\n- Added validation"
}'
```

---

## Error Recovery Patterns

### Agent Failure

```
State before: { "T003": { "status": "in-progress" } }
Error occurs during agent execution

Recovery:
1. Update state: { "T003": { "status": "failed", "error": "..." } }
2. Ask user for action
3. If retry: Reset to in-progress, re-dispatch
4. If skip: Mark as skipped, log, continue
5. If pause: Save state, exit
```

### Jira API Failure

```
1. Log error details
2. Ask user: Retry / Skip Jira / Abort
3. If skip: Continue execution without Jira updates
4. Mark jiraSkipped: true in state
5. Manual Jira sync needed later
```

### Review Gate Failure

```
1. Present concerns to user
2. Do NOT allow automatic override
3. Options: Fix → Re-review / Manual override (logged) / Abort
4. If override: Log as "overridden" not "passed"
```
