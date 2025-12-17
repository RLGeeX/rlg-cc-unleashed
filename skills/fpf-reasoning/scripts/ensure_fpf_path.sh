#!/usr/bin/env bash
#
# ensure_fpf_path.sh - Ensure FPF files are stored in .claude/fpf/
#
# This script:
# 1. Creates .claude/fpf/ directory structure
# 2. Migrates any existing .fpf/ content to .claude/fpf/
# 3. Creates symlink .fpf -> .claude/fpf for Quint Code compatibility
#
# Run this BEFORE any /q* command to ensure correct path structure.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Create .claude/fpf directory structure
create_fpf_structure() {
    log_info "Ensuring .claude/fpf/ directory structure..."

    mkdir -p .claude/fpf/knowledge/{L0,L1,L2,invalid}
    mkdir -p .claude/fpf/evidence
    mkdir -p .claude/fpf/decisions
    mkdir -p .claude/fpf/sessions

    log_info "Directory structure created: .claude/fpf/"
}

# Step 2: Migrate existing .fpf/ content if it exists (and is not a symlink)
migrate_existing_fpf() {
    if [ -d ".fpf" ] && [ ! -L ".fpf" ]; then
        log_warn "Found existing .fpf/ directory (not symlink). Migrating to .claude/fpf/..."

        # Copy contents without overwriting existing files
        cp -rn .fpf/* .claude/fpf/ 2>/dev/null || true

        # Remove the old directory
        rm -rf .fpf

        log_info "Migration complete. Old .fpf/ removed."
    fi
}

# Step 3: Create symlink for Quint Code compatibility
create_symlink() {
    if [ -L ".fpf" ]; then
        # Symlink already exists - verify it points to correct location
        local target
        target=$(readlink .fpf)
        if [ "$target" = ".claude/fpf" ]; then
            log_info "Symlink .fpf -> .claude/fpf already exists and is correct."
        else
            log_warn "Symlink .fpf exists but points to '$target'. Fixing..."
            rm .fpf
            ln -s .claude/fpf .fpf
            log_info "Symlink updated: .fpf -> .claude/fpf"
        fi
    elif [ -e ".fpf" ]; then
        log_error ".fpf exists but is not a symlink or directory. Please remove it manually."
        exit 1
    else
        ln -s .claude/fpf .fpf
        log_info "Symlink created: .fpf -> .claude/fpf"
    fi
}

# Step 4: Verify structure
verify_structure() {
    local errors=0

    # Check directory exists
    if [ ! -d ".claude/fpf" ]; then
        log_error ".claude/fpf/ directory not found"
        errors=$((errors + 1))
    fi

    # Check symlink exists and is correct
    if [ ! -L ".fpf" ]; then
        log_error ".fpf symlink not found"
        errors=$((errors + 1))
    else
        local target
        target=$(readlink .fpf)
        if [ "$target" != ".claude/fpf" ]; then
            log_error ".fpf symlink points to wrong target: $target"
            errors=$((errors + 1))
        fi
    fi

    if [ $errors -eq 0 ]; then
        log_info "Verification passed. FPF path structure is correct."
        echo ""
        echo "Structure:"
        echo "  .claude/fpf/     <- FPF artifacts stored here"
        echo "  .fpf             -> .claude/fpf (symlink for Quint Code)"
        return 0
    else
        log_error "Verification failed with $errors error(s)"
        return 1
    fi
}

# Main
main() {
    echo "=== FPF Path Setup for CC Unleashed ==="
    echo ""

    create_fpf_structure
    migrate_existing_fpf
    create_symlink

    echo ""
    verify_structure
}

main "$@"
