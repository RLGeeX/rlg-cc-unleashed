---
description: Convene an LLM Council for deliberative multi-model reasoning with peer review and chairman synthesis
allowed-tools: Bash, Read, AskUserQuestion
---

# LLM Council

Convene a council of AI models for deliberative reasoning. Uses 3-stage process: Query, Peer Review, Chairman Synthesis.

## IMPORTANT: How to Execute This Command

You orchestrate the council through the shell script and AskUserQuestion tool.

### Step 1: Get the Question

If the user provided a question with the command, use it. Otherwise, ask:
- What question should the council deliberate on?

### Step 2: Offer Configuration

Use AskUserQuestion to let user configure the council:

```
Question: "How would you like to configure the council?"
Options:
1. Use defaults (Recommended) - GPT-4o, Gemini 2.5 Flash, Grok 4, Claude Sonnet as chairman
2. Customize council - Select which models participate
3. Customize chairman - Choose who synthesizes the final answer
```

**If "Customize council" or "Customize chairman"**: First run discover to show available models:

```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/council/scripts/council.sh --discover --format table
```

Then use AskUserQuestion to let user pick from the discovered models.

### Step 3: Run the Council

**Default configuration:**
```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/council/scripts/council.sh \
  --question "USER'S QUESTION HERE"
```

**Custom council:**
```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/council/scripts/council.sh \
  --question "USER'S QUESTION" \
  --council "model1,model2,model3" \
  --chairman "chairman-model"
```

**With member count:**
```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/council/scripts/council.sh \
  --question "USER'S QUESTION" \
  --members 5
```

### Step 4: Present Results

The script outputs structured results. Summarize for the user:
1. **Key Consensus**: What the council agreed on
2. **Areas of Debate**: Where they differed
3. **Chairman's Recommendation**: The synthesized verdict

## Prerequisites

- `OPENROUTER_API_KEY` environment variable must be set
- `curl` and `jq` installed (standard on most systems)
- Optional: `~/.claude/config/council.json` for default configuration

## Good Questions for Council

- "Should we use GraphQL or REST for our new API?"
- "Monorepo vs polyrepo for 5 microservices?"
- "What's the best approach for implementing real-time updates?"
- "How should we structure our authentication layer?"

## When to Use Council vs Consensus

| Council | Consensus |
|---------|-----------|
| Complex decisions needing synthesis | Quick polls |
| Research requiring multiple perspectives | Simple A vs B |
| When peer review adds value | Fast answers needed |
