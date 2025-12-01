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

## Available Models on OpenRouter

### Defaults
- `openai/gpt-4o-mini` (default) - Fast, cost-effective GPT-4
- `google/gemini-2.5-flash` (default) - Latest Gemini Flash
- `x-ai/grok-4-fast` (default) - Fast Grok with 2M context

### OpenAI
- `openai/gpt-5.1` - Latest GPT-5 with adaptive reasoning
- `openai/gpt-5.1-codex` - Specialized for software engineering
- `openai/gpt-5.1-codex-mini` - Faster codex variant
- `openai/gpt-5-pro` - Most advanced reasoning
- `openai/gpt-5-mini` - Balanced GPT-5
- `openai/gpt-5-nano` - Lightweight GPT-5
- `openai/gpt-4o-mini` - Fast, cost-effective
- `openai/o3-deep-research` - Web search for research tasks
- `openai/o4-mini-deep-research` - Faster deep research

### Google
- `google/gemini-3-pro-preview` - NEW: 1M context, state-of-the-art
- `google/gemini-2.5-pro` - Full Gemini 2.5
- `google/gemini-2.5-flash` - Fast Gemini 2.5
- `google/gemini-2.5-flash-lite` - Lightweight, fastest

### xAI (Grok)
- `x-ai/grok-4.1-fast:free` - Free tier, 2M context
- `x-ai/grok-4-fast` - Fast with 2M context
- `x-ai/grok-4` - Full Grok 4

### Anthropic
- `anthropic/claude-opus-4.5` - Frontier reasoning
- `anthropic/claude-sonnet-4.5` - 1M context, >73% SWE-bench
- `anthropic/claude-haiku-4.5` - Fastest, most efficient

### Meta-Routing
- `openrouter/auto` - Auto-selects best model per request (see below)

## Using openrouter/auto

The `openrouter/auto` model is a meta-router that automatically selects the optimal model for each request. Useful for:

1. **Fallback** - If a specific model fails, auto can provide a backup response
2. **Wildcard opinion** - Add as a 4th model for an additional perspective
3. **Single-query mode** - When you just want the best answer, not consensus

Note: The response includes which model was actually selected, so you can verify diversity.

See https://openrouter.ai/models for full list and current pricing.
