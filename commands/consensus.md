---
description: Query multiple AI models (GPT, Gemini, Grok) for consensus on a decision question
---

# Consensus Query

Load the consensus skill to query multiple AI models via OpenRouter and compare their recommendations.

## What This Does

Sends your question to 3 different AI models simultaneously:
- GPT-4 (OpenAI)
- Gemini Pro (Google)
- Grok (xAI)

Then presents you with either:
- **Consensus** (3/3 agree) - Clear recommendation
- **Majority** (2/3 agree) - Recommendation with noted dissent
- **Split** (all differ) - Multiple perspectives to consider

## Prerequisites

You must have `OPENROUTER_API_KEY` set in your environment:
```bash
export OPENROUTER_API_KEY="sk-or-your-key-here"
```

Get a key at https://openrouter.ai

## Usage

After invoking `/cc-unleashed:consensus`, provide your decision question. Good questions are:
- Specific and technical
- Have clear alternatives to compare
- Not open-ended brainstorming

**Good examples:**
- "Should I use Redis or Memcached for session caching in a Node.js app?"
- "PostgreSQL vs MySQL for a time-series analytics workload?"
- "Is it better to use a monorepo or separate repos for 3 microservices?"

**Better handled by brainstorming:**
- "How should I architect my application?" (too broad)
- "What features should I add?" (creative/exploratory)

## Cost

Each query costs approximately $0.03-0.06 (3 API calls). Use for meaningful decisions.

---

Use the `consensus` skill to handle this request.
