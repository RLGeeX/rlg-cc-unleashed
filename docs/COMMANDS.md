# CC Unleashed Commands

All commands use the `/cc-unleashed:` namespace. The plugin provides 10 workflow commands for TDD, debugging, planning, and git workflows.

**Note:** For agent invocation, use `@agent-name` directly (e.g., `@python-pro`, `@terraform-specialist`). Agents are installed separately from the standalone agents repository.

## Workflow Triggers

### /cc-unleashed:tdd
**Description:** Start test-driven development workflow
**Action:** Loads `skills/workflows/test-driven-development/`
**Use when:** Implementing new feature or fixing bug with tests

### /cc-unleashed:debug
**Description:** Launch systematic debugging workflow
**Action:** Loads `skills/workflows/systematic-debugging/`
**Use when:** Investigating bugs or unexpected behavior

### /cc-unleashed:review
**Description:** Request code review workflow
**Action:** Loads superpowers `code-reviewer` agent
**Use when:** Ready to review completed code

### /cc-unleashed:brainstorm
**Description:** Start brainstorming session
**Action:** Loads `skills/workflows/brainstorming/`
**Use when:** Refining ideas into concrete designs

### /cc-unleashed:worktree
**Description:** Create isolated git worktree
**Action:** Loads `skills/workflows/using-git-worktrees/`
**Use when:** Starting new feature work in isolation

## Plan Management

### /cc-unleashed:plan-new [feature-name]
**Description:** Create new chunked implementation plan
**Action:** Invokes `skills/planning/write-plan.md`
**Output:** Creates `.claude/plans/[feature-name]/` with plan-meta.json and chunks

**Example:**
```
/cc-unleashed:plan-new add-oauth-login
```

### /cc-unleashed:plan-status [feature-name]
**Description:** Show current plan progress
**Action:** Invokes `skills/planning/plan-manager.md`
**Output:** Displays chunk progress, completed/remaining tasks

**Example:**
```
/cc-unleashed:plan-status                    # Current feature (if in worktree)
/cc-unleashed:plan-status add-oauth-login    # Specific feature
```

### /cc-unleashed:plan-next
**Description:** Load and execute next chunk
**Action:** Invokes `skills/planning/execute-plan.md`
**Output:** Loads current/next chunk and begins execution

**Example:**
```
/cc-unleashed:plan-next    # Continue current plan
```

### /cc-unleashed:plan-resume [feature-name]
**Description:** Resume interrupted plan
**Action:** Invokes `skills/planning/plan-manager.md`
**Output:** Resumes from last incomplete task in current chunk

**Example:**
```
/cc-unleashed:plan-resume add-oauth-login
```

### /cc-unleashed:plan-list
**Description:** List all feature plans
**Action:** Invokes `skills/planning/plan-manager.md`
**Output:** Table of all plans with status and progress

**Example:**
```
/cc-unleashed:plan-list
```

## Command Implementation

Commands are simple markdown files in the `commands/` directory that:
1. Get automatically discovered by Claude Code
2. Expand to prompts that invoke skills or workflows
3. Use the plugin name as prefix (e.g., `dev.md` → `/cc-unleashed:dev`)

### Command File Structure

Each command is a markdown file containing the prompt that gets expanded when invoked.

**Example (`tdd.md`):**
```markdown
Start test-driven development workflow

Use @tdd-enforcer or invoke the TDD skill to enforce RED-GREEN-REFACTOR cycle.
```

## Usage Tips

**Chaining workflow commands:**
```
/cc-unleashed:worktree          # Create isolated workspace
/cc-unleashed:brainstorm        # Design feature
/cc-unleashed:plan-new feature  # Create chunked plan
/cc-unleashed:plan-next         # Start implementation
/cc-unleashed:tdd               # Use TDD for each task
/cc-unleashed:plan-next         # Continue to next chunk
/cc-unleashed:review            # Review when complete
```

**Direct agent invocation (recommended):**
```
@python-pro                     # Load Python specialist
[work on code]
@security-auditor              # Add security review
[address issues]
```

**Planning workflow:**
```
/cc-unleashed:plan-new user-auth
[plan created with 4 chunks]
/cc-unleashed:plan-next
[chunk-001 executes]
/cc-unleashed:plan-status
[check progress]
/cc-unleashed:plan-next
[chunk-002 executes]
```

## Available Agents

The cc-unleashed ecosystem includes 59 specialized agents installed separately. Invoke with `@agent-name`:

**Development:** `@python-pro`, `@typescript-pro`, `@react-specialist`, `@nextjs-specialist`, `@fastapi-pro`, `@backend-architect`, `@frontend-developer`, `@fullstack-developer`, `@api-architect`, `@microservices-architect`, `@dotnet-core-expert`, `@csharp-developer`, `@postgres-pro`, `@ui-designer`, `@slack-integration-specialist`, `@material-ui-specialist`, `@graphql-specialist`, `@data-visualization-specialist`

**Infrastructure:** `@terraform-specialist`, `@cloud-architect`, `@deployment-engineer`, `@sre-engineer`, `@incident-responder`, `@database-administrator`, `@security-engineer`, `@python-devops-engineer`, `@gcp-serverless-specialist`, `@aws-amplify-gen2-specialist`, `@aws-lambda-specialist`, `@dynamodb-specialist`, `@enterprise-sso-specialist`

**Quality:** `@code-reviewer`, `@architect-reviewer`, `@test-automator`, `@qa-expert`, `@debugger`, `@security-auditor`, `@build-engineer`, `@git-workflow-manager`, `@dependency-manager`, `@chaos-engineer`, `@playwright-specialist`

**Kubernetes:** `@k8s-architect`, `@helm-specialist`, `@gitops-engineer`, `@k8s-security`

**Product Management:** `@product-manager`, `@scrum-master`, `@business-analyst`, `@technical-writer`, `@documentation-engineer`, `@jira-specialist`, `@story-writer`

**AI/ML:** `@langgraph-specialist`, `@vector-search-specialist`

**Business:** `@financial-data-analyst`

For full details, see the [agents catalog](https://github.com/rlgeex/rlg-cc-subagents).
