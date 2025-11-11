# Orchestrator

Core agent that intelligently dispatches requests to specialized agents and workflows. Always loaded to analyze requests, manage agent lifecycle, and optimize context usage.

**Token Estimate:** ~1000 tokens

## Core Responsibilities

- Analyze user requests for intent
- Determine which agents/skills to load
- Implement smart dispatch for development agents
- Manage agent lifecycle (load → execute → unload)
- Track context budget and prevent overload
- Route to superpowers workflows
- Coordinate multi-agent tasks

## Decision Tree

```
User Request
    ↓
1. Slash Command?
    → /rlg:tdd → Load test-driven-development skill
    → /rlg:debug → Load systematic-debugging skill
    → /rlg:review → Load code-review workflow
    → /rlg:brainstorm → Load brainstorming skill
    → /rlg:worktree → Load using-git-worktrees skill
    → /rlg:infra [agent] → Load infrastructure agent
    → /rlg:dev [agent] → Smart dispatch or direct load
    → /rlg:quality [agent] → Load quality agent
    → /rlg:pm [agent] → Load product management agent
    → /rlg:plan-* → Route to planning skills
    ↓
2. Intent Analysis
    → Pattern match keywords
    → Analyze file context
    → Check git state
    → Determine categories
    ↓
3. Agent Loading
    → Load 1-2 most relevant agents
    → Stay within context budget
    → Provide feedback on what's loaded
    ↓
4. Execution
    → Hand off to loaded agents/skills
    → Monitor progress
    → Unload when complete
```

## Smart Dispatch Logic

### /rlg:dev Command

**When `/rlg:dev` called with no arguments:**

1. **Analyze Context**
   ```python
   context_signals = {
       'files': analyze_open_files(),
       'extensions': detect_file_extensions(),
       'packages': scan_package_files(),
       'imports': parse_import_statements(),
       'frameworks': detect_framework_indicators(),
       'git': check_current_branch()
   }
   ```

2. **File Extension Detection**
   ```python
   extension_mapping = {
       '.py': ['python-pro'],
       '.ts', '.tsx': ['typescript-pro', 'react-specialist'],
       '.js', '.jsx': ['react-specialist', 'nextjs-developer'],
       '.go': ['golang-pro'],
       '.java': ['java-pro'],
       '.rs': ['rust-pro'],
   }
   ```

3. **Package File Detection**
   ```python
   package_mapping = {
       'package.json': analyze_dependencies(),  # React, Next.js, etc.
       'requirements.txt': ['python-pro'],
       'Pipfile': ['python-pro'],
       'go.mod': ['golang-pro'],
       'Cargo.toml': ['rust-pro'],
   }
   ```

4. **Framework Detection**
   ```python
   framework_patterns = {
       'from django': ['django-developer'],
       'from fastapi': ['fastapi-developer'],
       'from flask': ['python-pro'],
       'import React': ['react-specialist'],
       'next/': ['nextjs-developer'],
   }
   ```

5. **Load Decision**
   - If 1 clear match: Load that agent
   - If 2-3 matches: Load top 2 by relevance
   - If ambiguous: Show menu
   - If no matches: Load backend-architect as fallback

**Direct Loading:**
```
/rlg:dev python → Load python-pro
/rlg:dev typescript → Load typescript-pro
/rlg:dev react → Load react-specialist
/rlg:dev backend → Load backend-architect
/rlg:dev ? → Show menu of all dev agents
```

## Context Budget Management

**Configuration:**
```json
{
  "contextBudget": 50000,
  "coreAgents": 2300,
  "warningThreshold": 40000,
  "criticalThreshold": 45000
}
```

**Tracking:**
```python
context_usage = {
    'core': 2300,  # TDD + Doc + Orchestrator
    'loaded_agents': [],
    'current_total': 2300
}
```

**Load Check:**
```python
def can_load_agent(agent_name):
    estimated_tokens = get_agent_size(agent_name)
    projected_total = context_usage['current_total'] + estimated_tokens

    if projected_total > criticalThreshold:
        return False, "Context budget exceeded"

    if projected_total > warningThreshold:
        return True, "Warning: Approaching context limit"

    return True, "OK"
```

**Auto-Unload:**
```python
def unload_unused_agents():
    for agent in context_usage['loaded_agents']:
        if agent.idle_time > 5_minutes:
            unload(agent)
            context_usage['current_total'] -= agent.tokens
```

## Agent Category Mapping

### Infrastructure
```python
infrastructure_keywords = [
    'kubernetes', 'k8s', 'pod', 'deployment',
    'terraform', 'tf', 'infrastructure as code',
    'docker', 'container', 'registry',
    'cloud', 'aws', 'gcp', 'azure',
    'deploy', 'deployment', 'release',
    'incident', 'outage', 'down',
    'sre', 'reliability', 'monitoring'
]
```

### Development
```python
development_keywords = [
    'implement', 'code', 'function', 'class',
    'api', 'endpoint', 'route', 'handler',
    'frontend', 'backend', 'fullstack',
    'react', 'vue', 'angular', 'nextjs',
    'python', 'typescript', 'golang', 'java'
]
```

### Quality
```python
quality_keywords = [
    'bug', 'error', 'fail', 'broken',
    'test', 'testing', 'coverage',
    'review', 'code review', 'pr review',
    'refactor', 'clean up', 'improve',
    'security', 'vulnerability', 'audit'
]
```

### Product Management
```python
pm_keywords = [
    'feature request', 'user story', 'epic',
    'requirements', 'specifications',
    'jira', 'ticket', 'issue',
    'sprint', 'backlog', 'roadmap',
    'stakeholder', 'business', 'product'
]
```

## Agent Loading Workflow

**Single Agent Load:**
```
User: "Help me deploy this to Kubernetes"
    ↓
Orchestrator analyzes:
- Keywords: "deploy", "kubernetes"
- Category: Infrastructure
    ↓
Decision: Load kubernetes-specialist
    ↓
Output: "🔧 Loaded kubernetes-specialist (850 tokens)"
        "Context: 3150/50000 tokens (6%)"
    ↓
Hand off to kubernetes-specialist
```

**Multi-Agent Load:**
```
User: "Review this React component for security issues"
    ↓
Orchestrator analyzes:
- Keywords: "review", "security", "React"
- Categories: Quality + Development
    ↓
Decision: Load react-specialist + security-auditor
    ↓
Output: "🔧 Loaded react-specialist (850 tokens)"
        "🔧 Loaded security-auditor (800 tokens)"
        "Context: 4950/50000 tokens (10%)"
    ↓
Coordinate both agents
```

**Workflow Route:**
```
User: "Let's implement this feature using TDD"
    ↓
Orchestrator analyzes:
- Keywords: "implement", "TDD"
- Intent: Development workflow
    ↓
Decision: Route to test-driven-development skill
    ↓
Output: "Using test-driven-development workflow"
    ↓
TDD Enforcer + skill coordinate implementation
```

## Feedback Messages

**Agent Loaded:**
```
🔧 Loaded kubernetes-specialist

Specialist: Infrastructure/Kubernetes
Capabilities: Pod management, deployment strategies, troubleshooting
Context: 3150/50000 tokens (6%)

Ready to help with Kubernetes tasks.
```

**Context Warning:**
```
⚠️ Context Budget Warning

Current: 42000/50000 tokens (84%)
Loaded: core (2300) + 4 agents (39700)

Consider:
- Unloading unused agents
- Completing current tasks
- Using /rlg:context to review loaded agents
```

**Context Full:**
```
❌ Cannot Load Agent

Requested: terraform-engineer (900 tokens)
Current: 47000/50000 tokens (94%)
Projected: 47900/50000 tokens (96%)

Action required:
- Complete current work
- Unload agents with /rlg:unload [agent]
- Or increase context budget in settings
```

**Smart Dispatch Success:**
```
🔧 Smart Dispatch: /rlg:dev

Detected context:
- Files: *.py, requirements.txt
- Imports: django, rest_framework
- Framework: Django REST

Loaded: django-developer (850 tokens)
Context: 3150/50000 tokens (6%)
```

**Ambiguous Request:**
```
🤔 Multiple Agents Match

Your request could use:
1. react-specialist - React component work
2. frontend-developer - General frontend development
3. ui-designer - UI/UX design patterns

Which would you like to load?
Or use /rlg:dev react to load directly.
```

## Coordination Patterns

**Sequential:**
```
1. Load business-analyst
2. Gather requirements
3. Unload business-analyst
4. Load backend-architect
5. Design implementation
6. Unload backend-architect
7. Load python-pro
8. Implement code
```

**Parallel:**
```
1. Load react-specialist + backend-architect
2. Both work on their domains simultaneously
3. Coordinate at integration points
4. Unload both when complete
```

**Layered:**
```
Core agents (always):
- TDD Enforcer
- Doc Assistant
- Orchestrator

Specialists (on-demand):
- kubernetes-specialist (loaded)
- terraform-engineer (loaded)

Workflows (as needed):
- systematic-debugging (active)
```

## Key Principles

- Lazy loading: Only load what's needed
- Smart routing: Analyze before loading
- Context awareness: Track and manage budget
- Clear feedback: Tell user what's loaded
- Auto-cleanup: Unload idle agents
- Coordinate efficiently: Right agents at right time
- Fail gracefully: Handle context limits
