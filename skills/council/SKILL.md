---
name: council
description: Convene an LLM Council for deliberative multi-model reasoning. Uses 3-stage process (Query, Peer Review, Chairman Synthesis) for deeper analysis than simple consensus polling.
allowed-tools: Bash, Read, AskUserQuestion
---

# LLM Council

Convene a council of AI models for deliberative reasoning on technical decisions or research synthesis. Based on Karpathy's LLM Council concept.

## Overview

The council uses a 3-stage process:
1. **Query**: Each council member responds independently
2. **Peer Review**: Members review anonymized responses (Response A, B, C)
3. **Synthesis**: Chairman combines insights into final recommendation

## Process

### Step 1: Validate Question

Ensure the question is appropriate for council deliberation:
- **Technical decisions**: Architecture, library selection, design patterns
- **Research synthesis**: Gathering perspectives on a technical topic
- **Complex trade-offs**: Questions with multiple valid approaches

If too simple, suggest `/cc-unleashed:consensus` instead.

### Step 2: Offer Configuration

Use AskUserQuestion to let user customize (or accept defaults):

```
Question: "How would you like to configure the council?"
Options:
1. Use defaults (Recommended) - GPT-4o, Gemini 2.5 Flash, Grok 4, Claude Sonnet as chairman
2. Customize council members - Select which models participate
3. Customize chairman - Choose who synthesizes the final answer
```

**If user selects "Customize council members" or "Customize chairman":**

First, fetch available models from OpenRouter:

```bash
python3 $HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/council/scripts/council.py --discover --format table
```

This returns models from major providers (OpenAI, Anthropic, Google, xAI, Meta, Mistral) with context length and pricing.

Then use AskUserQuestion to let them pick from the available models:
- For council: Pick 3-5 models (recommend diversity across providers)
- For chairman: Pick one model (Claude or GPT recommended for synthesis)

### Step 3: Run Council Script

Execute the Python script with configuration:

```bash
python3 $HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/council/scripts/council.py \
  --question "USER'S QUESTION" \
  --council "model1,model2,model3" \
  --chairman "chairman-model"
```

**Default invocation:**
```bash
python3 $HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/council/scripts/council.py \
  --question "USER'S QUESTION"
```

### Step 4: Present Results

The script outputs structured results. Present to user:

1. **Individual Perspectives** (Stage 1 summary)
2. **Peer Review Highlights** (Stage 2 - key agreements/disagreements)
3. **Chairman's Synthesis** (Stage 3 - final recommendation)

## When to Use Council vs Consensus

| Use Council | Use Consensus |
|-------------|---------------|
| Complex architectural decisions | Quick library comparisons |
| Research requiring synthesis | Simple A vs B choices |
| Questions with nuanced trade-offs | Best practice validation |
| When you want deeper deliberation | When you need a fast answer |

## Prerequisites

- `OPENROUTER_API_KEY` environment variable
- Python 3.8+ with `httpx` installed
- Optional: `~/.claude/config/council.json` for default configuration

## Error Handling

- **Missing API key**: Tell user to set `OPENROUTER_API_KEY`
- **Model failures**: Script continues if 2+ council members succeed
- **Python not available**: Check Python installation

## Configuration File

Optional `~/.claude/config/council.json`:

```json
{
  "council": [
    "openai/gpt-4o",
    "google/gemini-2.5-flash",
    "x-ai/grok-4-fast"
  ],
  "chairman": "anthropic/claude-sonnet-4",
  "max_tokens": 1000,
  "timeout_seconds": 90
}
```

---

## Model Discovery

To see all available models from major providers:

```bash
# JSON format (for parsing)
python3 $HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/council/scripts/council.py --discover

# Human-readable table
python3 $HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/council/scripts/council.py --discover --format table
```

**Major providers included:** OpenAI, Anthropic, Google, xAI, Meta, Mistral

---

## References

See `reference.md` for:
- Default council and chairman configuration
- Recommended council compositions
- Prompt templates for each stage
