# Consensus - Reference Documentation

Available OpenRouter models and configuration details.

## Table of Contents

1. [Available Models](#available-models)
2. [Configuration](#configuration)
3. [Using openrouter/auto](#using-openrouterauto)

---

## Available Models

### Default Models

Verified against the OpenRouter catalog on 2026-08-10. Prices are $ per million
tokens, prompt → completion. Re-check with `council.sh --discover --format table`
rather than trusting this table indefinitely.

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `openai/gpt-5.6-luna` | 0.10 → 0.60 | Cheapest current GPT tier; fast and capable |
| `google/gemini-3.5-flash-lite` | 0.30 → 2.50 | Lightweight, fastest Gemini |
| `x-ai/grok-4.3` | 1.25 → 2.50 | Cheapest current Grok, 1M context |

> **Note:** essentially every current model emits hidden reasoning tokens that count
> against `max_tokens`. The old 500-token budget could hit `finish_reason=length` and
> return empty output, which is why this used to pin `openai/gpt-4o-mini` (July 2024,
> non-reasoning). The budget is now **1500** and the defaults are modern. If you lower
> `max_tokens` again, switch back to a non-reasoning model or expect empty responses.

### OpenAI Models

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `openai/gpt-5.6-sol` | 5 → 30 | Flagship tier, complex reasoning |
| `openai/gpt-5.6-terra` | 1 → 6 | Balanced tier (council default) |
| `openai/gpt-5.6-luna` | 0.10 → 0.60 | Cost-efficient tier (consensus default) |
| `openai/gpt-5.1-codex` | — | Specialized for software engineering |
| `openai/gpt-5-nano` | — | Lightweight legacy GPT-5 |

### Google Models

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `google/gemini-3.6-flash` | 1.50 → 7.50 | Current Flash (council default) |
| `google/gemini-3.5-flash-lite` | 0.30 → 2.50 | Lightweight, fastest (consensus default) |
| `google/gemini-2.5-pro` | — | Legacy Gemini 2.5 |

### xAI (Grok) Models

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `x-ai/grok-4.5` | 2 → 6 | Current frontier Grok (council default) |
| `x-ai/grok-4.3` | 1.25 → 2.50 | Cheaper prior tier (consensus default) |
| `x-ai/grok-4.20` | — | Heavier reasoning tier |

### Anthropic Models

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `anthropic/claude-opus-5` | 5 → 25 | Frontier reasoning (council chairman default) |
| `anthropic/claude-sonnet-5` | 2 → 10 | Balanced, strong synthesis |
| `anthropic/claude-haiku-4.5` | — | Fastest, most efficient |

### Open-Weight Models

| Model | $/M in→out | Description |
|-------|-----------|-------------|
| `qwen/qwen3.8-max` | 2 → 6 | Open-weight frontier |
| `deepseek/deepseek-v4-pro` | 0.44 → 0.87 | Strong reasoning, very cheap |
| `deepseek/deepseek-v4-flash` | 0.14 → 0.28 | Cheapest capable member |
| `qwen/qwen3.7-flash` | 0.03 → 0.13 | Cheapest option in the catalog |

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
    "openai/gpt-5.6-luna",
    "google/gemini-3.5-flash-lite",
    "x-ai/grok-4.3"
  ],
  "max_tokens": 1500,
  "timeout_seconds": 60
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
