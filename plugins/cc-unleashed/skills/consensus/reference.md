# Consensus - Reference Documentation

Available OpenRouter models and configuration details.

## Table of Contents

1. [Available Models](#available-models)
2. [Configuration](#configuration)
3. [Using openrouter/auto](#using-openrouterauto)

---

## Available Models

### Default Models

Verified against the OpenRouter catalog on 2026-10-19. Prices are $ per million
tokens, prompt → completion. Re-check with `council.sh --discover --format table`
rather than trusting this table indefinitely.

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `openai/gpt-6-luna` | 0.10 → 0.50 | Fast, cost-efficient GPT-6 tier |
| `google/gemini-3.8-flash` | 0.83 → 4.13 | Strongest Flash; a clear step up from Flash-Lite |
| `x-ai/grok-4.3` | 1.25 → 2.50 | Reliable and fast; still well under a cent per query |

### Budget, Reasoning Cap, Timeout

Every current model emits hidden reasoning tokens that count against `max_tokens`.
Requests send `max_tokens: 4000` with OpenRouter `reasoning: {"effort": "low"}` and a
120s timeout. A member that spends the whole budget thinking is reported as
`Truncated`; a cut-off answer is tagged `[TRUNCATED]`.

### Replay Results (2026-10-19)

Five real consensus questions from Claude Code history (160–530 words), replayed
with the consensus prompt. "ok" means the model finished with a real answer.

| Model | 1500 tokens, no cap | 4000 + effort low |
|-------|--------------------:|------------------:|
| openai/gpt-6-luna | 4/5 | 5/5 |
| google/gemini-3.8-flash | 5/5 | 5/5 |
| x-ai/grok-4.3 | 5/5 | 5/5 |
| google/gemini-3.5-flash-lite | 5/5 | 5/5 |
| deepseek/deepseek-v4.1-flash | 1/5 | 4/5 |
| qwen/qwen3.8-flash | 1/5 | 3/5 |

`deepseek-v4.1-flash` was briefly the slot-3 default and was reverted to
`grok-4.3` on this evidence. `gemini-3.5-flash-lite` is the safe cheaper swap.

### OpenAI Models

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `openai/gpt-6-astra` | 10 → 50 | Flagship, complex reasoning |
| `openai/gpt-6.1-sol` | 2 → 10 | Mid tier (council default) |
| `openai/gpt-6-luna` | 0.10 → 0.50 | Cost-efficient tier (consensus default) |

### Google Models

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `google/gemini-4-argon` | 2 → 10 | Flagship reasoning (council default) |
| `google/gemini-3.8-flash` | 0.83 → 4.13 | Current Flash (consensus default) |
| `google/gemini-3.5-flash-lite` | 0.30 → 2.50 | Cheapest Google option |

`google/gemini-2.5-*` models expire on OpenRouter on 2026-10-20 — do not pin them.

### xAI (Grok) Models

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `x-ai/grok-4.7` | 2 → 6 | Current frontier Grok (council default) |
| `x-ai/grok-4.3` | 1.25 → 2.50 | Fast, reliable tier (consensus default) |

### Anthropic Models

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `anthropic/claude-opus-5.5` | 4 → 20 | Frontier reasoning (council chairman default) |
| `anthropic/claude-sonnet-5.5` | 2 → 10 | Balanced, strong synthesis |
| `anthropic/claude-haiku-5.5` | 0.10 → 0.50 | Fastest, most efficient |

### Open-Weight Models

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `deepseek/deepseek-v4-pro-0813` | 0.66 → 1.98 | Strong reasoning, very cheap |
| `moonshotai/kimi-k3` | 0.24 → 11.94 | 2.8T open-weight reasoning |
| `z-ai/glm-5.3` | 0.08 → 1.40 | 1M-context reasoning |

Not recommended: `deepseek-v4.1-flash` and `qwen3.8-flash` truncate on long
questions (above); `mistral-large-4-0` and `qwen3.8-max` truncate or run slow (see the
council reference).

### Meta-Routing

| Model | Description |
|-------|-------------|
| `openrouter/auto` | Auto-selects best model per request |

---

## Configuration

### Environment Variable

```bash
export OPENROUTER_API_KEY="your-api-key"
```

### Optional Config File

`~/.claude/config/consensus.json`:

```json
{
  "models": [
    "openai/gpt-6-luna",
    "google/gemini-3.8-flash",
    "x-ai/grok-4.3"
  ],
  "max_tokens": 4000,
  "reasoning_effort": "low",
  "timeout_seconds": 120
}
```

---

## Using openrouter/auto

The `openrouter/auto` model is a meta-router that automatically selects the optimal model for each request.

**Useful for:**
1. **Fallback** - If a specific model fails, auto can provide a backup response
2. **Wildcard opinion** - Add as a 4th model for an additional perspective
3. **Single-query mode** - When you just want the best answer, not consensus

**Note:** The response includes which model was actually selected, so you can verify diversity.

See https://openrouter.ai/models for full list and current pricing.
