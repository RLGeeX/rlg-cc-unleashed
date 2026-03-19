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
| `openai/gpt-4o` | Council Member | Strong reasoning, widely trusted |
| `google/gemini-2.5-flash` | Council Member | Fast, good at synthesis |
| `x-ai/grok-4-fast` | Council Member | Different training, diverse perspective |

### Default Chairman

| Model | Why |
|-------|-----|
| `anthropic/claude-sonnet-4` | Excellent at synthesis, nuanced analysis |

---

## Recommended Council Compositions

### Diverse Perspectives (Default)

Best for technical decisions where you want different viewpoints.

```json
{
  "council": ["openai/gpt-4o", "google/gemini-2.5-flash", "x-ai/grok-4-fast"],
  "chairman": "anthropic/claude-sonnet-4"
}
```

### Deep Reasoning

For complex architectural decisions requiring careful analysis.

```json
{
  "council": ["openai/gpt-5-pro", "anthropic/claude-opus-4", "google/gemini-3-pro-preview"],
  "chairman": "anthropic/claude-opus-4"
}
```

### Fast Council

For quicker deliberations when time matters.

```json
{
  "council": ["openai/gpt-4o-mini", "google/gemini-2.5-flash-lite", "x-ai/grok-4-fast"],
  "chairman": "google/gemini-2.5-flash"
}
```

### Research Synthesis

For gathering and synthesizing information on a topic.

```json
{
  "council": ["openai/o3-deep-research", "google/gemini-2.5-pro", "anthropic/claude-sonnet-4"],
  "chairman": "anthropic/claude-opus-4"
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
| `openai/gpt-4o` | Balanced performance (recommended) |
| `openai/gpt-4o-mini` | Fast, cost-effective |
| `openai/o3-deep-research` | Research with web search |

### Google Models

| Model | Best For |
|-------|----------|
| `google/gemini-3-pro-preview` | State-of-the-art, 1M context |
| `google/gemini-2.5-pro` | Full Gemini 2.5 capabilities |
| `google/gemini-2.5-flash` | Fast responses (recommended) |
| `google/gemini-2.5-flash-lite` | Fastest, most economical |

### Anthropic Models

| Model | Best For |
|-------|----------|
| `anthropic/claude-opus-4.5` | Frontier reasoning, best chairman |
| `anthropic/claude-sonnet-4.5` | Great balance, 1M context |
| `anthropic/claude-sonnet-4` | Excellent synthesis (default chairman) |
| `anthropic/claude-haiku-4.5` | Fast, efficient |

### xAI (Grok) Models

| Model | Best For |
|-------|----------|
| `x-ai/grok-4` | Full Grok 4 capabilities |
| `x-ai/grok-4-fast` | Fast with 2M context (recommended) |
| `x-ai/grok-4.1-fast:free` | Free tier option |

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
    "openai/gpt-4o",
    "google/gemini-2.5-flash",
    "x-ai/grok-4-fast"
  ],
  "chairman": "anthropic/claude-sonnet-4",
  "max_tokens": 1000,
  "timeout_seconds": 90
}
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `council` | GPT-4o, Gemini, Grok | List of council member models |
| `chairman` | Claude Sonnet 4 | Model for final synthesis |
| `max_tokens` | 1000 | Max tokens per response (chairman gets 2x) |
| `timeout_seconds` | 90 | Request timeout |

---

See https://openrouter.ai/models for full model list and current pricing.
