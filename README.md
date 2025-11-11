# RLG CC Unleashed

Streamlined Claude Code plugin with intelligent context management, core agents, on-demand specialists, and chunked planning system.

**Version:** 1.0.0
**Author:** RLGeeX
**Requires:** Claude Code >=2.0.31

## Overview

RLG CC Unleashed combines the best features from multiple Claude Code plugins (superpowers, claude-code-sub-agents, etc.) into a single, optimized plugin that:

- **Manages context efficiently**: 3 core agents (~2300 tokens) always loaded, 30+ specialists on-demand
- **Enforces best practices**: TDD, documentation, code quality baked in
- **Breaks down complexity**: Chunked planning system for large features
- **Smart agent dispatch**: Auto-loads relevant agents based on code context
- **Comprehensive coverage**: Infrastructure, Development, Quality, Product Management

## Quick Start

### Installation

Choose one of the following methods:

#### Method 1: Direct Plugin Installation (Recommended)

```bash
/plugin add github:RLGeeX/rlg-cc-unleashed
```

#### Method 2: Marketplace Installation

```bash
/plugin marketplace add RLGeeX/rlg-cc-unleashed
```

#### Method 3: Manual Installation

```bash
git clone https://github.com/RLGeeX/rlg-cc-unleashed ~/.claude/plugins/rlg-cc-unleashed
```

After installation, restart Claude Code or reload plugins, then verify:

```bash
/rlg:plan-list
```

### First Steps

**Start a new feature with TDD:**
```
/rlg:worktree           # Create isolated workspace
/rlg:brainstorm         # Design your feature
/rlg:plan-new my-feature  # Create chunked plan
/rlg:plan-next          # Start first chunk with TDD
```

**Get help with specific technology:**
```
/rlg:dev                # Auto-detect and load relevant agent
/rlg:infra kubernetes   # Load Kubernetes specialist
/rlg:quality security   # Load security auditor
```

## Core Architecture

### Always-Loaded Core (2300 tokens)

**TDD Enforcer** (~500 tokens)
- Enforces test-driven development
- Verifies RED-GREEN-REFACTOR cycle
- Blocks untested code

**Doc Assistant** (~800 tokens)
- Maintains README, CLAUDE.md, API docs
- Suggests updates on code changes
- Generates documentation

**Orchestrator** (~1000 tokens)
- Analyzes requests and loads agents
- Smart dispatch for development agents
- Manages context budget
- Coordinates multi-agent tasks

### On-Demand Specialists (28500 tokens available)

#### Infrastructure (6 agents, ~5000 tokens)
- terraform-engineer
- devops-engineer
- sre-engineer
- cloud-architect
- deployment-engineer
- incident-responder

#### Development (12 agents, ~10000 tokens)
- python-pro, typescript-pro, golang-pro
- react-specialist, nextjs-developer
- django-developer, fastapi-developer
- backend-architect, frontend-developer, fullstack-developer
- mobile-developer, api-designer

#### Quality (6 agents, ~5000 tokens)
- code-reviewer
- test-automator
- qa-expert
- debugger
- refactoring-specialist
- security-auditor

#### Product Management (5 agents, ~4000 tokens)
- business-analyst
- product-owner
- story-writer
- jira-specialist
- scrum-master

#### Kubernetes (5 agents, ~3500 tokens)
- k8s-architect - cluster design, platform engineering
- helm-specialist - chart development, templating
- gitops-engineer - ArgoCD, Flux, progressive delivery
- k8s-security - policies, RBAC, admission control
- service-mesh-expert - Istio, Linkerd, Cilium

## Chunked Planning System

Traditional plans put all 30 tasks in one file, bloating your context. RLG CC Unleashed breaks plans into digestible chunks:

### How It Works

```
.claude/plans/my-feature/
├── plan-meta.json       # Feature metadata
├── chunk-001.md         # Setup (7 tasks)
├── chunk-002.md         # Implementation (8 tasks)
├── chunk-003.md         # Testing (6 tasks)
└── chunk-004.md         # Documentation (9 tasks)
```

**Benefits:**
- Only 1 chunk (~300-500 tokens) loaded at a time
- Clear progress tracking
- Natural break points
- Pause/resume friendly

### Creating a Plan

```bash
/rlg:plan-new feature-name
```

This will:
1. Use brainstorming to understand the feature
2. Break it into logical chunks (5-10 tasks each)
3. Save to `.claude/plans/feature-name/`
4. Offer to start execution

### Executing Plans

```bash
/rlg:plan-next    # Execute next chunk (or resume current)
```

Execution flow:
1. Load current chunk
2. Execute tasks in batches (default 3)
3. Report and get feedback
4. Continue until chunk complete
5. Move to next chunk

### Managing Plans

```bash
/rlg:plan-list                 # List all plans
/rlg:plan-status               # Show current progress
/rlg:plan-status feature-name  # Check specific plan
/rlg:plan-resume feature-name  # Resume interrupted plan
```

## Commands Reference

All commands use `/rlg:` namespace to avoid conflicts.

### Workflow Triggers

| Command | Description | Loads |
|---------|-------------|-------|
| `/rlg:tdd` | Start TDD workflow | test-driven-development skill |
| `/rlg:debug` | Launch debugging | systematic-debugging skill |
| `/rlg:review` | Request code review | code-reviewer agent |
| `/rlg:brainstorm` | Design session | brainstorming skill |
| `/rlg:worktree` | Create worktree | using-git-worktrees skill |

### Agent Dispatchers

| Command | Description | Smart Dispatch |
|---------|-------------|----------------|
| `/rlg:infra [agent]` | Infrastructure agents | No |
| `/rlg:dev [agent]` | Development agents | **Yes** |
| `/rlg:quality [agent]` | Quality agents | No |
| `/rlg:pm [agent]` | Product management | No |
| `/rlg:k8s [agent]` | Kubernetes specialists | No |

**Smart Dispatch Example:**
```bash
# Working on React app
/rlg:dev
# → Auto-loads react-specialist

# Working on Python + Django
/rlg:dev
# → Auto-loads django-developer
```

**Kubernetes Specialists:**
```bash
/rlg:k8s architect      # Cluster design, platform engineering
/rlg:k8s helm           # Chart development, templating
/rlg:k8s gitops         # ArgoCD, Flux, progressive delivery
/rlg:k8s security       # Policies, RBAC, admission control
/rlg:k8s mesh           # Istio, Linkerd, Cilium
```

**Parallel Dispatch for Complex Tasks:**
```bash
# Load multiple agents in parallel for K8s migration
/rlg:k8s architect
/rlg:k8s security
/rlg:k8s gitops
```

### Plan Management

| Command | Description |
|---------|-------------|
| `/rlg:plan-new [name]` | Create chunked plan |
| `/rlg:plan-status [name]` | Show progress |
| `/rlg:plan-next` | Execute next chunk |
| `/rlg:plan-resume [name]` | Resume plan |
| `/rlg:plan-list` | List all plans |

## Smart Dispatch

The `/rlg:dev` command with no arguments analyzes your codebase and automatically loads relevant agents.

**Detection signals:**
- File extensions (`.py`, `.ts`, `.go`)
- Package files (`package.json`, `requirements.txt`)
- Import statements (`from django`, `import React`)
- Framework indicators (config files)

**Examples:**

| Your Code | Auto-Loaded Agent |
|-----------|-------------------|
| `*.py` + `django` imports | django-developer |
| `*.ts` + `package.json` with React | react-specialist |
| `*.go` + `go.mod` | golang-pro |
| `*.py` + `fastapi` imports | fastapi-developer |

## Context Management

**Budget:** 50000 tokens (configurable)
**Core:** 2300 tokens (always loaded)
**Available:** 47700 tokens for specialists

**Tracking:**
- Orchestrator monitors token usage
- Warns at 80% (40K tokens)
- Blocks at 90% (45K tokens)
- Auto-unloads idle agents (5 min default)

**Feedback:**
```
🔧 Loaded kubernetes-specialist (850 tokens)
Context: 3150/50000 tokens (6%)
```

## Workflows

### Feature Development

```bash
# 1. Setup
/rlg:worktree            # Isolated workspace

# 2. Design
/rlg:brainstorm          # Refine idea

# 3. Plan
/rlg:plan-new feature    # Create chunked plan

# 4. Implement
/rlg:plan-next           # Chunk 1: Setup
/rlg:plan-next           # Chunk 2: Implementation
/rlg:plan-next           # Chunk 3: Tests

# 5. Review
/rlg:review              # Code review

# 6. Finish
# Use superpowers:finishing-a-development-branch
```

### Bug Fixing

```bash
# 1. Debug
/rlg:debug               # Systematic debugging

# 2. Fix with TDD
/rlg:tdd                 # Write test first

# 3. Verify
/rlg:quality test        # Load test automator

# 4. Review
/rlg:review              # Final check
```

### Infrastructure Work

```bash
# Kubernetes deployment issue
/rlg:infra kubernetes    # Load specialist

# Terraform changes
/rlg:infra terraform     # Load engineer

# Incident response
/rlg:infra incident      # Load responder
```

## Configuration

Edit `manifest.json` to customize:

```json
{
  "settings": {
    "plansDirectory": ".claude/plans",
    "maxChunkSize": 10,
    "contextBudget": 50000,
    "contextWarningThreshold": 40000,
    "contextCriticalThreshold": 45000,
    "autoUnloadIdleTime": 300000,
    "strictTDD": false
  }
}
```

**Settings:**
- `plansDirectory`: Where to store plans
- `maxChunkSize`: Max tasks per chunk
- `contextBudget`: Total context limit
- `contextWarningThreshold`: Warn at this level
- `contextCriticalThreshold`: Block at this level
- `autoUnloadIdleTime`: Unload after ms idle
- `strictTDD`: Block or warn on TDD violations

## Best Practices

### Planning
- Break features into 5-10 task chunks
- Use natural breakpoints (setup, implementation, tests, docs)
- Track dependencies between chunks
- Pause/resume at chunk boundaries

### TDD
- Always write test first (RED)
- Verify test fails
- Write minimal implementation (GREEN)
- Refactor with confidence
- Commit frequently

### Context Management
- Let orchestrator manage loading/unloading
- Complete tasks before loading new agents
- Use chunked plans for large features
- Monitor context feedback

### Documentation
- Update docs alongside code
- Keep README current
- Document complex decisions
- Include usage examples

## Troubleshooting

**Context Budget Exceeded:**
```
❌ Cannot Load Agent
Current: 47000/50000 tokens (94%)

Actions:
- Complete current work
- Unload idle agents
- Increase contextBudget in settings
```

**Plan Not Found:**
```
Error: Plan metadata not found for 'feature-name'
Available plans: [use /rlg:plan-list]
```

**Agent Not Loading:**
- Check manifest.json for agent path
- Verify agent file exists
- Check for syntax errors in agent markdown

## Contributing

Contributions welcome! Areas for improvement:

- Additional specialized agents
- More workflow skills
- Command enhancements
- Documentation improvements
- Bug fixes

## License

MIT License - See LICENSE file

## Credits

Built on top of:
- **superpowers** - Workflow skills and patterns
- **claude-code-sub-agents** - Specialized agent library
- **awesome-claude-agents** - Agent templates
- **wshobson-agents** - Additional specialists

## Support

Issues: https://github.com/RLGeeX/rlg-cc-unleashed/issues

## Distribution

This plugin is available through multiple channels:

1. **Direct Installation**: `/plugin add github:RLGeeX/rlg-cc-unleashed`
2. **Marketplace**: `/plugin marketplace add RLGeeX/rlg-cc-unleashed`
3. **Community Marketplaces**: Submit PRs to:
   - [ingpoc/claude-code-plugins-marketplace](https://github.com/ingpoc/claude-code-plugins-marketplace)
   - [ccplugins/marketplace](https://github.com/ccplugins/marketplace)

**GitHub Topics**: Add these topics to the repository for discoverability:
- `claude-code`
- `claude-code-plugin`
- `ai-assistant`
- `productivity`
- `tdd`
- `agents`
