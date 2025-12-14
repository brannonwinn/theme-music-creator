#!/bin/bash

# ensure_gitignore.sh - Ensure required .gitignore entries exist for worktree system
#
# Usage:
#   ./ensure_gitignore.sh [--silent]
#
# Options:
#   --silent    Don't print success messages (for use in scripts)
#
# This script adds required .gitignore entries if they're missing (idempotent).
# Safe to run multiple times - only adds missing entries.

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse arguments
SILENT=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --silent|-s)
            SILENT=true
            shift
            ;;
        *)
            echo "Error: Unknown option '$1'"
            echo "Usage: $0 [--silent]"
            exit 1
            ;;
    esac
done

# Get project root
PROJECT_ROOT="$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')"
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
fi
if [ -z "$PROJECT_ROOT" ]; then
    echo "Error: Not in a git repository"
    exit 1
fi

GITIGNORE="$PROJECT_ROOT/.gitignore"

# Required entries for worktree system
REQUIRED_ENTRIES=(
    "# Worktrees directory"
    "worktrees/"
    ""
    "# Generated worktree Celery Docker Compose files (from template)"
    "**/docker/docker-compose.celery.yml"
    "**/docker/Dockerfile.celery"
    ""
    "# Worktree-specific MCP configuration (unique Chrome debug ports per agent)"
    ".mcp.json"
)

# Function to check if entry exists in .gitignore
entry_exists() {
    local entry="$1"
    # Skip empty lines and comments when checking
    if [ -z "$entry" ] || [[ "$entry" =~ ^# ]]; then
        return 1  # Don't check these
    fi
    grep -qF "$entry" "$GITIGNORE" 2>/dev/null
}

# Function to log (unless silent)
log() {
    if [ "$SILENT" != "true" ]; then
        echo -e "$1"
    fi
}

# Main function
main() {
    # Create .gitignore if it doesn't exist
    if [ ! -f "$GITIGNORE" ]; then
        log "${YELLOW}Creating .gitignore file...${NC}"
        touch "$GITIGNORE"
    fi

    # First, check which entries are missing
    local missing_entries=()
    for entry in "${REQUIRED_ENTRIES[@]}"; do
        # Only check actual entries (not comments/empty lines)
        if [ -n "$entry" ] && [[ ! "$entry" =~ ^# ]]; then
            if ! entry_exists "$entry"; then
                missing_entries+=("$entry")
            else
                log "${CYAN}  ✓ Already present: $entry${NC}"
            fi
        fi
    done

    # If all entries exist, we're done
    if [ ${#missing_entries[@]} -eq 0 ]; then
        log "${GREEN}✅ All required .gitignore entries already present${NC}"
        return 0
    fi

    # Add missing entries with their comments
    log "${YELLOW}Adding ${#missing_entries[@]} missing .gitignore entries...${NC}"

    # Check if file ends with newline
    local needs_newline=false
    if [ -s "$GITIGNORE" ]; then
        if [ "$(tail -c 1 "$GITIGNORE" | wc -l)" -eq 0 ]; then
            needs_newline=true
            echo "" >> "$GITIGNORE"
        fi
    fi

    # Add all entries (including comments for context)
    for entry in "${REQUIRED_ENTRIES[@]}"; do
        echo "$entry" >> "$GITIGNORE"
        if [ -n "$entry" ] && [[ ! "$entry" =~ ^# ]]; then
            log "${GREEN}  + Added: $entry${NC}"
        fi
    done

    log ""
    log "${GREEN}✅ Added ${#missing_entries[@]} missing .gitignore entries${NC}"
    return 0
}

# Run main
main
