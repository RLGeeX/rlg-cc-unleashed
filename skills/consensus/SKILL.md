---
name: consensus
description: Use when facing a decision question that would benefit from multiple AI perspectives - queries GPT, Gemini, and Grok via OpenRouter to provide consensus or highlight differing opinions. Not for brainstorming or fundamental design questions.
allowed-tools: Bash, Read, AskUserQuestion
---

# AI Consensus Query

## Overview

Query multiple AI models (GPT-4, Gemini, Grok) simultaneously via OpenRouter API to get diverse perspectives on a decision question. This skill helps when you're uncertain about a technical choice and want to see if there's agreement across different AI systems.

## When to Use

**Good for:**
- Library/framework selection ("Should I use Redis or Memcached for caching?")
- Architecture pattern decisions ("REST vs GraphQL for this use case?")
- Best practice questions ("Is it better to use composition or inheritance here?")
- Technology comparisons ("PostgreSQL vs MySQL for time-series data?")
- Code approach validation ("Should I use async/await or callbacks?")

**Not good for:**
- Brainstorming / creative exploration (use `/cc-unleashed:brainstorm` instead)
- Fundamental design decisions (use brainstorming first, then consensus on specific choices)
- Code generation tasks
- Debugging (use `/cc-unleashed:debug`)
- Subjective preferences

## Prerequisites

1. **OpenRouter API Key**: Set the `OPENROUTER_API_KEY` environment variable
   ```bash
   export OPENROUTER_API_KEY="sk-or-your-key-here"
   ```

2. **Optional Configuration**: Create `~/.claude/config/consensus.json` to customize models:
   ```json
   {
     "models": [
       "openai/gpt-4o-mini",
       "google/gemini-2.5-flash",
       "x-ai/grok-4-fast"
     ],
     "max_tokens": 500,
     "timeout_seconds": 60
   }
   ```

3. **Optional Environment Overrides**:
   ```bash
   export CONSENSUS_MODEL_1="openai/gpt-5.1"
   export CONSENSUS_MODEL_2="google/gemini-2.5-pro"
   export CONSENSUS_MODEL_3="anthropic/claude-sonnet-4.5"
   ```

## Process

### Step 1: Validate the Question

Before running consensus, ensure the question is:
- **Specific** - Not vague or open-ended
- **Decision-focused** - Has clear alternatives to compare
- **Technical** - Related to software engineering choices

If the question is vague, use AskUserQuestion to clarify:
```
AskUserQuestion:
{
  "question": "Your question seems broad. Which specific aspect do you want consensus on?",
  "header": "Focus",
  "multiSelect": false,
  "options": [
    {"label": "Performance", "description": "Which option performs better?"},
    {"label": "Maintainability", "description": "Which is easier to maintain?"},
    {"label": "Ecosystem", "description": "Which has better tooling/community?"},
    {"label": "Scalability", "description": "Which scales better?"}
  ]
}
```

### Step 2: Run Consensus Query

Find the consensus script in this skill's directory and execute it:

```bash
# Find the skill directory (check common locations)
SKILL_DIR=""
for dir in \
    "$HOME/.claude/skills/consensus" \
    ".claude/skills/consensus" \
    "$(dirname "$(find . -name 'consensus' -type d -path '*/skills/*' 2>/dev/null | head -1)")/consensus" \
    "/home/jfogarty/git/rlgeex/rlg-cc/rlg-cc-unleashed/skills/consensus"; do
    if [[ -f "$dir/scripts/consensus.sh" ]]; then
        SKILL_DIR="$dir"
        break
    fi
done

if [[ -z "$SKILL_DIR" ]]; then
    echo "ERROR: Could not find consensus skill directory"
    exit 1
fi

"$SKILL_DIR/scripts/consensus.sh" "YOUR QUESTION HERE"
```

### Step 3: Interpret Results

The script outputs:
1. **Individual responses** from each model with:
   - RECOMMENDATION: Their specific answer
   - CONFIDENCE: high/medium/low
   - REASONING: Brief explanation

2. **Summary** showing successful vs failed queries

### Step 4: Present to User

After running the consensus query, present findings using AskUserQuestion:

**If 3/3 agree (consensus):**
```
AskUserQuestion:
{
  "question": "All three AI models recommend [X]. Would you like to proceed with this approach?",
  "header": "Consensus",
  "multiSelect": false,
  "options": [
    {"label": "Yes, proceed", "description": "Accept the consensus recommendation"},
    {"label": "More details", "description": "Show full reasoning from each model"},
    {"label": "Different question", "description": "Rephrase and query again"}
  ]
}
```

**If 2/3 agree (majority):**
```
AskUserQuestion:
{
  "question": "[Model1] and [Model2] recommend [X], but [Model3] suggests [Y] because [reason]. Which approach?",
  "header": "Split Opinion",
  "multiSelect": false,
  "options": [
    {"label": "[X] (majority)", "description": "Go with the 2/3 recommendation"},
    {"label": "[Y] (dissent)", "description": "The dissenting view has merit"},
    {"label": "Need more info", "description": "Explore the disagreement further"}
  ]
}
```

**If all disagree:**
```
AskUserQuestion:
{
  "question": "Models disagree: GPT suggests [X], Gemini suggests [Y], Grok suggests [Z]. This might need more context.",
  "header": "No Consensus",
  "multiSelect": false,
  "options": [
    {"label": "Refine question", "description": "Add more context and try again"},
    {"label": "Brainstorm instead", "description": "Switch to collaborative brainstorming"},
    {"label": "User decides", "description": "Review reasoning and decide yourself"}
  ]
}
```

## Error Handling

**If OPENROUTER_API_KEY is missing:**
- Inform user they need to set the environment variable
- Provide instructions for obtaining a key at https://openrouter.ai

**If models fail:**
- Script continues with remaining models if at least 2 succeed
- If <2 succeed, inform user and suggest checking API key or trying later

**If jq is not installed:**
- Script will use defaults instead of config file
- Recommend installing jq for config file support

## Cost Awareness

Each consensus query makes 3 API calls to OpenRouter. Approximate costs (as of 2024):
- GPT-4o: ~$0.01-0.03 per query
- Gemini Pro: ~$0.005-0.01 per query
- Grok: ~$0.01-0.02 per query

Total: ~$0.025-0.06 per consensus query

Use judiciously for meaningful decisions, not trivial questions.

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
