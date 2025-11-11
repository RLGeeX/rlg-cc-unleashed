# RLG CC Unleashed Commands

All commands use the `/rlg:` namespace to avoid conflicts with other plugins.

## Workflow Triggers

### /rlg:tdd
**Description:** Start test-driven development workflow
**Action:** Loads `skills/workflows/test-driven-development/`
**Use when:** Implementing new feature or fixing bug with tests

### /rlg:debug
**Description:** Launch systematic debugging workflow
**Action:** Loads `skills/workflows/systematic-debugging/`
**Use when:** Investigating bugs or unexpected behavior

### /rlg:review
**Description:** Request code review workflow
**Action:** Loads superpowers `code-reviewer` agent
**Use when:** Ready to review completed code

### /rlg:brainstorm
**Description:** Start brainstorming session
**Action:** Loads `skills/workflows/brainstorming/`
**Use when:** Refining ideas into concrete designs

### /rlg:worktree
**Description:** Create isolated git worktree
**Action:** Loads `skills/workflows/using-git-worktrees/`
**Use when:** Starting new feature work in isolation

## Agent Dispatchers

### /rlg:infra [agent-name]
**Description:** Load infrastructure category agent
**Available agents:**
- `terraform` - terraform-engineer
- `devops` - devops-engineer
- `cloud` - cloud-architect
- `deploy` - deployment-engineer
- `incident` - incident-responder
- `sre` - sre-engineer

**Examples:**
```
/rlg:infra terraform     # Load terraform engineer
/rlg:infra               # Show available infrastructure agents
```

**Note:** For Kubernetes specialists, use `/rlg:k8s` instead.

### /rlg:dev [agent-name]
**Description:** Smart dispatch or direct load development agent

**Smart Dispatch (no arguments):**
- Analyzes current files, extensions, imports
- Auto-loads 1-2 most relevant agents
- Falls back to menu if ambiguous

**Direct Loading:**
- `python` - python-pro
- `typescript` - typescript-pro
- `golang` - golang-pro
- `react` - react-specialist
- `nextjs` - nextjs-developer
- `django` - django-developer
- `fastapi` - fastapi-developer
- `backend` - backend-architect
- `frontend` - frontend-developer
- `fullstack` - fullstack-developer
- `mobile` - mobile-developer
- `api` - api-designer

**Examples:**
```
/rlg:dev                 # Smart dispatch based on context
/rlg:dev python          # Load Python specialist directly
/rlg:dev ?               # Show all available dev agents
```

### /rlg:quality [agent-name]
**Description:** Load quality category agent
**Available agents:**
- `review` - code-reviewer
- `test` - test-automator
- `qa` - qa-expert
- `debug` - debugger
- `refactor` - refactoring-specialist
- `security` - security-auditor

**Examples:**
```
/rlg:quality security    # Load security auditor
/rlg:quality             # Show available quality agents
```

### /rlg:pm [agent-name]
**Description:** Load product management agent
**Available agents:**
- `analyst` - business-analyst
- `owner` - product-owner
- `story` - story-writer
- `jira` - jira-specialist
- `scrum` - scrum-master

**Examples:**
```
/rlg:pm story            # Load story writer
/rlg:pm                  # Show available PM agents
```

### /rlg:k8s [agent-name]
**Description:** Load Kubernetes specialist agent
**Available agents:**
- `architect` - k8s-architect (cluster design, platform engineering)
- `helm` - helm-specialist (chart development, templating)
- `gitops` - gitops-engineer (ArgoCD, Flux, progressive delivery)
- `security` - k8s-security (policies, RBAC, admission control)
- `mesh` - service-mesh-expert (Istio, Linkerd, Cilium)

**Available skills:**
- `gitops-workflow` - GitOps patterns with ArgoCD/Flux
- `helm-chart-scaffolding` - Helm chart creation templates
- `k8s-manifest-generator` - Kubernetes YAML generation
- `k8s-security-policies` - OPA, Kyverno, network policies

**Examples:**
```
/rlg:k8s architect       # Load K8s architect for cluster design
/rlg:k8s helm            # Load Helm specialist for chart work
/rlg:k8s gitops          # Load GitOps engineer for ArgoCD/Flux
/rlg:k8s security        # Load K8s security specialist
/rlg:k8s mesh            # Load service mesh expert
/rlg:k8s                 # Show available K8s agents
```

**Parallel dispatch example:**
```
# Load multiple K8s specialists for complex task
/rlg:k8s helm
/rlg:k8s security
/rlg:k8s gitops
```

## Plan Management

### /rlg:plan-new [feature-name]
**Description:** Create new chunked implementation plan
**Action:** Invokes `skills/planning/write-plan.md`
**Output:** Creates `.claude/plans/[feature-name]/` with plan-meta.json and chunks

**Example:**
```
/rlg:plan-new add-oauth-login
```

### /rlg:plan-status [feature-name]
**Description:** Show current plan progress
**Action:** Invokes `skills/planning/plan-manager.md`
**Output:** Displays chunk progress, completed/remaining tasks

**Example:**
```
/rlg:plan-status                    # Current feature (if in worktree)
/rlg:plan-status add-oauth-login    # Specific feature
```

### /rlg:plan-next
**Description:** Load and execute next chunk
**Action:** Invokes `skills/planning/execute-plan.md`
**Output:** Loads current/next chunk and begins execution

**Example:**
```
/rlg:plan-next    # Continue current plan
```

### /rlg:plan-resume [feature-name]
**Description:** Resume interrupted plan
**Action:** Invokes `skills/planning/plan-manager.md`
**Output:** Resumes from last incomplete task in current chunk

**Example:**
```
/rlg:plan-resume add-oauth-login
```

### /rlg:plan-list
**Description:** List all feature plans
**Action:** Invokes `skills/planning/plan-manager.md`
**Output:** Table of all plans with status and progress

**Example:**
```
/rlg:plan-list
```

## Command Implementation

Commands are implemented as Claude Code slash commands that:
1. Parse command and arguments
2. Route to orchestrator for agent loading
3. Or directly invoke skills
4. Provide feedback on what's loaded
5. Track context usage

### Command File Structure

```markdown
---
name: rlg:command-name
description: What this command does
---

# Command Implementation

Invoke: [skill or agent path]
Arguments: [parameter descriptions]
Output: [what user sees]
```

### Integration with Orchestrator

Commands trigger orchestrator decision tree:
1. Command parsed
2. Orchestrator analyzes intent
3. Loads appropriate agents/skills
4. Provides context feedback
5. Executes requested action

## Usage Tips

**Chaining commands:**
```
/rlg:worktree          # Create isolated workspace
/rlg:brainstorm        # Design feature
/rlg:plan-new feature  # Create chunked plan
/rlg:plan-next         # Start implementation
/rlg:tdd               # Use TDD for each task
/rlg:plan-next         # Continue to next chunk
/rlg:review            # Review when complete
```

**Context management:**
```
/rlg:dev               # Smart load based on context
[work on code]
/rlg:quality security  # Add security review
[address issues]
[orchestrator auto-unloads when idle]
```

**Planning workflow:**
```
/rlg:plan-new user-auth
[plan created with 4 chunks]
/rlg:plan-next
[chunk-001 executes]
/rlg:plan-status
[check progress]
/rlg:plan-next
[chunk-002 executes]
```
