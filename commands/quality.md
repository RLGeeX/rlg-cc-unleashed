---
description: Load quality assurance specialist agent
---

# Quality Agent Dispatcher

Load a specialized quality agent for testing, review, and security tasks.

**Available Agents:**
- `review` - Code reviewer (agents/quality/code-reviewer.md)
- `test` - Test automation specialist (agents/quality/test-automator.md)
- `qa` - QA expert (agents/quality/qa-expert.md)
- `debug` - Debugger specialist (agents/quality/debugger.md)
- `refactor` - Refactoring expert (agents/quality/refactoring-specialist.md)
- `security` - Security auditor (agents/quality/security-auditor.md)

**Usage:**
- `/rlg-quality review` - Load code reviewer
- `/rlg-quality security` - Load security auditor
- `/rlg-quality` - Show available quality agents

If no agent is specified, present the list of available agents and ask the user which one to load.
