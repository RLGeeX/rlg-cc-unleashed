#!/usr/bin/env python3
"""
LLM Council - Multi-model deliberative reasoning via OpenRouter.

3-stage process:
1. Query: Each council member responds independently
2. Peer Review: Members review anonymized responses
3. Synthesis: Chairman combines insights into final recommendation

Based on Karpathy's LLM Council concept.
"""

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path
from typing import Optional

try:
    import httpx
except ImportError:
    print("ERROR: httpx not installed. Run: pip install httpx")
    sys.exit(1)


# =============================================================================
# Configuration
# =============================================================================

DEFAULT_COUNCIL = [
    "openai/gpt-4o",
    "google/gemini-2.5-flash",
    "x-ai/grok-4-fast",
]
DEFAULT_CHAIRMAN = "anthropic/claude-sonnet-4"
DEFAULT_MAX_TOKENS = 1000
DEFAULT_TIMEOUT = 90

OPENROUTER_API = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_MODELS_API = "https://openrouter.ai/api/v1/models"

# Major providers to filter for in --discover
MAJOR_PROVIDERS = [
    "openai",
    "anthropic",
    "google",
    "x-ai",
    "meta-llama",
    "mistralai",
]

# ANSI colors
BOLD = "\033[1m"
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
CYAN = "\033[0;36m"
MAGENTA = "\033[0;35m"
NC = "\033[0m"


def load_config() -> dict:
    """Load configuration from file or use defaults."""
    config = {
        "council": DEFAULT_COUNCIL,
        "chairman": DEFAULT_CHAIRMAN,
        "max_tokens": DEFAULT_MAX_TOKENS,
        "timeout_seconds": DEFAULT_TIMEOUT,
    }

    config_path = Path.home() / ".claude" / "config" / "council.json"
    if config_path.exists():
        try:
            with open(config_path) as f:
                file_config = json.load(f)
            config.update(file_config)
            print(f"{BLUE}[INFO]{NC} Loaded config from {config_path}")
        except (json.JSONDecodeError, OSError) as e:
            print(f"{YELLOW}[WARN]{NC} Failed to load config: {e}")

    return config


def discover_models(output_format: str = "json") -> int:
    """Fetch available models from OpenRouter and filter to major providers."""
    import httpx  # Sync version for discovery

    try:
        response = httpx.get(OPENROUTER_MODELS_API, timeout=30)
        response.raise_for_status()
        data = response.json()
    except httpx.HTTPError as e:
        print(f"{RED}[ERROR]{NC} Failed to fetch models: {e}", file=sys.stderr)
        return 1

    models = data.get("data", [])

    # Filter to major providers
    filtered = []
    for model in models:
        model_id = model.get("id", "")
        provider = model_id.split("/")[0] if "/" in model_id else ""

        if provider in MAJOR_PROVIDERS:
            # Extract useful fields
            pricing = model.get("pricing", {})
            prompt_price = float(pricing.get("prompt", 0)) * 1_000_000  # per 1M tokens
            completion_price = float(pricing.get("completion", 0)) * 1_000_000

            filtered.append({
                "id": model_id,
                "name": model.get("name", ""),
                "provider": provider,
                "context_length": model.get("context_length", 0),
                "pricing": {
                    "prompt_per_1m": round(prompt_price, 2),
                    "completion_per_1m": round(completion_price, 2),
                },
                "modality": model.get("architecture", {}).get("modality", "text->text"),
            })

    # Sort by provider, then by name
    filtered.sort(key=lambda x: (x["provider"], x["name"]))

    # Group by provider
    by_provider = {}
    for model in filtered:
        provider = model["provider"]
        if provider not in by_provider:
            by_provider[provider] = []
        by_provider[provider].append(model)

    if output_format == "json":
        print(json.dumps({
            "total": len(filtered),
            "providers": list(by_provider.keys()),
            "models": by_provider,
        }, indent=2))
    else:
        # Human-readable format
        print_header("Available Models (Major Providers)")
        print(f"Total: {len(filtered)} models from {len(by_provider)} providers\n")

        for provider, models in by_provider.items():
            print(f"{BOLD}{provider.upper()}{NC} ({len(models)} models)")
            print("-" * 50)
            for m in models[:10]:  # Show top 10 per provider
                ctx = f"{m['context_length'] // 1000}K" if m['context_length'] >= 1000 else str(m['context_length'])
                price = f"${m['pricing']['prompt_per_1m']:.2f}/${m['pricing']['completion_per_1m']:.2f}"
                print(f"  {m['id']:<45} {ctx:>8} ctx  {price:>15}/1M")
            if len(models) > 10:
                print(f"  ... and {len(models) - 10} more")
            print()

    return 0


def get_model_label(index: int) -> str:
    """Get anonymized label for a model (Response A, B, C, etc.)."""
    return chr(65 + index)  # A, B, C, ...


def get_model_short_name(model: str) -> str:
    """Extract short name from model identifier."""
    model_lower = model.lower()
    if "gpt" in model_lower:
        return "GPT"
    elif "gemini" in model_lower:
        return "Gemini"
    elif "grok" in model_lower:
        return "Grok"
    elif "claude" in model_lower:
        return "Claude"
    elif "llama" in model_lower:
        return "Llama"
    elif "mistral" in model_lower:
        return "Mistral"
    else:
        return model.split("/")[-1]


# =============================================================================
# Prompts
# =============================================================================

def build_stage1_prompt(question: str) -> str:
    """Build prompt for Stage 1: Initial Response."""
    return f"""You are participating in a multi-model council deliberation. Provide your perspective on the following question.

Structure your response as follows:

POSITION: [Your clear position or recommendation in 1-2 sentences]
REASONING: [Your key arguments and reasoning in 3-5 sentences]
TRADE-OFFS: [Important trade-offs or considerations to keep in mind]
CONFIDENCE: [high/medium/low] - How confident are you in this position?

Question: {question}"""


def build_stage2_prompt(question: str, responses: list[tuple[str, str]]) -> str:
    """Build prompt for Stage 2: Peer Review."""
    anonymized_responses = "\n\n".join([
        f"--- Response {get_model_label(i)} ---\n{response}"
        for i, (_, response) in enumerate(responses)
    ])

    return f"""You are reviewing responses from other council members on this question:

Question: {question}

Here are the anonymized responses:

{anonymized_responses}

---

Evaluate these responses and provide your assessment:

STRONGEST_RESPONSE: [Which response (A, B, C, etc.) is strongest and why?]
KEY_AGREEMENTS: [What do the responses agree on?]
KEY_DISAGREEMENTS: [Where do they differ and why might that be?]
GAPS: [What important considerations are missing from these responses?]
REVISED_POSITION: [Based on reviewing others, has your position changed? How?]"""


def build_stage3_prompt(question: str, stage1_responses: list[tuple[str, str]],
                        stage2_reviews: list[tuple[str, str]]) -> str:
    """Build prompt for Stage 3: Chairman Synthesis."""
    # Include original responses with model names revealed
    original_responses = "\n\n".join([
        f"--- {get_model_short_name(model)} ---\n{response}"
        for model, response in stage1_responses
    ])

    # Include peer reviews (anonymized)
    peer_reviews = "\n\n".join([
        f"--- Review by {get_model_short_name(model)} ---\n{review}"
        for model, review in stage2_reviews
    ])

    return f"""You are the Chairman of an LLM Council. Your role is to synthesize the deliberations into a final recommendation.

Original Question: {question}

=== STAGE 1: INDIVIDUAL RESPONSES ===

{original_responses}

=== STAGE 2: PEER REVIEWS ===

{peer_reviews}

---

As Chairman, synthesize these deliberations into a final council recommendation:

COUNCIL_RECOMMENDATION: [Clear, actionable recommendation based on the collective deliberation]

CONSENSUS_POINTS: [What the council agrees on]

AREAS_OF_DEBATE: [Where reasonable disagreement exists and why]

KEY_INSIGHTS: [Most valuable insights that emerged from the deliberation]

CONFIDENCE_LEVEL: [high/medium/low] - Council's overall confidence in this recommendation

DISSENTING_VIEWS: [Any important minority positions worth noting]

FINAL_VERDICT: [1-2 sentence summary of the council's recommendation]"""


# =============================================================================
# API Calls
# =============================================================================

async def call_model(
    client: httpx.AsyncClient,
    model: str,
    prompt: str,
    api_key: str,
    max_tokens: int,
    timeout: int,
) -> tuple[str, str, Optional[str]]:
    """Call a model via OpenRouter API. Returns (model, response, error)."""
    try:
        response = await client.post(
            OPENROUTER_API,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://github.com/rlgeex/rlg-cc-unleashed",
                "X-Title": "CC-Unleashed Council",
            },
            json={
                "model": model,
                "max_tokens": max_tokens,
                "messages": [{"role": "user", "content": prompt}],
            },
            timeout=timeout,
        )

        if response.status_code != 200:
            error_text = response.text
            try:
                error_json = response.json()
                if "error" in error_json:
                    error_text = error_json["error"].get("message", error_text)
            except json.JSONDecodeError:
                pass
            return model, "", f"HTTP {response.status_code}: {error_text}"

        data = response.json()
        content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
        if not content:
            return model, "", "Empty response"

        return model, content, None

    except httpx.TimeoutException:
        return model, "", "Request timed out"
    except Exception as e:
        return model, "", str(e)


async def query_models(
    models: list[str],
    prompt_builder,
    api_key: str,
    max_tokens: int,
    timeout: int,
    **prompt_kwargs,
) -> list[tuple[str, str]]:
    """Query multiple models in parallel. Returns list of (model, response)."""
    async with httpx.AsyncClient() as client:
        tasks = [
            call_model(
                client,
                model,
                prompt_builder(**prompt_kwargs),
                api_key,
                max_tokens,
                timeout,
            )
            for model in models
        ]
        results = await asyncio.gather(*tasks)

    successful = []
    for model, response, error in results:
        if error:
            print(f"{RED}[ERROR]{NC} {get_model_short_name(model)}: {error}")
        else:
            successful.append((model, response))

    return successful


# =============================================================================
# Main Execution
# =============================================================================

def print_header(text: str):
    """Print a section header."""
    print()
    print(f"{BOLD}{'=' * 70}{NC}")
    print(f"{BOLD}  {text}{NC}")
    print(f"{BOLD}{'=' * 70}{NC}")
    print()


def print_subheader(text: str):
    """Print a subsection header."""
    print()
    print(f"{BOLD}{'-' * 70}{NC}")
    print(f"{BOLD}  {text}{NC}")
    print(f"{BOLD}{'-' * 70}{NC}")
    print()


async def run_council(
    question: str,
    council: list[str],
    chairman: str,
    api_key: str,
    max_tokens: int,
    timeout: int,
) -> int:
    """Run the 3-stage council process."""

    print_header("LLM Council Deliberation")
    print(f"{CYAN}Question:{NC} {question}")
    print()
    print(f"{CYAN}Council Members:{NC}")
    for i, model in enumerate(council):
        print(f"  {i + 1}. {model}")
    print(f"{CYAN}Chairman:{NC} {chairman}")

    # =========================================================================
    # Stage 1: Individual Responses
    # =========================================================================
    print_header("Stage 1: Individual Responses")
    print(f"{BLUE}[INFO]{NC} Querying council members in parallel...")

    stage1_responses = await query_models(
        council,
        lambda q=question: build_stage1_prompt(q),
        api_key,
        max_tokens,
        timeout,
    )

    if len(stage1_responses) < 2:
        print(f"{RED}[ERROR]{NC} Insufficient responses for deliberation ({len(stage1_responses)}/{len(council)})")
        return 1

    print(f"{GREEN}[OK]{NC} Received {len(stage1_responses)}/{len(council)} responses")

    for model, response in stage1_responses:
        print_subheader(f"{get_model_short_name(model)} ({model})")
        print(response)

    # =========================================================================
    # Stage 2: Peer Review
    # =========================================================================
    print_header("Stage 2: Peer Review (Anonymized)")
    print(f"{BLUE}[INFO]{NC} Council members reviewing anonymized responses...")

    # Each council member reviews all responses
    responding_models = [model for model, _ in stage1_responses]

    async with httpx.AsyncClient() as client:
        review_tasks = [
            call_model(
                client,
                model,
                build_stage2_prompt(question, stage1_responses),
                api_key,
                max_tokens,
                timeout,
            )
            for model in responding_models
        ]
        review_results = await asyncio.gather(*review_tasks)

    stage2_reviews = []
    for model, review, error in review_results:
        if error:
            print(f"{RED}[ERROR]{NC} {get_model_short_name(model)} review failed: {error}")
        else:
            stage2_reviews.append((model, review))

    if len(stage2_reviews) < 2:
        print(f"{YELLOW}[WARN]{NC} Limited peer reviews available ({len(stage2_reviews)})")

    print(f"{GREEN}[OK]{NC} Received {len(stage2_reviews)} peer reviews")

    for model, review in stage2_reviews:
        print_subheader(f"Review by {get_model_short_name(model)}")
        print(review)

    # =========================================================================
    # Stage 3: Chairman Synthesis
    # =========================================================================
    print_header("Stage 3: Chairman Synthesis")
    print(f"{BLUE}[INFO]{NC} Chairman ({get_model_short_name(chairman)}) synthesizing deliberations...")

    async with httpx.AsyncClient() as client:
        _, synthesis, error = await call_model(
            client,
            chairman,
            build_stage3_prompt(question, stage1_responses, stage2_reviews),
            api_key,
            max_tokens * 2,  # Chairman gets more tokens for synthesis
            timeout,
        )

    if error:
        print(f"{RED}[ERROR]{NC} Chairman synthesis failed: {error}")
        print()
        print(f"{YELLOW}Falling back to summary of Stage 1 responses:{NC}")
        for model, response in stage1_responses:
            print(f"\n{get_model_short_name(model)}: {response[:200]}...")
        return 1

    print_subheader(f"Chairman's Synthesis ({get_model_short_name(chairman)})")
    print(synthesis)

    # =========================================================================
    # Summary
    # =========================================================================
    print_header("Council Deliberation Complete")
    print(f"{GREEN}Council Members:{NC} {len(stage1_responses)}/{len(council)} participated")
    print(f"{GREEN}Peer Reviews:{NC} {len(stage2_reviews)} completed")
    print(f"{GREEN}Chairman:{NC} {get_model_short_name(chairman)} synthesized")
    print()

    return 0


def main():
    parser = argparse.ArgumentParser(
        description="LLM Council - Multi-model deliberative reasoning",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  council.py --discover                    # List available models from OpenRouter
  council.py --discover --format table     # Human-readable table format
  council.py --question "Should we use GraphQL or REST for our API?"
  council.py -q "Monorepo vs polyrepo?" --council "openai/gpt-4o,google/gemini-2.5-flash"
  council.py -q "Best approach for real-time updates?" --chairman "anthropic/claude-opus-4"
        """,
    )
    parser.add_argument(
        "-q", "--question",
        help="The question for the council to deliberate",
    )
    parser.add_argument(
        "--discover",
        action="store_true",
        help="Fetch and display available models from OpenRouter (filtered to major providers)",
    )
    parser.add_argument(
        "--format",
        choices=["json", "table"],
        default="json",
        help="Output format for --discover (default: json)",
    )
    parser.add_argument(
        "-c", "--council",
        help="Comma-separated list of council member models (default: from config)",
    )
    parser.add_argument(
        "--chairman",
        help="Chairman model for synthesis (default: from config)",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        help="Maximum tokens per response (default: from config)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        help="Request timeout in seconds (default: from config)",
    )

    args = parser.parse_args()

    # Handle --discover (doesn't need API key or question)
    if args.discover:
        sys.exit(discover_models(args.format))

    # Validate question is provided for council deliberation
    if not args.question:
        parser.error("--question is required (or use --discover to list models)")

    # Check API key
    api_key = os.environ.get("OPENROUTER_API_KEY")
    if not api_key:
        print(f"{RED}[ERROR]{NC} OPENROUTER_API_KEY environment variable not set")
        print()
        print("Set it in your shell profile (~/.bashrc or ~/.zshrc):")
        print('  export OPENROUTER_API_KEY="sk-or-your-key-here"')
        sys.exit(1)

    # Load config
    config = load_config()

    # Override with CLI args
    council = args.council.split(",") if args.council else config["council"]
    chairman = args.chairman or config["chairman"]
    max_tokens = args.max_tokens or config["max_tokens"]
    timeout = args.timeout or config["timeout_seconds"]

    # Run council
    exit_code = asyncio.run(
        run_council(
            question=args.question,
            council=council,
            chairman=chairman,
            api_key=api_key,
            max_tokens=max_tokens,
            timeout=timeout,
        )
    )

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
