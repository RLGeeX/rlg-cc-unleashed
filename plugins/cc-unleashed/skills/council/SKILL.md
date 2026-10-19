---
name: council
description: Convene an LLM Council for deliberative multi-model reasoning. Uses 3-stage process (Query, Peer Review, Chairman Synthesis) for deeper analysis than simple consensus polling. Use when a question needs rigorous multi-model deliberation with peer review, or say "convene council", "council review", or "LLM council".
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
1. Use defaults (Recommended) - GPT-6.1 Sol, Gemini 4 Argon, Grok 4.7, Claude Opus 5.5 as chairman
2. Deep council - 5 members (adds Kimi K3 and GLM-5.3), Claude Opus 5.5 chairman
3. Customize council members - Select which models participate
4. Customize chairman - Choose who synthesizes the final answer
```

**For the "Deep council" option, invoke with `-n 5`** — the chairman already defaults to `anthropic/claude-opus-5.5`, and the script auto-selects one model per non-Anthropic provider in `PROVIDER_ORDER`, giving cross-architecture diversity with Opus synthesizing. Or pin the roster via `council-5-opus.json.example`. `-n 6` seats every non-Anthropic provider (adds DeepSeek V4 Pro) for foundational decisions where breadth beats cost.

**If user selects "Customize council members" or "Customize chairman":**

First, fetch available models from OpenRouter:

```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/plugins/cc-unleashed/skills/council/scripts/council.sh --discover --format table
```

This returns models from major providers (OpenAI, Anthropic, Google, xAI, DeepSeek, Moonshot, Z.ai) with context length and pricing.

Then use AskUserQuestion to let them pick from the available models:
- For council: Pick 3-5 models (recommend diversity across providers)
- For chairman: Pick one model (Claude or GPT recommended for synthesis)

### Step 3: Run Council Script

Execute the shell script with configuration:

```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/plugins/cc-unleashed/skills/council/scripts/council.sh \
  --question "USER'S QUESTION" \
  --council "model1,model2,model3" \
  --chairman "chairman-model"
```

**Default invocation:**
```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/plugins/cc-unleashed/skills/council/scripts/council.sh \
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
- `curl` and `jq` installed (standard on most systems)
- Optional: `~/.claude/config/council.json` for default configuration

## Error Handling

- **Missing API key**: Tell user to set `OPENROUTER_API_KEY`
- **Model failures**: Script continues if 2+ council members succeed. A member that spends its whole budget reasoning is reported as `Truncated`, and a partly cut-off answer is tagged `[TRUNCATED]` so reviewers and the chairman discount it
- **Timeouts**: reported as `Timed out after Ns`; long questions can take a reasoning model 2+ minutes
- **Missing curl/jq**: Tell user to install these tools

## Configuration File

Optional `~/.claude/config/council.json`:

```json
{
  "council": [
    "openai/gpt-6.1-sol",
    "google/gemini-4-argon",
    "x-ai/grok-4.7"
  ],
  "chairman": "anthropic/claude-opus-5.5",
  "max_tokens": 8000,
  "reasoning_effort": "medium",
  "timeout_seconds": 240
}
```

---

## Model Discovery

To see all available models from major providers:

```bash
# JSON format (for parsing)
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/plugins/cc-unleashed/skills/council/scripts/council.sh --discover

# Human-readable table
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/plugins/cc-unleashed/skills/council/scripts/council.sh --discover --format table
```

**Major providers included:** OpenAI, Anthropic, Google, xAI, DeepSeek, Moonshot, Z.ai

---

## References

See `reference.md` for:
- Default council and chairman configuration
- Recommended council compositions
- Prompt templates for each stage
