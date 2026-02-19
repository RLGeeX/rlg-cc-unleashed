#!/usr/bin/env bash
#
# CC-Unleashed Memory Integration Setup
#
# Run once per machine to register the Memorizer MCP server with Claude Code.
# After running, restart Claude Code for the MCP server to be available.
#
# Memorizer: https://memorizer.rlgeex.com/mcp (Streamable HTTP / SSE transport)
# Deployed on: rlg-k8s-lab homelab cluster (Petabridge Memorizer v2.0.0)
#
# Usage:
#   ./scripts/setup-memory.sh          # Register and set up
#   ./scripts/setup-memory.sh --check  # Check if already registered
#   ./scripts/setup-memory.sh --remove # Remove registration
#

set -euo pipefail

MEMORIZER_NAME="memorizer"
MEMORIZER_URL="https://memorizer.rlgeex.com/mcp"
CACHE_FILE="${HOME}/.claude/memorizer-project-cache.json"

# ── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }

# ── Check mode ──────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--check" ]]; then
    echo "Checking Memorizer integration..."

    # Check MCP registration
    if claude mcp list 2>/dev/null | grep -q "$MEMORIZER_NAME"; then
        ok "MCP server '$MEMORIZER_NAME' is registered (user scope — global)"
    else
        fail "MCP server '$MEMORIZER_NAME' is NOT registered — run setup-memory.sh"
        exit 1
    fi

    # Check connectivity
    if curl -s --max-time 3 -X POST "$MEMORIZER_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' \
        2>/dev/null | grep -q '"result"'; then
        ok "Memorizer endpoint is reachable: $MEMORIZER_URL"
    else
        fail "Memorizer endpoint is unreachable: $MEMORIZER_URL"
        exit 1
    fi

    # Check cache
    if [[ -f "$CACHE_FILE" ]]; then
        count=$(jq 'length' "$CACHE_FILE" 2>/dev/null || echo "0")
        ok "Project ID cache exists ($count entries)"
    else
        warn "Project ID cache not yet created (will populate on first use)"
    fi

    echo ""
    ok "Memorizer integration is ready"
    exit 0
fi

# ── Remove mode ─────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--remove" ]]; then
    echo "Removing Memorizer integration..."
    if claude mcp remove --scope user "$MEMORIZER_NAME" 2>/dev/null; then
        ok "Removed MCP server '$MEMORIZER_NAME' (user scope)"
    else
        warn "MCP server '$MEMORIZER_NAME' was not registered at user scope"
    fi
    exit 0
fi

# ── Setup ────────────────────────────────────────────────────────────────────

echo "Setting up CC-Unleashed Memory Integration"
echo "=========================================="
echo ""

# 1. Check if already registered
if claude mcp list 2>/dev/null | grep -q "$MEMORIZER_NAME"; then
    ok "MCP server '$MEMORIZER_NAME' already registered — skipping"
else
    echo "Registering Memorizer MCP server..."
    # --scope user = global registration (available in all projects)
    # default 'local' scope only activates in the cwd project
    if claude mcp add --scope user --transport http "$MEMORIZER_NAME" "$MEMORIZER_URL" 2>/dev/null; then
        ok "Registered MCP server: $MEMORIZER_NAME → $MEMORIZER_URL (user scope)"
    else
        # Fallback: direct JSON edit of ~/.claude/settings.json
        warn "'claude mcp add' failed — falling back to direct settings edit"
        SETTINGS="${HOME}/.claude/settings.json"
        if [[ -f "$SETTINGS" ]]; then
            # Add mcpServers entry if not present
            if jq -e '.mcpServers.memorizer' "$SETTINGS" >/dev/null 2>&1; then
                ok "MCP server already present in settings.json"
            else
                jq --arg url "$MEMORIZER_URL" \
                    '.mcpServers = (.mcpServers // {}) | .mcpServers.memorizer = {type:"http",url:$url}' \
                    "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
                ok "Added memorizer to ~/.claude/settings.json"
            fi
        else
            fail "~/.claude/settings.json not found — please register manually:"
            echo "  claude mcp add memorizer --transport http $MEMORIZER_URL"
            exit 1
        fi
    fi
fi

# 2. Verify connectivity
echo ""
echo "Verifying Memorizer connectivity..."
if curl -s --max-time 5 -X POST "$MEMORIZER_URL" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' \
    2>/dev/null | grep -q '"result"'; then
    ok "Memorizer is reachable at $MEMORIZER_URL"
else
    warn "Memorizer unreachable — ensure you are on the home network or VPN"
    warn "The MCP server is registered but hooks will degrade gracefully when offline"
fi

# 3. Create cache dir
mkdir -p "$(dirname "$CACHE_FILE")"
ok "Cache directory ready: $(dirname "$CACHE_FILE")"

# 4. Summary
echo ""
echo "=========================================="
ok "Setup complete"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code for the MCP server to load"
echo "  2. Use /memorize at the end of sessions to store knowledge"
echo "  3. The memory-retrieval hook will auto-inject context on every prompt"
echo ""
echo "Verify with: ./scripts/setup-memory.sh --check"
