#!/bin/bash

# create_branch.sh - Create a feature branch in an existing worktree
#
# Usage:
#   ./create_branch.sh <color> <branch-name> [--verbose]
#
# Examples:
#   ./create_branch.sh blue feature/task-3a-1-1
#   ./create_branch.sh red feat/user-auth --verbose
#   ./create_branch.sh main feature/new-feature  # Works in main repo too
#
# Note: Can be run from any directory (main repo or worktree)

set -e

# Store original working directory (will restore at end)
ORIGINAL_CWD="$(pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse arguments
COLOR=""
BRANCH_NAME=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            if [ -z "$COLOR" ]; then
                COLOR="$1"
            elif [ -z "$BRANCH_NAME" ]; then
                BRANCH_NAME="$1"
            else
                echo -e "${RED}Error: Too many arguments${NC}"
                echo "Usage: $0 <color> <branch-name> [--verbose]"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$COLOR" ] || [ -z "$BRANCH_NAME" ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    echo "Usage: $0 <color> <branch-name> [--verbose]"
    exit 1
fi

# Source common.sh for utilities and auto-detection
# Note: common.sh sets MAIN_PROJECT_ROOT via git worktree list (works from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SH="$SCRIPT_DIR/common.sh"
if [ ! -f "$COMMON_SH" ]; then
    log_error "common.sh not found at: $COMMON_SH"
    exit 1
fi
source "$COMMON_SH"

# Add cleanup trap to restore original directory on exit
cleanup() {
    cd "$ORIGINAL_CWD" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Validate color (uses validate_agent under the hood, supports "main")
if ! validate_color "$COLOR"; then
    exit 1
fi

# Functions
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}$1${NC}"
    fi
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Get worktree path using common.sh utility (works for main and colored worktrees)
WORKTREE_PATH=$(get_worktree_path "$COLOR")
log_verbose "Target worktree path: $WORKTREE_PATH"

# For colored worktrees, verify it exists
if [ "$COLOR" != "main" ]; then
    if [ ! -d "$WORKTREE_PATH" ]; then
        PROJECT_NAME=$(get_project_name)
        if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "null" ]; then
            log_warning "PROJECT_NAME not found in config, using default: agent_observer"
            PROJECT_NAME="agent_observer"
        fi
        log_error "Worktree ${PROJECT_NAME}_${COLOR} doesn't exist"
        echo ""
        echo "Create it first with:"
        echo "  /worktree:wt_create $COLOR"
        exit 1
    fi
    log_verbose "Found worktree at: $WORKTREE_PATH"
fi

# Determine base branch and target directory based on color
if [ "$COLOR" = "main" ]; then
    BASE_BRANCH="main"
    TARGET_DISPLAY="main repository"
else
    BASE_BRANCH="$COLOR"
    TARGET_DISPLAY="${COLOR} worktree"
fi

# Get current branch (without changing directories)
CURRENT_BRANCH=$(git -C "$WORKTREE_PATH" branch --show-current)
log_verbose "Current branch in $TARGET_DISPLAY: $CURRENT_BRANCH"

# Sync base branch with main (skip if already on main)
if [ "$COLOR" != "main" ]; then
    log_verbose "Syncing ${COLOR} branch with main..."

    # Stash if there are uncommitted changes
    if ! git -C "$WORKTREE_PATH" diff-index --quiet HEAD --; then
        log_warning "Uncommitted changes detected in $TARGET_DISPLAY, stashing..."
        git -C "$WORKTREE_PATH" stash push -m "create_branch.sh auto-stash $(date +%Y-%m-%d_%H:%M:%S)"
    fi

    # Checkout color branch (blue/red/white)
    log_verbose "Checking out ${COLOR} branch..."
    git -C "$WORKTREE_PATH" checkout "$COLOR"

    # Pull latest from main to sync color branch
    log_verbose "Pulling latest from main to sync ${COLOR} branch..."
    if git -C "$WORKTREE_PATH" pull origin main --rebase; then
        log_verbose "Successfully synced ${COLOR} with main"
    else
        log_error "Failed to sync ${COLOR} with main"
        exit 1
    fi
fi

# Create new feature branch from base branch
log_verbose "Creating feature branch: $BRANCH_NAME from ${BASE_BRANCH}..."
if git -C "$WORKTREE_PATH" checkout -b "$BRANCH_NAME"; then
    log_success "Branch '$BRANCH_NAME' created successfully from ${BASE_BRANCH}"
else
    log_error "Failed to create branch '$BRANCH_NAME'"
    echo ""
    echo "Branch may already exist. Check with:"
    echo "  git -C $WORKTREE_PATH branch"
    exit 1
fi

# Get ports from config (common.sh already sourced earlier for validation)
BACKEND_PORT=$(get_service_port "$COLOR" "backend")
FRONTEND_PORT=$(get_service_port "$COLOR" "frontend")

# Get project name for display
PROJECT_NAME=$(get_project_name)
if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "null" ]; then
    log_warning "PROJECT_NAME not found in config, using default: agent_observer"
    PROJECT_NAME="agent_observer"
fi

# Success summary
echo ""
log_success "Ready to work!"
echo ""
if [ "$COLOR" = "main" ]; then
    echo -e "${CYAN}Location:${NC} Main Repository"
else
    echo -e "${CYAN}Worktree:${NC} ${PROJECT_NAME}_${COLOR}"
fi
echo -e "${CYAN}Branch:${NC} $BRANCH_NAME"
echo -e "${CYAN}Path:${NC} $WORKTREE_PATH"
echo ""
echo -e "${CYAN}Service URLs:${NC}"
echo "  Backend:  http://localhost:${BACKEND_PORT}"
echo "  Frontend: http://localhost:${FRONTEND_PORT}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
if [ "$COLOR" = "main" ] && [ "$WORKTREE_PATH" != "$ORIGINAL_CWD" ]; then
    echo "  1. cd $WORKTREE_PATH  # (optional - already on correct branch)"
elif [ "$COLOR" != "main" ]; then
    echo "  1. cd $WORKTREE_PATH"
fi
echo "  2. Start coding"
echo "  3. When done:"
echo "     git push origin $BRANCH_NAME"
echo "     Create PR: $BRANCH_NAME → main"
echo ""
echo -e "${YELLOW}Note:${NC} Your shell remains in: $ORIGINAL_CWD"
