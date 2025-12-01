---
description: Query multiple AI models (GPT, Gemini, Grok) for consensus on a decision question
allowed-tools: Bash, AskUserQuestion
---

# Consensus Query

Query multiple AI models via OpenRouter to get diverse perspectives on a decision question.

## IMPORTANT: How to Execute This Command

You MUST run the consensus bash script directly. Do NOT dispatch a Task agent or make API calls manually.

### Step 1: Get the Question

If the user provided a question with the command, use it. Otherwise, ask:
- What specific technical decision do you need consensus on?

### Step 2: Run the Script

Execute this command with the user's question:

```bash
/home/jfogarty/git/rlgeex/rlg-cc/rlg-cc-unleashed/skills/consensus/scripts/consensus.sh "USER'S QUESTION HERE"
```

### Step 3: Present Results

After the script runs, summarize:
- **3/3 agree**: "Unanimous consensus for [X]"
- **2/3 agree**: "Majority (2-1) for [X], dissent: [Y]"
- **All differ**: "No consensus - GPT: [X], Gemini: [Y], Grok: [Z]"

## Prerequisites

- `OPENROUTER_API_KEY` environment variable must be set
- Configure models in `~/.claude/config/consensus.json`

## Good Questions

- "Should I use Redis or Memcached for session caching?"
- "PostgreSQL vs MySQL for time-series analytics?"
- "Monorepo or separate repos for 3 microservices?"

## Not Good For

- Broad design questions (use `/cc-unleashed:brainstorm`)
- Code generation
- Subjective preferences
