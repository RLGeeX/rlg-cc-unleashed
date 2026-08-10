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
| `openai/gpt-5.6-terra` | Council Member | Balanced GPT-5.6 tier — strong reasoning at $1/$6 per M |
| `google/gemini-3.6-flash` | Council Member | Fast, cheaper on output than 3.5-flash it replaced |
| `x-ai/grok-4.5` | Council Member | Different training, diverse perspective |

### Default Chairman

| Model | Why |
|-------|-----|
| `anthropic/claude-opus-5` | Frontier synthesis; the chairman is where quality pays off |

### Max Tokens

`DEFAULT_MAX_TOKENS` is **2500**. Every model in the default pool is a reasoning
model, and reasoning tokens draw against `max_tokens` — a smaller budget truncates
or empties responses. Do not lower this below ~2500 without switching to
non-reasoning members. The chairman automatically gets 2×.

---

## Recommended Council Compositions

### Diverse Perspectives (Default)

Best for technical decisions where you want different viewpoints.

```json
{
  "council": ["openai/gpt-5.6-terra", "google/gemini-3.6-flash", "x-ai/grok-4.5"],
  "chairman": "anthropic/claude-opus-5",
  "max_tokens": 2500
}
```

### Deep Reasoning (5 members, Opus chairman)

For complex architectural decisions requiring careful analysis with maximum
cross-provider coverage. No Anthropic model sits on the council — Opus chairs, so a
second house model would only echo it. Run via `--members 5`: `select_council_members()`
skips the chairman's own provider, so an Anthropic chairman structurally cannot draw an
Anthropic member. That also caps the roster at 5 — `-n 6` still yields 5. Or pin
explicitly:

```json
{
  "council": [
    "openai/gpt-5.6-terra",
    "google/gemini-3.6-flash",
    "x-ai/grok-4.5",
    "qwen/qwen3.7-max",
    "mistralai/mistral-medium-3-5"
  ],
  "chairman": "anthropic/claude-opus-5",
  "max_tokens": 3000
}
```

Swap `gpt-5.6-terra` → `gpt-5.6-sol`, `qwen3.7-max` → `qwen3.8-max` and
`mistral-medium-3-5` → `deepseek/deepseek-v4-pro` for the frontier-quality variant at
roughly 1.7× the cost.

### Fast Council

For quicker deliberations when time matters. Roughly a tenth the cost of the default.

```json
{
  "council": ["openai/gpt-5.6-luna", "google/gemini-3.5-flash-lite", "deepseek/deepseek-v4-flash"],
  "chairman": "anthropic/claude-opus-5"
}
```

### Research Synthesis

For gathering and synthesizing information on a topic.

```json
{
  "council": ["openai/gpt-5.6-sol", "google/gemini-3.6-flash", "qwen/qwen3.8-max"],
  "chairman": "anthropic/claude-opus-5"
}
```

---

## Available Models

Verified against the OpenRouter catalog on 2026-08-10. Prices are $ per million
tokens, prompt → completion. Re-check with `council.sh --discover --format table`
rather than trusting this table indefinitely — it goes stale in weeks.

### OpenAI Models

| Model | $/M in→out | Best For |
|-------|-----------|----------|
| `openai/gpt-5.6-sol` | 5 → 30 | Flagship tier; strongest multi-step coding |
| `openai/gpt-5.6-terra` | 1 → 6 | Balanced tier (default council member) |
| `openai/gpt-5.6-luna` | 0.10 → 0.60 | High-volume, latency-sensitive, cheap councils |
| `openai/gpt-5.5-pro` | 30 → 180 | Deepest reasoning; rarely worth it for a member |

### Google Models

| Model | $/M in→out | Best For |
|-------|-----------|----------|
| `google/gemini-3.6-flash` | 1.50 → 7.50 | Coding and agentic work (default council member) |
| `google/gemini-3.5-flash-lite` | 0.30 → 2.50 | Fastest, most economical |

### Anthropic Models

| Model | $/M in→out | Best For |
|-------|-----------|----------|
| `anthropic/claude-opus-5` | 5 → 25 | Frontier synthesis (default chairman) |
| `anthropic/claude-sonnet-5` | 2 → 10 | Cheaper chairman when the question isn't hard |
| `anthropic/claude-haiku-4.5` | — | Fast, efficient |

### xAI (Grok) Models

| Model | $/M in→out | Best For |
|-------|-----------|----------|
| `x-ai/grok-4.5` | 2 → 6 | Current frontier Grok (default council member) |
| `x-ai/grok-4.3` | 1.25 → 2.50 | Cheaper prior tier, 1M context |

### Other Providers

| Model | $/M in→out | Best For |
|-------|-----------|----------|
| `qwen/qwen3.8-max` | 2 → 6 | Open-weight frontier; real architectural diversity |
| `qwen/qwen3.7-max` | 1.48 → 4.43 | Same, one tier down (5-member default) |
| `deepseek/deepseek-v4-pro` | 0.44 → 0.87 | Strong reasoning, very cheap |
| `deepseek/deepseek-v4-flash` | 0.14 → 0.28 | Cheap-council member |
| `mistralai/mistral-medium-3-5` | 1.50 → 7.50 | European/multilingual reasoning |

`meta-llama/llama-4-maverick` was dropped from the defaults in the 2026-08-10 refresh:
released 2025-04, and the only non-reasoning model left in the pool.

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
    "openai/gpt-5.6-terra",
    "google/gemini-3.6-flash",
    "x-ai/grok-4.5"
  ],
  "chairman": "anthropic/claude-opus-5",
  "max_tokens": 2500,
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
