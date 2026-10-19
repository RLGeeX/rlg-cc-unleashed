# Council - Reference Documentation

Available OpenRouter models and configuration details for the LLM Council.

## Table of Contents

1. [Default Configuration](#default-configuration)
2. [Recommended Council Compositions](#recommended-council-compositions)
3. [Replay Results](#replay-results)
4. [Available Models](#available-models)
5. [Prompt Templates](#prompt-templates)

---

## Default Configuration

### Default Council Members

| Model | Role | Why |
|-------|------|-----|
| `openai/gpt-6.1-sol` | Council Member | GPT-6.1 mid tier; cheaper than the gpt-5.6-terra it replaced ($2/$10 vs $2/$12) |
| `google/gemini-4-argon` | Council Member | Google's flagship reasoning model, same price tier as the other seats |
| `x-ai/grok-4.7` | Council Member | Different training, diverse perspective |

### Default Chairman

| Model | Why |
|-------|-----|
| `anthropic/claude-opus-5.5` | Frontier synthesis, and cheaper than Opus 5 ($4/$20 vs $5/$25) |

### Budget, Reasoning Cap, Timeout

| Setting | Default | Why |
|---------|---------|-----|
| `max_tokens` | **8000** | Reasoning tokens draw against it; the chairman gets 2× |
| `reasoning_effort` | **medium** | Sent as OpenRouter `reasoning.effort`; stops a member spending the whole budget thinking |
| `timeout_seconds` | **240** | grok-4.7 took up to 142s on long real questions |

All three matter together. At the old 2500 tokens with no cap, five of eight
candidates returned empty or cut-off answers on real questions (see
[Replay Results](#replay-results)). A member that still runs out is reported as
`Truncated`, and a partly cut-off answer is tagged `[TRUNCATED]` rather than passed
off as complete.

---

## Recommended Council Compositions

### Diverse Perspectives (Default)

Best for technical decisions where you want different viewpoints.

```json
{
  "council": ["openai/gpt-6.1-sol", "google/gemini-4-argon", "x-ai/grok-4.7"],
  "chairman": "anthropic/claude-opus-5.5",
  "max_tokens": 8000
}
```

### Deep Reasoning (5 members, Opus chairman)

For complex architectural decisions requiring careful analysis with wide
cross-provider coverage. No Anthropic model sits on the council — Opus chairs, so a
second house model would only echo it. Run via `--members 5`: `select_council_members()`
skips the chairman's own provider, so an Anthropic chairman structurally cannot draw an
Anthropic member. Or pin explicitly:

```json
{
  "council": [
    "openai/gpt-6.1-sol",
    "google/gemini-4-argon",
    "x-ai/grok-4.7",
    "moonshotai/kimi-k3",
    "z-ai/glm-5.3"
  ],
  "chairman": "anthropic/claude-opus-5.5",
  "max_tokens": 8000
}
```

### Full Council (6 members)

`--members 6` seats every non-Anthropic provider in `PROVIDER_ORDER`: the five above
plus `deepseek/deepseek-v4-pro-0813`, for foundational decisions where breadth matters more than cost
or latency. `-n 7` still yields 6.

For a frontier-quality variant of any roster, swap `gpt-6.1-sol` → `gpt-6-astra`
($10/$50), the only member upgrade that changes the price class.

### Fast Council

For quicker deliberations when time matters. Roughly a tenth the cost of the default.

```json
{
  "council": ["openai/gpt-6-luna", "google/gemini-3.8-flash", "x-ai/grok-4.3"],
  "chairman": "anthropic/claude-sonnet-5.5"
}
```

### Research Synthesis

For gathering and synthesizing information on a topic.

```json
{
  "council": ["openai/gpt-6.1-sol", "google/gemini-4-argon", "moonshotai/kimi-k3"],
  "chairman": "anthropic/claude-opus-5.5"
}
```

---

## Replay Results

On 2026-10-19 the council stage-1 prompt was replayed with five real council and
consensus questions from Claude Code history (positioning briefs, a resume-tool
pick, a k8s decomposition question; 350–630 words each). "ok" means the model
finished with a real answer.

| Model | 2500 tokens, no cap | 8000 + effort medium | Slowest call |
|-------|--------------------:|---------------------:|-------------:|
| openai/gpt-6.1-sol | 5/5 | 5/5 | 26s |
| google/gemini-4-argon | 5/5 | 5/5 | 18s |
| x-ai/grok-4.7 | 5/5 | 5/5 | 142s |
| moonshotai/kimi-k3 | 2/5 | 5/5 | 18s |
| deepseek/deepseek-v4-pro-0813 | 3/5 | 5/5 | 75s |
| z-ai/glm-5.3 | 3/5 | 5/5 | 38s |
| qwen/qwen3.8-max-0902 | 0/5 | 5/5 | 113s |
| mistralai/mistral-large-4-0 | 0/5 | 3/5 | 227s |

Mistral was dropped for still truncating with the cap. Qwen was dropped as the
slowest, most verbose and most expensive of the extended seats. The same history
showed the failure in the wild: a 2026-08-10 council got one empty and one
mid-sentence answer, and a timeout misreported as `HTTP 200000`.

---

## Available Models

Verified against the OpenRouter catalog on 2026-10-19. Prices are $ per million
tokens, prompt → completion. Re-check with `council.sh --discover --format table`
rather than trusting this table indefinitely — it goes stale in weeks.

### OpenAI Models

| Model | $/M in→out | Best For |
|-------|-----------|----------|
| `openai/gpt-6-astra` | 10 → 50 | Flagship; deepest analysis, rarely worth it for a member |
| `openai/gpt-6.1-sol` | 2 → 10 | Mid tier (default council member) |
| `openai/gpt-6-luna` | 0.10 → 0.50 | High-volume, latency-sensitive, cheap councils |

### Google Models

| Model | $/M in→out | Best For |
|-------|-----------|----------|
| `google/gemini-4-argon` | 2 → 10 | Flagship reasoning (default council member) |
| `google/gemini-3.8-flash` | 0.83 → 4.13 | Strongest Flash; fast councils |
| `google/gemini-3.5-flash-lite` | 0.30 → 2.50 | Cheapest Google option |

`google/gemini-2.5-*` models expire on OpenRouter on 2026-10-20 — do not pin them.

### Anthropic Models

| Model | $/M in→out | Best For |
|-------|-----------|----------|
| `anthropic/claude-opus-5.5` | 4 → 20 | Frontier synthesis (default chairman) |
| `anthropic/claude-sonnet-5.5` | 2 → 10 | Cheaper chairman when the question isn't hard |
| `anthropic/claude-haiku-5.5` | 0.10 → 0.50 | Fast, efficient |
| `anthropic/claude-fable-5.1` | 10 → 50 | Most capable; chairman for the hardest questions only |

### xAI (Grok) Models

| Model | $/M in→out | Best For |
|-------|-----------|----------|
| `x-ai/grok-4.7` | 2 → 6 | Current frontier Grok (default council member) |
| `x-ai/grok-4.3` | 1.25 → 2.50 | Fast, reliable tier (consensus default, fast council) |

### Other Providers

| Model | $/M in→out | Best For |
|-------|-----------|----------|
| `moonshotai/kimi-k3` | 0.24 → 11.94 | 2.8T open-weight reasoning; fast with the cap (5-member roster) |
| `deepseek/deepseek-v4-pro-0813` | 0.66 → 1.98 | Strong reasoning, very cheap; truncated one long brief end-to-end (6-member roster) |
| `z-ai/glm-5.3` | 0.08 → 1.40 | 1M-context reasoning; fast, light reasoning (5-member roster) |

Not recommended (see [Replay Results](#replay-results)): `mistralai/mistral-large-4-0`
truncates even with the reasoning cap; `qwen/qwen3.8-max-0902` is slow and verbose;
`deepseek/deepseek-v4.1-flash` and `qwen/qwen3.8-flash` truncate as cheap members.

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
    "openai/gpt-6.1-sol",
    "google/gemini-4-argon",
    "x-ai/grok-4.7"
  ],
  "chairman": "anthropic/claude-opus-5.5",
  "max_tokens": 8000,
  "reasoning_effort": "medium",
  "timeout_seconds": 240
}
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `council` | GPT-6.1 Sol, Gemini 4 Argon, Grok 4.7 | List of council member models |
| `chairman` | Claude Opus 5.5 | Model for final synthesis |
| `max_tokens` | 8000 | Max tokens per response (chairman gets 2x) |
| `reasoning_effort` | medium | OpenRouter `reasoning.effort` cap: low, medium, high |
| `timeout_seconds` | 240 | Request timeout |

---

See https://openrouter.ai/models for full model list and current pricing.
