# Council - Reference Documentation

Available OpenRouter models and configuration details for the LLM Council.

## Table of Contents

1. [Default Configuration](#default-configuration)
2. [Recommended Council Compositions](#recommended-council-compositions)
3. [Available Models](#available-models)
4. [Prompt Templates](#prompt-templates)

---

## Default Configuration

### Default Council Members

| Model | Role | Why |
|-------|------|-----|
| `openai/gpt-5` | Council Member | Strong reasoning, widely trusted |
| `google/gemini-3.5-flash` | Council Member | Fast, near-Pro reasoning at Flash cost |
| `x-ai/grok-4.3` | Council Member | Different training, diverse perspective |

### Default Chairman

| Model | Why |
|-------|-----|
| `anthropic/claude-sonnet-4.6` | Excellent at synthesis, nuanced analysis |

---

## Recommended Council Compositions

### Diverse Perspectives (Default)

Best for technical decisions where you want different viewpoints.

```json
{
  "council": ["openai/gpt-5", "google/gemini-3.5-flash", "x-ai/grok-4.3"],
  "chairman": "anthropic/claude-sonnet-4.6"
}
```

### Deep Reasoning (5 members, Opus chairman)

For complex architectural decisions requiring careful analysis with maximum cross-provider coverage. Run via `--members 5 --chairman anthropic/claude-opus-4.7` (auto-selects one model per non-Anthropic provider) or pin explicitly:

```json
{
  "council": [
    "openai/gpt-5",
    "google/gemini-3.5-flash",
    "x-ai/grok-4.3",
    "meta-llama/llama-4-maverick",
    "mistralai/mistral-large-2512"
  ],
  "chairman": "anthropic/claude-opus-4.7"
}
```

### Fast Council

For quicker deliberations when time matters.

```json
{
  "council": ["openai/gpt-5-mini", "google/gemini-2.5-flash-lite", "x-ai/grok-4.3"],
  "chairman": "google/gemini-3.5-flash"
}
```

### Research Synthesis

For gathering and synthesizing information on a topic.

```json
{
  "council": ["openai/gpt-5-pro", "google/gemini-2.5-pro", "anthropic/claude-sonnet-4.6"],
  "chairman": "anthropic/claude-opus-4.7"
}
```

---

## Available Models

### OpenAI Models

| Model | Best For |
|-------|----------|
| `openai/gpt-5.1` | Latest GPT with adaptive reasoning |
| `openai/gpt-5.1-codex` | Software engineering focus |
| `openai/gpt-5-pro` | Most advanced reasoning |
| `openai/gpt-5` | Balanced performance (default council member) |
| `openai/gpt-5-mini` | Fast, cost-effective (default for consensus) |

### Google Models

| Model | Best For |
|-------|----------|
| `google/gemini-3-pro-preview` | State-of-the-art, 1M context |
| `google/gemini-3.5-flash` | Near-Pro reasoning at Flash cost (default) |
| `google/gemini-2.5-pro` | Full Gemini 2.5 capabilities |
| `google/gemini-2.5-flash-lite` | Fastest, most economical |

### Anthropic Models

| Model | Best For |
|-------|----------|
| `anthropic/claude-opus-4.7` | Frontier reasoning, best chairman for hard cases |
| `anthropic/claude-opus-4.5` | Strong reasoning, prior frontier tier |
| `anthropic/claude-sonnet-4.6` | Excellent synthesis (default chairman) |
| `anthropic/claude-haiku-4.5` | Fast, efficient |

### xAI (Grok) Models

| Model | Best For |
|-------|----------|
| `x-ai/grok-4.3` | Current Grok (default council member) |
| `x-ai/grok-4.20` | Heavier reasoning tier |
| `x-ai/grok-4.1-fast` | Faster tier when latency matters |

### Other Providers

| Model | Best For |
|-------|----------|
| `meta-llama/llama-4-maverick` | Cross-architecture diversity |
| `mistralai/mistral-large-2512` | Strong European/multilingual reasoning |

---

## Prompt Templates

### Stage 1: Individual Response

Each council member receives:
- The question
- Instructions to provide: POSITION, REASONING, TRADE-OFFS, CONFIDENCE

### Stage 2: Peer Review (Anonymized)

Each council member receives:
- The original question
- All Stage 1 responses labeled as "Response A", "Response B", etc.
- Instructions to evaluate: STRONGEST_RESPONSE, KEY_AGREEMENTS, KEY_DISAGREEMENTS, GAPS, REVISED_POSITION

### Stage 3: Chairman Synthesis

The chairman receives:
- The original question
- All Stage 1 responses (with model names revealed)
- All Stage 2 peer reviews
- Instructions to synthesize: COUNCIL_RECOMMENDATION, CONSENSUS_POINTS, AREAS_OF_DEBATE, KEY_INSIGHTS, CONFIDENCE_LEVEL, DISSENTING_VIEWS, FINAL_VERDICT

---

## Configuration File

Location: `~/.claude/config/council.json`

```json
{
  "council": [
    "openai/gpt-5",
    "google/gemini-3.5-flash",
    "x-ai/grok-4.3"
  ],
  "chairman": "anthropic/claude-sonnet-4.6",
  "max_tokens": 1000,
  "timeout_seconds": 90
}
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `council` | GPT-5, Gemini-3.5-Flash, Grok-4.3 | List of council member models |
| `chairman` | Claude Sonnet 4.6 | Model for final synthesis |
| `max_tokens` | 1000 | Max tokens per response (chairman gets 2x) |
| `timeout_seconds` | 90 | Request timeout |

---

See https://openrouter.ai/models for full model list and current pricing.
