#!/bin/bash
#
# consensus.sh - Query multiple AI models via OpenRouter and compare responses
#
# Usage: consensus.sh "Your question here"
#
# Configuration (in order of priority):
#   1. Environment variables: CONSENSUS_MODEL_1, CONSENSUS_MODEL_2, CONSENSUS_MODEL_3
#   2. Config file: .claude/config/consensus.json
#   3. Defaults: openai/gpt-4o, google/gemini-pro-1.5, x-ai/grok-2
#
# Required: OPENROUTER_API_KEY environment variable
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default models
DEFAULT_MODEL_1="openai/gpt-4o-mini"
DEFAULT_MODEL_2="google/gemini-2.5-flash"
DEFAULT_MODEL_3="x-ai/grok-4-fast"

# OpenRouter API endpoint
OPENROUTER_API="https://openrouter.ai/api/v1/chat/completions"

# Temp directory for responses
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ============================================================================
# Configuration Loading
# ============================================================================

load_config() {
    # Check for API key
    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        log_error "OPENROUTER_API_KEY environment variable is not set"
        echo ""
        echo "To set it, add to your shell profile (~/.bashrc or ~/.zshrc):"
        echo "  export OPENROUTER_API_KEY=\"sk-or-your-key-here\""
        exit 1
    fi

    # Load models from config file if it exists
    CONFIG_FILE="${HOME}/.claude/config/consensus.json"
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading config from $CONFIG_FILE"
        if command -v jq &> /dev/null; then
            CONFIG_MODEL_1=$(jq -r '.models[0] // empty' "$CONFIG_FILE" 2>/dev/null || echo "")
            CONFIG_MODEL_2=$(jq -r '.models[1] // empty' "$CONFIG_FILE" 2>/dev/null || echo "")
            CONFIG_MODEL_3=$(jq -r '.models[2] // empty' "$CONFIG_FILE" 2>/dev/null || echo "")
            MAX_TOKENS=$(jq -r '.max_tokens // 500' "$CONFIG_FILE" 2>/dev/null || echo "500")
            TIMEOUT_SECS=$(jq -r '.timeout_seconds // 60' "$CONFIG_FILE" 2>/dev/null || echo "60")
        else
            log_warning "jq not installed, using defaults (install jq to use config file)"
            CONFIG_MODEL_1=""
            CONFIG_MODEL_2=""
            CONFIG_MODEL_3=""
            MAX_TOKENS=500
            TIMEOUT_SECS=60
        fi
    else
        CONFIG_MODEL_1=""
        CONFIG_MODEL_2=""
        CONFIG_MODEL_3=""
        MAX_TOKENS=500
        TIMEOUT_SECS=60
    fi

    # Priority: ENV > Config > Default
    MODEL_1="${CONSENSUS_MODEL_1:-${CONFIG_MODEL_1:-$DEFAULT_MODEL_1}}"
    MODEL_2="${CONSENSUS_MODEL_2:-${CONFIG_MODEL_2:-$DEFAULT_MODEL_2}}"
    MODEL_3="${CONSENSUS_MODEL_3:-${CONFIG_MODEL_3:-$DEFAULT_MODEL_3}}"
}

# ============================================================================
# API Call Functions
# ============================================================================

build_prompt() {
    local question="$1"
    cat <<EOF
You are participating in a multi-model consensus process. Answer the following question concisely and clearly.

IMPORTANT: Structure your response EXACTLY as follows:

RECOMMENDATION: [Your specific recommendation or answer in one sentence]
CONFIDENCE: [high/medium/low]
REASONING: [2-3 sentences explaining your reasoning]

Question: $question
EOF
}

call_model() {
    local model="$1"
    local question="$2"
    local output_file="$3"
    local prompt
    prompt=$(build_prompt "$question")

    # Escape the prompt for JSON
    local escaped_prompt
    escaped_prompt=$(echo "$prompt" | jq -Rs .)

    # Build request body
    local request_body
    request_body=$(cat <<EOF
{
  "model": "$model",
  "max_tokens": $MAX_TOKENS,
  "messages": [
    {
      "role": "user",
      "content": $escaped_prompt
    }
  ]
}
EOF
)

    # Make API call
    local http_code
    http_code=$(curl -s -w "%{http_code}" -o "$output_file" \
        --max-time "$TIMEOUT_SECS" \
        -X POST "$OPENROUTER_API" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -H "HTTP-Referer: https://github.com/rlgeex/rlg-cc-unleashed" \
        -H "X-Title: CC-Unleashed Consensus" \
        -d "$request_body" 2>/dev/null || echo "000")

    # Check response
    if [[ "$http_code" != "200" ]]; then
        echo "{\"error\": \"HTTP $http_code\", \"model\": \"$model\"}" > "$output_file"
        return 1
    fi

    return 0
}

# ============================================================================
# Response Parsing
# ============================================================================

extract_response() {
    local file="$1"
    local model="$2"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: No response file"
        return 1
    fi

    # Check for error in response
    if jq -e '.error' "$file" &>/dev/null; then
        local error_msg
        error_msg=$(jq -r '.error.message // .error // "Unknown error"' "$file")
        echo "ERROR: $error_msg"
        return 1
    fi

    # Extract content from OpenRouter response
    local content
    content=$(jq -r '.choices[0].message.content // empty' "$file" 2>/dev/null)

    if [[ -z "$content" ]]; then
        echo "ERROR: Empty response"
        return 1
    fi

    echo "$content"
}

extract_recommendation() {
    local response="$1"
    echo "$response" | grep -i "^RECOMMENDATION:" | sed 's/^RECOMMENDATION:[[:space:]]*//' | head -1
}

extract_confidence() {
    local response="$1"
    echo "$response" | grep -i "^CONFIDENCE:" | sed 's/^CONFIDENCE:[[:space:]]*//' | head -1 | tr '[:upper:]' '[:lower:]'
}

extract_reasoning() {
    local response="$1"
    echo "$response" | grep -i "^REASONING:" | sed 's/^REASONING:[[:space:]]*//' | head -1
}

# ============================================================================
# Consensus Analysis
# ============================================================================

get_model_short_name() {
    local model="$1"
    case "$model" in
        *gpt*) echo "GPT" ;;
        *gemini*) echo "Gemini" ;;
        *grok*) echo "Grok" ;;
        *claude*) echo "Claude" ;;
        *llama*) echo "Llama" ;;
        *mistral*) echo "Mistral" ;;
        *) echo "${model##*/}" ;;
    esac
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: consensus.sh \"Your question here\""
        echo ""
        echo "Environment variables:"
        echo "  OPENROUTER_API_KEY     - Required: Your OpenRouter API key"
        echo "  CONSENSUS_MODEL_1      - Optional: First model (default: openai/gpt-4o-mini)"
        echo "  CONSENSUS_MODEL_2      - Optional: Second model (default: google/gemini-2.5-flash)"
        echo "  CONSENSUS_MODEL_3      - Optional: Third model (default: x-ai/grok-4-fast)"
        exit 1
    fi

    local question="$1"

    # Load configuration
    load_config

    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  AI Consensus Query${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Question:${NC} $question"
    echo ""
    echo -e "${CYAN}Models:${NC}"
    echo "  1. $MODEL_1"
    echo "  2. $MODEL_2"
    echo "  3. $MODEL_3"
    echo ""

    # Query all models in parallel
    log_info "Querying models in parallel..."
    echo ""

    call_model "$MODEL_1" "$question" "$TEMP_DIR/response1.json" &
    local pid1=$!

    call_model "$MODEL_2" "$question" "$TEMP_DIR/response2.json" &
    local pid2=$!

    call_model "$MODEL_3" "$question" "$TEMP_DIR/response3.json" &
    local pid3=$!

    # Wait for all to complete
    local status1=0 status2=0 status3=0
    wait $pid1 || status1=$?
    wait $pid2 || status2=$?
    wait $pid3 || status3=$?

    # Extract responses
    local response1 response2 response3
    response1=$(extract_response "$TEMP_DIR/response1.json" "$MODEL_1")
    response2=$(extract_response "$TEMP_DIR/response2.json" "$MODEL_2")
    response3=$(extract_response "$TEMP_DIR/response3.json" "$MODEL_3")

    # Track successful responses
    local successful=0
    local failed_models=""

    # Display individual responses
    echo -e "${BOLD}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}  Individual Responses${NC}"
    echo -e "${BOLD}───────────────────────────────────────────────────────────────${NC}"
    echo ""

    local name1 name2 name3
    name1=$(get_model_short_name "$MODEL_1")
    name2=$(get_model_short_name "$MODEL_2")
    name3=$(get_model_short_name "$MODEL_3")

    # Model 1
    echo -e "${GREEN}[$name1]${NC} ($MODEL_1)"
    if [[ "$response1" == ERROR:* ]]; then
        echo -e "  ${RED}$response1${NC}"
        failed_models="$failed_models $name1"
    else
        successful=$((successful + 1))
        local rec1 conf1 reason1
        rec1=$(extract_recommendation "$response1")
        conf1=$(extract_confidence "$response1")
        reason1=$(extract_reasoning "$response1")
        echo "  Recommendation: ${rec1:-N/A}"
        echo "  Confidence: ${conf1:-N/A}"
        echo "  Reasoning: ${reason1:-N/A}"
    fi
    echo ""

    # Model 2
    echo -e "${YELLOW}[$name2]${NC} ($MODEL_2)"
    if [[ "$response2" == ERROR:* ]]; then
        echo -e "  ${RED}$response2${NC}"
        failed_models="$failed_models $name2"
    else
        successful=$((successful + 1))
        local rec2 conf2 reason2
        rec2=$(extract_recommendation "$response2")
        conf2=$(extract_confidence "$response2")
        reason2=$(extract_reasoning "$response2")
        echo "  Recommendation: ${rec2:-N/A}"
        echo "  Confidence: ${conf2:-N/A}"
        echo "  Reasoning: ${reason2:-N/A}"
    fi
    echo ""

    # Model 3
    echo -e "${BLUE}[$name3]${NC} ($MODEL_3)"
    if [[ "$response3" == ERROR:* ]]; then
        echo -e "  ${RED}$response3${NC}"
        failed_models="$failed_models $name3"
    else
        successful=$((successful + 1))
        local rec3 conf3 reason3
        rec3=$(extract_recommendation "$response3")
        conf3=$(extract_confidence "$response3")
        reason3=$(extract_reasoning "$response3")
        echo "  Recommendation: ${rec3:-N/A}"
        echo "  Confidence: ${conf3:-N/A}"
        echo "  Reasoning: ${reason3:-N/A}"
    fi
    echo ""

    # Summary
    echo -e "${BOLD}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}  Summary${NC}"
    echo -e "${BOLD}───────────────────────────────────────────────────────────────${NC}"
    echo ""

    if [[ $successful -lt 2 ]]; then
        log_error "Insufficient responses for consensus ($successful/3 succeeded)"
        if [[ -n "$failed_models" ]]; then
            echo "  Failed models:$failed_models"
        fi
        exit 1
    fi

    echo "  Successful responses: $successful/3"
    if [[ -n "$failed_models" ]]; then
        echo -e "  Failed models:${RED}$failed_models${NC}"
    fi
    echo ""
    echo -e "${CYAN}Note:${NC} Review the recommendations above. Look for:"
    echo "  - Agreement on approach (consensus)"
    echo "  - Confidence levels (weight high-confidence responses more)"
    echo "  - Different perspectives that may inform your decision"
    echo ""
}

main "$@"
