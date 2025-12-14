#!/bin/bash

# detect_worktree.sh - Detect current worktree context and output environment variables
#
# Usage:
#   source <(./.claude/commands/worktree/scripts/detect_worktree.sh)
#
# Outputs:
#   WORKTREE_COLOR - Detected agent/color
#   WORKTREE_PATH - Absolute path to current worktree
#   WORKTREE_BRANCH - Current git branch
#   PROJECT_NAME - Project name from config
#   DATABASE_NAME - Database name for this worktree
#   AI_DOCS_DIR - AI documentation directory (from config or auto-detected)
#   REVIEW_BASE_DIR - Base directory for reviews (${AI_DOCS_DIR}/reviews)

set -e

# Source common configuration for centralized functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh" 2>/dev/null || true

# Get absolute path to current directory
WORKTREE_PATH="$(pwd)"

# Detect worktree color using centralized function
WORKTREE_COLOR=$(detect_agent_color)

# Get PROJECT_NAME from config (centralized function)
PROJECT_NAME=$(get_project_name 2>/dev/null)

# Fallback if PROJECT_NAME not found (with warning)
if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "null" ]; then
    echo "WARNING: PROJECT_NAME not found in config, using directory name" >&2
    PROJECT_NAME=$(basename "$(pwd)")
fi

# Get current git branch
WORKTREE_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

# Construct database name
if [ "$WORKTREE_COLOR" = "main" ]; then
    DATABASE_NAME="$PROJECT_NAME"
else
    DATABASE_NAME="${PROJECT_NAME}_${WORKTREE_COLOR}"
fi

# Set AI docs directory (from config or auto-detected)
AI_DOCS_DIR=$(get_ai_docs_dir)

# Set review base directory (relative to AI docs)
REVIEW_BASE_DIR="${AI_DOCS_DIR}/reviews"

# Output as environment variables for sourcing
echo "export WORKTREE_COLOR=\"$WORKTREE_COLOR\""
echo "export WORKTREE_PATH=\"$WORKTREE_PATH\""
echo "export WORKTREE_BRANCH=\"$WORKTREE_BRANCH\""
echo "export PROJECT_NAME=\"$PROJECT_NAME\""
echo "export DATABASE_NAME=\"$DATABASE_NAME\""
echo "export AI_DOCS_DIR=\"$AI_DOCS_DIR\""
echo "export REVIEW_BASE_DIR=\"$REVIEW_BASE_DIR\""
