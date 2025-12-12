# CC Unleashed

Streamlined Claude Code plugin with workflow automation, chunked planning, Jira integration, and integration with 62 specialized agents.

**Version:** 1.1.0
**Author:** RLGeeX
**Requires:** Claude Code >=2.0.31

## Overview

CC Unleashed provides workflow automation and planning tools that integrate seamlessly with 62 specialized agents:

- **Workflow automation**: TDD, debugging, code review, git worktrees, brainstorming
- **Chunked planning**: Break down large features into manageable chunks with autonomous execution
- **Jira integration**: Automatic issue creation and status tracking throughout plan execution
- **Agent integration**: Works with separately-installed agents (62 specialists with full MCP tool access)
- **Clean separation**: 14 slash commands, agents invoked with `@agent-name`
- **Comprehensive coverage**: Infrastructure, Development, Quality, Product Management, K8s, AI/ML

## Quick Start

### Installation

Choose one of the following methods:

#### Method 1: Marketplace Installation (Recommended)

```bash
/plugin marketplace add RLGeeX/rlg-cc-unleashed
```

#### Method 2: Manual Installation

```bash
git clone https://github.com/RLGeeX/rlg-cc-unleashed ~/.claude/plugins/rlg-cc-unleashed
```

After installation, restart Claude Code or reload plugins, then verify:

```bash
/cc-unleashed:plan-list
```

### First Steps

**Start a new feature with autonomous execution:**
```
/cc-unleashed:worktree           # Create isolated workspace
/cc-unleashed:brainstorm         # Design your feature
/cc-unleashed:plan-new my-feature  # Create chunked plan
/cc-unleashed:plan-execute       # Execute all chunks automatically
```

**Or execute chunks manually:**
```
/cc-unleashed:worktree           # Create isolated workspace
/cc-unleashed:brainstorm         # Design your feature
/cc-unleashed:plan-new my-feature  # Create chunked plan
/cc-unleashed:plan-next          # Start first chunk with TDD
```

**Work with specialized agents:**
```
@python-pro                      # Load Python specialist
@terraform-specialist            # Load Terraform specialist
@security-auditor               # Load security auditor
```

## Architecture

### Plugin Components

The cc-unleashed plugin provides:

**24 Workflow Skills**
- TDD, debugging, code review, git workflows, brainstorming
- Chunked planning system (write-plan, execute-plan, plan-manager, autonomous-execute)
- Kubernetes workflows (GitOps, Helm scaffolding, manifest generation, security policies)
- Jira integration (jira-plan), Hugo story generation, multi-AI consensus

**14 Slash Commands**
- Workflow triggers: `/cc-unleashed:tdd`, `/cc-unleashed:debug`, `/cc-unleashed:review`, `/cc-unleashed:brainstorm`, `/cc-unleashed:worktree`
- Plan management: `/cc-unleashed:plan-new`, `/cc-unleashed:plan-status`, `/cc-unleashed:plan-execute`, `/cc-unleashed:plan-next`, `/cc-unleashed:plan-resume`, `/cc-unleashed:plan-list`
- Content creation: `/cc-unleashed:hugo-story`, `/cc-unleashed:consensus`

### Specialized Agents (Installed Separately)

The cc-unleashed ecosystem includes 62 specialized agents installed via the separate [rlg-cc-subagents](https://github.com/rlgeex/rlg-cc-subagents) repository. Invoke with `@agent-name`:

#### Infrastructure (13 agents)
`@terraform-specialist`, `@cloud-architect`, `@devops-engineer`, `@deployment-engineer`, `@sre-engineer`, `@incident-responder`, `@database-administrator`, `@security-engineer`, `@gcp-serverless-specialist`, `@aws-amplify-gen2-specialist`, `@aws-lambda-specialist`, `@dynamodb-specialist`, `@enterprise-sso-specialist`

#### Development (18 agents)
`@python-pro`, `@typescript-pro`, `@react-specialist`, `@nextjs-specialist`, `@fastapi-pro`, `@backend-architect`, `@frontend-developer`, `@fullstack-developer`, `@api-architect`, `@microservices-architect`, `@dotnet-core-expert`, `@csharp-developer`, `@postgres-pro`, `@ui-designer`, `@slack-integration-specialist`, `@material-ui-specialist`, `@graphql-specialist`, `@data-visualization-specialist`

#### Quality (11 agents)
`@code-reviewer`, `@architect-reviewer`, `@test-automator`, `@qa-expert`, `@debugger`, `@security-auditor`, `@build-engineer`, `@git-workflow-manager`, `@dependency-manager`, `@chaos-engineer`, `@playwright-specialist`

#### Kubernetes (4 agents)
`@k8s-architect`, `@helm-specialist`, `@gitops-engineer`, `@k8s-security`

#### Product Management (7 agents)
`@product-manager`, `@scrum-master`, `@business-analyst`, `@technical-writer`, `@documentation-engineer`, `@jira-specialist`, `@story-writer`

#### Creative (3 agents)
`@ghost-writer`, `@copy-editor`, `@content-reviewer`

#### AI/ML (2 agents)
`@langgraph-specialist`, `@vector-search-specialist`

#### Business (1 agent)
`@financial-data-analyst`

**Installation:**
```bash
# Install agents separately
git clone https://github.com/rlgeex/rlg-cc-subagents ~/.claude/agents/cc-unleashed
```

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
/cc-unleashed:plan-new feature-name
```

This will:
1. Use brainstorming to understand the feature
2. Break it into logical chunks (5-10 tasks each)
3. Save to `.claude/plans/feature-name/`
4. Offer to start execution

### Executing Plans

**Autonomous Execution (Fastest):**
```bash
/cc-unleashed:plan-execute    # Execute all chunks automatically
```

Autonomous flow:
1. Confirms with user before starting
2. Executes all remaining chunks with subagents
3. Code review after each chunk
4. Progress updates between chunks
5. Stops on errors or test failures
6. Comprehensive summary at end

**Manual Execution (More Control):**
```bash
/cc-unleashed:plan-next    # Execute next chunk (or resume current)
```

Manual flow:
1. Load current chunk
2. Execute tasks in batches (default 3)
3. Report and get feedback
4. Continue until chunk complete
5. Move to next chunk

### Managing Plans

```bash
/cc-unleashed:plan-list                 # List all plans
/cc-unleashed:plan-status               # Show current progress
/cc-unleashed:plan-status feature-name  # Check specific plan
/cc-unleashed:plan-resume feature-name  # Resume interrupted plan
```

## Commands Reference

All commands use the `/cc-unleashed:` prefix. The plugin provides 14 slash commands:

### Workflow Triggers

| Command | Description | Loads |
|---------|-------------|-------|
| `/cc-unleashed:tdd` | Start TDD workflow | test-driven-development skill |
| `/cc-unleashed:debug` | Launch debugging | systematic-debugging skill |
| `/cc-unleashed:review` | Request code review | code-reviewer agent |
| `/cc-unleashed:brainstorm` | Design session | brainstorming skill |
| `/cc-unleashed:worktree` | Create worktree | using-git-worktrees skill |

### Plan Management

| Command | Description |
|---------|-------------|
| `/cc-unleashed:plan-new [name]` | Create chunked plan |
| `/cc-unleashed:plan-status [name]` | Show progress |
| `/cc-unleashed:plan-execute` | Execute all chunks automatically |
| `/cc-unleashed:plan-next` | Execute next chunk manually |
| `/cc-unleashed:plan-resume [name]` | Resume plan |
| `/cc-unleashed:plan-list` | List all plans |

### Agent Invocation

For specialized help, invoke agents directly:

```bash
@python-pro              # Python specialist
@terraform-specialist    # Infrastructure
@code-reviewer          # Quality assurance
@k8s-architect          # Kubernetes
```

**Agent discovery:** Type `@` and start typing to see autocomplete suggestions, or let Claude automatically delegate based on your code context.

## Workflows

### Feature Development

```bash
# 1. Setup
/cc-unleashed:worktree            # Isolated workspace

# 2. Design
/cc-unleashed:brainstorm          # Refine idea

# 3. Plan
/cc-unleashed:plan-new feature    # Create chunked plan

# 4. Implement
/cc-unleashed:plan-next           # Chunk 1: Setup
/cc-unleashed:plan-next           # Chunk 2: Implementation
/cc-unleashed:plan-next           # Chunk 3: Tests

# 5. Review
/cc-unleashed:review              # Code review

# 6. Finish
# Use superpowers:finishing-a-development-branch
```

### Bug Fixing

```bash
# 1. Debug
/cc-unleashed:debug               # Systematic debugging

# 2. Fix with TDD
/cc-unleashed:tdd                 # Write test first

# 3. Verify
@test-automator                   # Load test automator

# 4. Review
/cc-unleashed:review              # Final check
```

### Infrastructure Work

```bash
# Terraform changes
@terraform-specialist             # Load Terraform specialist

# Kubernetes work
@k8s-architect                    # Load K8s architect

# Incident response
@incident-responder               # Load incident responder
```

## Configuration

Edit `manifest.json` to customize planning settings:

```json
{
  "settings": {
    "plansDirectory": ".claude/plans",
    "maxChunkSize": 10,
    "strictTDD": false
  }
}
```

**Settings:**
- `plansDirectory`: Where to store chunked plans (default: `.claude/plans`)
- `maxChunkSize`: Maximum tasks per plan chunk (default: 10)
- `strictTDD`: Enforce strict TDD workflow (default: false)

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

### Agent Usage
- Use `@agent-name` for direct invocation
- Let Claude auto-delegate based on context
- Combine multiple agents for complex tasks
- Check agent descriptions for capabilities

### Documentation
- Update docs alongside code
- Keep README current
- Document complex decisions
- Include usage examples

## Troubleshooting

**Plan Not Found:**
```
Error: Plan metadata not found for 'feature-name'
Available plans: [use /cc-unleashed:plan-list]
```

**Command Not Found:**
- Run `/plugin update` to reload the plugin
- Check that you're using `/cc-unleashed:` prefix
- Verify installation with `/cc-unleashed:plan-list`

**Agent Not Available:**
- Ensure agents repository is installed: `~/.claude/agents/cc-unleashed/`
- Check agent name with `@` autocomplete
- See available agents in [rlg-cc-subagents](https://github.com/rlgeex/rlg-cc-subagents)

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

1. **Marketplace**: `/plugin marketplace add RLGeeX/rlg-cc-unleashed`
2. **Manual Installation**: `git clone https://github.com/RLGeeX/rlg-cc-unleashed ~/.claude/plugins/rlg-cc-unleashed`
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
