#!/usr/bin/env bash
#
# LLM Council - Multi-model deliberative reasoning via OpenRouter
#
# 3-stage process:
# 1. Query: Each council member responds independently
# 2. Peer Review: Members review anonymized responses
# 3. Synthesis: Chairman combines insights into final recommendation
#
# Based on Karpathy's LLM Council concept.
#
# Requirements: curl, jq
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

OPENROUTER_API="https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_MODELS_API="https://openrouter.ai/api/v1/models"

DEFAULT_CHAIRMAN="anthropic/claude-sonnet-4"
DEFAULT_MEMBERS=3
DEFAULT_MAX_TOKENS=1000
DEFAULT_TIMEOUT=90

# Preferred models by provider (best first)
declare -A PROVIDER_MODELS=(
    [openai]="openai/gpt-4o"
    [google]="google/gemini-2.5-flash"
    [x-ai]="x-ai/grok-4"
    [meta-llama]="meta-llama/llama-4-maverick"
    [mistralai]="mistralai/mistral-large"
    [anthropic]="anthropic/claude-sonnet-4"
)
PROVIDER_ORDER=(openai google x-ai meta-llama mistralai anthropic)

# ANSI colors
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Temp directory for parallel results
TMPDIR="${TMPDIR:-/tmp}"
WORK_DIR=""

# =============================================================================
# Utility Functions
# =============================================================================

cleanup() {
    if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}

trap cleanup EXIT

die() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    exit 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

print_header() {
    echo ""
    echo -e "${BOLD}======================================================================${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BOLD}======================================================================${NC}"
    echo ""
}

print_subheader() {
    echo ""
    echo -e "${BOLD}----------------------------------------------------------------------${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BOLD}----------------------------------------------------------------------${NC}"
    echo ""
}

select_council_members() {
    # Select N council members from different providers, excluding chairman's provider
    local count="$1"
    local chairman="$2"
    local chairman_provider="${chairman%%/*}"

    local selected=()
    for provider in "${PROVIDER_ORDER[@]}"; do
        if [[ "$provider" == "$chairman_provider" ]]; then
            continue
        fi
        if [[ ${#selected[@]} -ge $count ]]; then
            break
        fi
        if [[ -n "${PROVIDER_MODELS[$provider]:-}" ]]; then
            selected+=("${PROVIDER_MODELS[$provider]}")
        fi
    done

    # Return comma-separated list
    local IFS=','
    echo "${selected[*]}"
}

get_model_short_name() {
    local model="$1"
    local lower
    lower=$(echo "$model" | tr '[:upper:]' '[:lower:]')

    case "$lower" in
        *gpt*) echo "GPT" ;;
        *gemini*) echo "Gemini" ;;
        *grok*) echo "Grok" ;;
        *claude*) echo "Claude" ;;
        *llama*) echo "Llama" ;;
        *mistral*) echo "Mistral" ;;
        *) echo "${model##*/}" ;;
    esac
}

get_model_label() {
    # Convert index (0,1,2...) to letter (A,B,C...)
    local index=$1
    printf "\\x$(printf '%02x' $((65 + index)))"
}

# =============================================================================
# API Functions
# =============================================================================

call_model() {
    local model="$1"
    local prompt="$2"
    local max_tokens="$3"
    local timeout="$4"
    local output_file="$5"

    # Escape the prompt for JSON
    local escaped_prompt
    escaped_prompt=$(echo "$prompt" | jq -Rs .)

    # Build request body (same pattern as consensus.sh)
    local request_body
    request_body=$(cat <<EOF
{
  "model": "$model",
  "max_tokens": $max_tokens,
  "messages": [
    {
      "role": "user",
      "content": $escaped_prompt
    }
  ]
}
EOF
)

    # Make API call (same pattern as consensus.sh)
    local http_code
    http_code=$(curl -s -w "%{http_code}" -o "$output_file" \
        --max-time "$timeout" \
        -X POST "$OPENROUTER_API" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -H "HTTP-Referer: https://github.com/rlgeex/rlg-cc-unleashed" \
        -H "X-Title: CC-Unleashed Council" \
        -d "$request_body" 2>/dev/null || echo "000")

    # Check HTTP response code
    if [[ "$http_code" != "200" ]]; then
        local error_detail=""
        if [[ -f "$output_file" ]]; then
            error_detail=$(jq -r '.error.message // .error // ""' "$output_file" 2>/dev/null || true)
        fi
        echo "{\"error\": \"HTTP $http_code${error_detail:+: $error_detail}\", \"model\": \"$model\"}" > "$output_file"
        return 1
    fi

    # Check for API error in response body
    if jq -e '.error' "$output_file" &>/dev/null; then
        local error_msg
        error_msg=$(jq -r '
          if (.error | type) == "string" then .error
          elif (.error | type) == "object" then (.error.message // "Unknown error")
          else "Unknown error"
          end
        ' "$output_file" 2>/dev/null || echo "Error parsing response")
        echo "{\"error\": \"$error_msg\", \"model\": \"$model\"}" > "$output_file"
        return 1
    fi

    # Extract content from OpenRouter response
    local content
    content=$(jq -r '.choices[0].message.content // empty' "$output_file" 2>/dev/null)

    if [[ -z "$content" ]]; then
        echo "{\"error\": \"Empty response\", \"model\": \"$model\"}" > "$output_file"
        return 1
    fi

    # Save successful response with model info (compact for JSONL compatibility)
    jq -cn --arg model "$model" --arg content "$content" \
        '{model: $model, content: $content}' > "$output_file"
    return 0
}

# =============================================================================
# Prompts
# =============================================================================

build_stage1_prompt() {
    local question="$1"
    cat <<EOF
You are participating in a multi-model council deliberation. Provide your perspective on the following question.

Structure your response as follows:

POSITION: [Your clear position or recommendation in 1-2 sentences]
REASONING: [Your key arguments and reasoning in 3-5 sentences]
TRADE-OFFS: [Important trade-offs or considerations to keep in mind]
CONFIDENCE: [high/medium/low] - How confident are you in this position?

Question: $question
EOF
}

build_stage2_prompt() {
    local question="$1"
    local responses_file="$2"

    local anonymized=""
    local i=0

    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local label
            label=$(get_model_label $i)
            local content
            content=$(echo "$line" | jq -r '.content')
            anonymized+="--- Response $label ---
$content

"
            ((i++)) || true
        fi
    done < "$responses_file"

    cat <<EOF
You are reviewing responses from other council members on this question:

Question: $question

Here are the anonymized responses:

$anonymized
---

Evaluate these responses and provide your assessment:

STRONGEST_RESPONSE: [Which response (A, B, C, etc.) is strongest and why?]
KEY_AGREEMENTS: [What do the responses agree on?]
KEY_DISAGREEMENTS: [Where do they differ and why might that be?]
GAPS: [What important considerations are missing from these responses?]
REVISED_POSITION: [Based on reviewing others, has your position changed? How?]
EOF
}

build_stage3_prompt() {
    local question="$1"
    local stage1_file="$2"
    local stage2_file="$3"

    local original_responses=""
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local model short_name content
            model=$(echo "$line" | jq -r '.model')
            short_name=$(get_model_short_name "$model")
            content=$(echo "$line" | jq -r '.content')
            original_responses+="--- $short_name ---
$content

"
        fi
    done < "$stage1_file"

    local peer_reviews=""
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local model short_name content
            model=$(echo "$line" | jq -r '.model')
            short_name=$(get_model_short_name "$model")
            content=$(echo "$line" | jq -r '.content')
            peer_reviews+="--- Review by $short_name ---
$content

"
        fi
    done < "$stage2_file"

    cat <<EOF
You are the Chairman of an LLM Council. Your role is to synthesize the deliberations into a final recommendation.

Original Question: $question

=== STAGE 1: INDIVIDUAL RESPONSES ===

$original_responses

=== STAGE 2: PEER REVIEWS ===

$peer_reviews

---

As Chairman, synthesize these deliberations into a final council recommendation:

COUNCIL_RECOMMENDATION: [Clear, actionable recommendation based on the collective deliberation]

CONSENSUS_POINTS: [What the council agrees on]

AREAS_OF_DEBATE: [Where reasonable disagreement exists and why]

KEY_INSIGHTS: [Most valuable insights that emerged from the deliberation]

CONFIDENCE_LEVEL: [high/medium/low] - Council's overall confidence in this recommendation

DISSENTING_VIEWS: [Any important minority positions worth noting]

FINAL_VERDICT: [1-2 sentence summary of the council's recommendation]
EOF
}

# =============================================================================
# Discovery
# =============================================================================

discover_models() {
    local format="${1:-json}"

    local response
    response=$(curl -s --max-time 30 "$OPENROUTER_MODELS_API") || die "Failed to fetch models"

    # Filter to major providers
    local filtered
    filtered=$(echo "$response" | jq '[.data[] | select(.id | test("^(openai|anthropic|google|x-ai|meta-llama|mistralai)/"))]')

    if [[ "$format" == "json" ]]; then
        echo "$filtered" | jq '{
            total: length,
            providers: [.[].id | split("/")[0]] | unique,
            models: group_by(.id | split("/")[0]) | map({(.[0].id | split("/")[0]): .}) | add
        }'
    else
        print_header "Available Models (Major Providers)"
        local total
        total=$(echo "$filtered" | jq 'length')
        echo "Total: $total models"
        echo ""

        for provider in openai anthropic google x-ai meta-llama mistralai; do
            local provider_models
            provider_models=$(echo "$filtered" | jq -r --arg p "$provider" \
                '[.[] | select(.id | startswith($p + "/"))] | sort_by(.name)[:10][] |
                 "\(.id)\t\(.context_length // 0)\t\(.pricing.prompt // 0)"')

            if [[ -n "$provider_models" ]]; then
                echo -e "${BOLD}${provider^^}${NC}"
                echo "----------------------------------------------------------------------"
                while IFS=$'\t' read -r id ctx price; do
                    local ctx_k
                    if [[ "$ctx" -ge 1000 ]]; then
                        ctx_k="$((ctx / 1000))K"
                    else
                        ctx_k="$ctx"
                    fi
                    printf "  %-45s %8s ctx\n" "$id" "$ctx_k"
                done <<< "$provider_models"
                echo ""
            fi
        done
    fi
}

# =============================================================================
# Main Council Logic
# =============================================================================

run_council() {
    local question="$1"
    local council_csv="$2"
    local chairman="$3"
    local max_tokens="$4"
    local timeout="$5"

    # Parse council members
    IFS=',' read -ra council_input <<< "$council_csv"

    # Filter out chairman's provider from council to avoid self-review
    local chairman_provider
    chairman_provider="${chairman%%/*}"

    local council=()
    for model in "${council_input[@]}"; do
        local model_provider="${model%%/*}"
        if [[ "$model_provider" == "$chairman_provider" ]]; then
            warn "Excluding $model from council (same provider as chairman)"
        else
            council+=("$model")
        fi
    done

    if [[ ${#council[@]} -lt 2 ]]; then
        die "Need at least 2 council members after filtering. Add more models from different providers."
    fi

    # Create work directory
    WORK_DIR=$(mktemp -d "${TMPDIR}/council.XXXXXX")

    print_header "LLM Council Deliberation"
    echo -e "${CYAN}Question:${NC} $question"
    echo ""
    echo -e "${CYAN}Council Members:${NC}"
    local i=1
    for model in "${council[@]}"; do
        echo "  $i. $model"
        ((i++)) || true
    done
    echo -e "${CYAN}Chairman:${NC} $chairman"

    # =========================================================================
    # Stage 1: Individual Responses
    # =========================================================================
    print_header "Stage 1: Individual Responses"
    info "Querying council members in parallel..."

    local stage1_prompt
    stage1_prompt=$(build_stage1_prompt "$question")

    # Query each model (sequential for reliability)
    i=0
    for model in "${council[@]}"; do
        local short_name
        short_name=$(get_model_short_name "$model")
        echo -e "  Querying ${CYAN}$short_name${NC}..."
        call_model "$model" "$stage1_prompt" "$max_tokens" "$timeout" \
            "$WORK_DIR/stage1_$i.json" || true
        ((i++)) || true
    done

    # Collect successful responses
    local stage1_responses="$WORK_DIR/stage1_responses.jsonl"
    local success_count=0

    for f in "$WORK_DIR"/stage1_*.json; do
        [[ -f "$f" ]] || continue
        if ! jq -e '.error' "$f" >/dev/null 2>&1; then
            cat "$f" >> "$stage1_responses"
            echo "" >> "$stage1_responses"
            ((success_count++)) || true
        else
            local model_name error_msg
            model_name=$(basename "$f" .json | sed 's/stage1_//')
            error_msg=$(jq -r '.error' "$f")
            echo -e "${RED}[ERROR]${NC} Model $model_name: $error_msg"
        fi
    done

    if [[ $success_count -lt 2 ]]; then
        die "Insufficient responses for deliberation ($success_count/${#council[@]})"
    fi

    ok "Received $success_count/${#council[@]} responses"

    # Display Stage 1 responses
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        local model short_name content
        model=$(echo "$line" | jq -r '.model')
        short_name=$(get_model_short_name "$model")
        content=$(echo "$line" | jq -r '.content')
        print_subheader "$short_name ($model)"
        echo "$content"
    done < "$stage1_responses"

    # =========================================================================
    # Stage 2: Peer Review
    # =========================================================================
    print_header "Stage 2: Peer Review (Anonymized)"
    info "Council members reviewing anonymized responses..."

    local stage2_prompt
    stage2_prompt=$(build_stage2_prompt "$question" "$stage1_responses")

    # Get list of responding models
    local responding_models=()
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        responding_models+=("$(echo "$line" | jq -r '.model')")
    done < "$stage1_responses"

    # Query each model for review (sequential for reliability)
    i=0
    for model in "${responding_models[@]}"; do
        local short_name
        short_name=$(get_model_short_name "$model")
        echo -e "  ${CYAN}$short_name${NC} reviewing..."
        call_model "$model" "$stage2_prompt" "$max_tokens" "$timeout" \
            "$WORK_DIR/stage2_$i.json" || true
        ((i++)) || true
    done

    # Collect reviews
    local stage2_reviews="$WORK_DIR/stage2_reviews.jsonl"
    local review_count=0

    for f in "$WORK_DIR"/stage2_*.json; do
        [[ -f "$f" ]] || continue
        if ! jq -e '.error' "$f" >/dev/null 2>&1; then
            cat "$f" >> "$stage2_reviews"
            echo "" >> "$stage2_reviews"
            ((review_count++)) || true
        else
            local error_msg
            error_msg=$(jq -r '.error' "$f")
            echo -e "${RED}[ERROR]${NC} Review failed: $error_msg"
        fi
    done

    if [[ $review_count -lt 2 ]]; then
        warn "Limited peer reviews available ($review_count)"
    else
        ok "Received $review_count peer reviews"
    fi

    # Display Stage 2 reviews
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        local model short_name content
        model=$(echo "$line" | jq -r '.model')
        short_name=$(get_model_short_name "$model")
        content=$(echo "$line" | jq -r '.content')
        print_subheader "Review by $short_name"
        echo "$content"
    done < "$stage2_reviews"

    # =========================================================================
    # Stage 3: Chairman Synthesis
    # =========================================================================
    print_header "Stage 3: Chairman Synthesis"
    local chairman_short
    chairman_short=$(get_model_short_name "$chairman")
    info "Chairman ($chairman_short) synthesizing deliberations..."

    local stage3_prompt
    stage3_prompt=$(build_stage3_prompt "$question" "$stage1_responses" "$stage2_reviews")

    # Chairman gets more tokens
    local chairman_tokens=$((max_tokens * 2))

    call_model "$chairman" "$stage3_prompt" "$chairman_tokens" "$timeout" \
        "$WORK_DIR/stage3_chairman.json"

    if jq -e '.error' "$WORK_DIR/stage3_chairman.json" >/dev/null 2>&1; then
        local error_msg
        error_msg=$(jq -r '.error' "$WORK_DIR/stage3_chairman.json")
        echo -e "${RED}[ERROR]${NC} Chairman synthesis failed: $error_msg"
        echo ""
        warn "Falling back to summary of Stage 1 responses"
        return 1
    fi

    local synthesis
    synthesis=$(jq -r '.content' "$WORK_DIR/stage3_chairman.json")

    print_subheader "Chairman's Synthesis ($chairman_short)"
    echo "$synthesis"

    # =========================================================================
    # Summary
    # =========================================================================
    print_header "Council Deliberation Complete"
    echo -e "${GREEN}Council Members:${NC} $success_count/${#council[@]} participated"
    echo -e "${GREEN}Peer Reviews:${NC} $review_count completed"
    echo -e "${GREEN}Chairman:${NC} $chairman_short synthesized"
    echo ""

    return 0
}

# =============================================================================
# Main
# =============================================================================

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

LLM Council - Multi-model deliberative reasoning via OpenRouter

Options:
  -q, --question TEXT      Question for the council to deliberate (required)
  -n, --members N          Number of council members (default: $DEFAULT_MEMBERS)
  -c, --council MODELS     Comma-separated council members (overrides --members)
  --chairman MODEL         Chairman model for synthesis (default: $DEFAULT_CHAIRMAN)
  --max-tokens N           Max tokens per response (default: $DEFAULT_MAX_TOKENS)
  --timeout N              Request timeout in seconds (default: $DEFAULT_TIMEOUT)
  --discover               List available models from OpenRouter
  --format FORMAT          Output format for --discover: json|table (default: json)
  -h, --help               Show this help

Examples:
  $(basename "$0") --discover --format table
  $(basename "$0") -q "Should we use GraphQL or REST?" -n 5
  $(basename "$0") -q "Monorepo vs polyrepo?" -c "openai/gpt-4o,google/gemini-2.5-flash"
  $(basename "$0") -q "Best approach?" --chairman "anthropic/claude-opus-4" -n 4

Environment:
  OPENROUTER_API_KEY       Required for council deliberation (not for --discover)
EOF
}

main() {
    local question=""
    local council=""
    local members="$DEFAULT_MEMBERS"
    local chairman="$DEFAULT_CHAIRMAN"
    local max_tokens="$DEFAULT_MAX_TOKENS"
    local timeout="$DEFAULT_TIMEOUT"
    local discover=false
    local format="json"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q|--question)
                question="$2"
                shift 2
                ;;
            -n|--members)
                members="$2"
                shift 2
                ;;
            -c|--council)
                council="$2"
                shift 2
                ;;
            --chairman)
                chairman="$2"
                shift 2
                ;;
            --max-tokens)
                max_tokens="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --discover)
                discover=true
                shift
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    # Check for required tools
    command -v curl >/dev/null 2>&1 || die "curl is required but not installed"
    command -v jq >/dev/null 2>&1 || die "jq is required but not installed"

    # Handle --discover
    if [[ "$discover" == true ]]; then
        discover_models "$format"
        exit 0
    fi

    # Validate question
    if [[ -z "$question" ]]; then
        die "Question is required. Use -q 'your question' or --help for usage."
    fi

    # Check API key
    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        die "OPENROUTER_API_KEY environment variable not set.

Set it in your shell profile (~/.bashrc or ~/.zshrc):
  export OPENROUTER_API_KEY=\"sk-or-your-key-here\""
    fi

    # Load config file if exists
    local config_file="$HOME/.claude/config/council.json"
    if [[ -f "$config_file" ]]; then
        info "Loading config from $config_file"
        if [[ -z "$council" ]]; then
            local file_council
            file_council=$(jq -r '.council // empty | join(",")' "$config_file" 2>/dev/null)
            [[ -n "$file_council" ]] && council="$file_council"
        fi
        if [[ "$chairman" == "$DEFAULT_CHAIRMAN" ]]; then
            local file_chairman
            file_chairman=$(jq -r '.chairman // empty' "$config_file" 2>/dev/null)
            [[ -n "$file_chairman" ]] && chairman="$file_chairman"
        fi
    fi

    # Auto-select council members if not specified
    if [[ -z "$council" ]]; then
        council=$(select_council_members "$members" "$chairman")
        info "Auto-selected $members council members (excluding chairman's provider)"
    fi

    run_council "$question" "$council" "$chairman" "$max_tokens" "$timeout"
}

main "$@"
