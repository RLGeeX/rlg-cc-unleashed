# Consensus - Reference Documentation

Available OpenRouter models and configuration details.

## Table of Contents

1. [Available Models](#available-models)
2. [Configuration](#configuration)
3. [Using openrouter/auto](#using-openrouterauto)

---

## Available Models

### Default Models

| Model | Description |
|-------|-------------|
| `openai/gpt-4o-mini` | Fast, cost-effective GPT-4 |
| `google/gemini-2.5-flash` | Latest Gemini Flash |
| `x-ai/grok-4-fast` | Fast Grok with 2M context |

### OpenAI Models

| Model | Description |
|-------|-------------|
| `openai/gpt-5.1` | Latest GPT-5 with adaptive reasoning |
| `openai/gpt-5.1-codex` | Specialized for software engineering |
| `openai/gpt-5.1-codex-mini` | Faster codex variant |
| `openai/gpt-5-pro` | Most advanced reasoning |
| `openai/gpt-5-mini` | Balanced GPT-5 |
| `openai/gpt-5-nano` | Lightweight GPT-5 |
| `openai/gpt-4o-mini` | Fast, cost-effective |
| `openai/o3-deep-research` | Web search for research tasks |
| `openai/o4-mini-deep-research` | Faster deep research |

### Google Models

| Model | Description |
|-------|-------------|
| `google/gemini-3-pro-preview` | 1M context, state-of-the-art |
| `google/gemini-2.5-pro` | Full Gemini 2.5 |
| `google/gemini-2.5-flash` | Fast Gemini 2.5 |
| `google/gemini-2.5-flash-lite` | Lightweight, fastest |

### xAI (Grok) Models

| Model | Description |
|-------|-------------|
| `x-ai/grok-4.1-fast:free` | Free tier, 2M context |
| `x-ai/grok-4-fast` | Fast with 2M context |
| `x-ai/grok-4` | Full Grok 4 |

### Anthropic Models

| Model | Description |
|-------|-------------|
| `anthropic/claude-opus-4.5` | Frontier reasoning |
| `anthropic/claude-sonnet-4.5` | 1M context, >73% SWE-bench |
| `anthropic/claude-haiku-4.5` | Fastest, most efficient |

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
    "openai/gpt-4o-mini",
    "google/gemini-2.5-flash",
    "x-ai/grok-4-fast"
  ]
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
