---
name: consensus
description: Use when facing a decision question that would benefit from multiple AI perspectives - queries GPT, Gemini, and Grok via OpenRouter to provide consensus or highlight differing opinions. Not for brainstorming or fundamental design questions.
allowed-tools: Bash, Read, AskUserQuestion
---

# AI Consensus Query

Query multiple AI models (GPT-4, Gemini, Grok) via OpenRouter to get diverse perspectives on a technical decision.

## CRITICAL: Run the Bash Script

**DO NOT** dispatch a Task agent or make API calls manually.
**DO** run the consensus script directly using the Bash tool.

### Script Path

```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/consensus/scripts/consensus.sh
```

### Execution

```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/consensus/scripts/consensus.sh "YOUR QUESTION HERE"
```

## Process

### 1. Validate Question

Ensure the question is:
- **Specific** - Not vague or open-ended
- **Decision-focused** - Has clear alternatives
- **Technical** - Software engineering related

If vague, ask user to clarify before running.

### 2. Run Script

Execute with the Bash tool:
```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/consensus/scripts/consensus.sh "Should I use X or Y for Z?"
```

### 3. Summarize Results

After script completes, summarize:
- **3/3 agree**: "Unanimous consensus for [X]"
- **2/3 agree**: "Majority (2-1) for [X]. Dissent: [Y] because [reason]"
- **All differ**: "No consensus - present each perspective"

## When to Use

**Good for:**
- Library/framework selection
- Architecture pattern decisions
- Technology comparisons
- Best practice validation

**Not for:**
- Brainstorming (use `/cc-unleashed:brainstorm`)
- Code generation
- Debugging (use `/cc-unleashed:debug`)

## Prerequisites

- `OPENROUTER_API_KEY` environment variable
- Optional: `~/.claude/config/consensus.json` for model configuration

## Error Handling

- **Missing API key**: Tell user to set `OPENROUTER_API_KEY`
- **Models fail**: Script continues if 2+ succeed
- **All fail**: Check API key and provider access

---

## References

See `reference.md` for:
- Complete list of available OpenRouter models
- Default models used
- Configuration options
- Using openrouter/auto meta-router
