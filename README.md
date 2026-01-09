# CC Unleashed

Streamlined Claude Code plugin with workflow automation, chunked planning, Jira integration, and integration with 61 specialized agents.

**Version:** 1.4.0
**Author:** RLGeeX
**Requires:** Claude Code >=2.0.31

## Overview

CC Unleashed provides workflow automation and planning tools that integrate seamlessly with 61 specialized agents:

- **Workflow automation**: TDD, debugging, code review, git worktrees, brainstorming
- **Chunked planning**: Break down large features into manageable chunks with autonomous execution
- **Jira integration**: Automatic issue creation and status tracking throughout plan execution
- **Multi-AI consensus**: Query GPT, Gemini, and Grok for quick decision validation
- **LLM Council**: 3-stage deliberative reasoning with peer review and chairman synthesis
- **FPF reasoning**: Evidence-based architectural decisions via Quint Code integration
- **D3 workflow**: Discover-Decide-Design for rigorous multi-decision planning

## Installation

**Step 1:** Add the marketplace:
```
/plugin marketplace add RLGeeX/rlg-cc-unleashed
```

**Step 2:** Install the plugin:
```
/plugin install cc-unleashed@RLGeeX
```

Or use the interactive menu: `/plugin` → Browse Plugins → cc-unleashed

**Verify installation:**
```
/cc-unleashed:plan-list
```

### Agents (Optional)

For the 61 specialized agents, see [rlg-cc-subagents](https://github.com/RLGeeX/rlg-cc-subagents).

## Quick Start

**Start a new feature with autonomous execution:**
```
/cc-unleashed:worktree           # Create isolated workspace
/cc-unleashed:brainstorm         # Design your feature
/cc-unleashed:plan-new my-feature  # Create chunked plan
/cc-unleashed:plan-execute       # Execute all chunks automatically
```

**Or execute chunks manually:**
```
/cc-unleashed:plan-new my-feature  # Create chunked plan
/cc-unleashed:plan-next          # Execute next chunk
/cc-unleashed:plan-status        # Check progress
```

**Work with specialized agents:**
```
@python-pro                      # Load Python specialist
@terraform-specialist            # Load Terraform specialist
@security-auditor               # Load security auditor
```

## Plugin Components

### Skills (27 total)

| Category | Skills |
|----------|--------|
| Workflow (14) | TDD, debugging, code review, brainstorming, git worktrees, verification, parallel agents, etc. |
| Planning (7) | write-plan, execute-plan, plan-manager, autonomous-execute, jira-plan, fpf-reasoning, discover-decide-design |
| Kubernetes (4) | gitops-workflow, helm-chart-scaffolding, k8s-manifest-generator, k8s-security-policies |
| Decision Support (1) | council (3-stage deliberative reasoning with peer review) |
| Content (1) | hugo-story |

### Commands (16 total)

| Category | Commands |
|----------|----------|
| Workflow | `/tdd`, `/debug`, `/review`, `/brainstorm`, `/worktree` |
| Planning | `/plan-new`, `/plan-status`, `/plan-execute`, `/plan-next`, `/plan-resume`, `/plan-list` |
| Integration | `/jira-plan`, `/consensus`, `/council`, `/hugo-story`, `/d3` |

All commands use the `/cc-unleashed:` prefix.

### Specialized Agents (61 total, installed separately)

| Category | Count | Examples |
|----------|-------|----------|
| Infrastructure | 13 | terraform-specialist, cloud-architect, devops-engineer, sre-engineer |
| Development | 18 | python-pro, react-specialist, fastapi-pro, backend-architect |
| Quality | 11 | code-reviewer, test-automator, debugger, security-auditor |
| Kubernetes | 4 | k8s-architect, helm-specialist, gitops-engineer |
| Product Management | 7 | product-manager, scrum-master, jira-specialist |
| Creative | 3 | ghost-writer, copy-editor, content-reviewer |
| AI/ML | 2 | langgraph-specialist, vector-search-specialist |
| Business | 1 | financial-data-analyst |

## Chunked Planning System

Traditional plans put all tasks in one file, bloating context. CC Unleashed breaks plans into digestible chunks:

```
.claude/plans/my-feature/
├── plan-meta.json       # Feature metadata
├── chunk-001.md         # Setup (2-3 tasks)
├── chunk-002.md         # Implementation (2-3 tasks)
├── chunk-003.md         # Testing (2-3 tasks)
└── chunk-004.md         # Documentation (2-3 tasks)
```

**Benefits:**
- Only 1 chunk (~300-500 tokens) loaded at a time
- Clear progress tracking with story points
- Automatic Jira integration
- Pause/resume friendly
- Code review after each chunk

### Execution Modes

| Mode | Command | Description |
|------|---------|-------------|
| Autonomous | `/plan-execute` | Execute all chunks automatically with subagents |
| Manual | `/plan-next` | Execute one chunk at a time with control |
| Supervised | (via execute-plan) | Human review after each task |

## Workflows

### Feature Development
```
/cc-unleashed:worktree            # Isolated workspace
/cc-unleashed:brainstorm          # Refine idea
/cc-unleashed:plan-new feature    # Create chunked plan
/cc-unleashed:plan-execute        # Execute automatically
```

### Rigorous Planning (D3)
```
/cc-unleashed:d3                  # Discover-Decide-Design workflow
```
D3 automatically validates decisions through consensus queries and FPF reasoning before producing a design.

### Bug Fixing
```
/cc-unleashed:debug               # Systematic debugging
/cc-unleashed:tdd                 # Write test first, then fix
```

## Configuration

Edit `manifest.json` to customize:

```json
{
  "settings": {
    "plansDirectory": ".claude/plans",
    "maxChunkSize": 10,
    "strictTDD": false
  }
}
```

## Troubleshooting

**Command Not Found:**
- Run `/plugin update` to reload
- Verify with `/cc-unleashed:plan-list`

**Agent Not Available:**
- See [rlg-cc-subagents](https://github.com/RLGeeX/rlg-cc-subagents) for installation
- Check agent name with `@` autocomplete

**Plan Not Found:**
- Use `/cc-unleashed:plan-list` to see available plans

## License

MIT License

## Support

Issues: https://github.com/RLGeeX/rlg-cc-unleashed/issues
