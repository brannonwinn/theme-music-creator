#!/bin/bash

# install_deps.sh - Install Python and Node dependencies in worktree
#
# Usage:
#   ./install_deps.sh <color> [--verbose]
#
# Examples:
#   ./install_deps.sh blue
#   ./install_deps.sh red --verbose

set -e

# Source common configuration and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Parse arguments
COLOR=""
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
            else
                echo -e "${RED}Error: Too many arguments${NC}"
                echo "Usage: $0 <color> [--verbose]"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$COLOR" ]; then
    print_error "Missing color argument"
    echo "Usage: $0 <color> [--verbose]"
    exit 1
fi

# Validate color
validate_color "$COLOR"

# Functions
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}$1${NC}"
    fi
}

# Get worktree path using common function
WORKTREE_PATH=$(get_worktree_path "$COLOR")

# Check if worktree exists
if [ ! -d "$WORKTREE_PATH" ]; then
    print_error "Worktree for color '$COLOR' doesn't exist at: $WORKTREE_PATH"
    exit 1
fi

log_verbose "Worktree path: $WORKTREE_PATH"

# Load directory configuration
# Use backend_project_dir for dependency installation (where pyproject.toml is)
BACKEND_PROJECT_DIR=$(get_backend_project_dir)
FRONTEND_DIR=$(get_frontend_dir "$WORKTREE_PATH")

log_verbose "Backend project directory (for dependencies): $BACKEND_PROJECT_DIR"
log_verbose "Frontend directory: $FRONTEND_DIR"

# Ensure we use the worktree's virtual environment
export VIRTUAL_ENV="$WORKTREE_PATH/.venv"
export PATH="$VIRTUAL_ENV/bin:$PATH"

cd "$WORKTREE_PATH"

# Install Python dependencies from backend PROJECT directory (where pyproject.toml is)
if [ -d "$BACKEND_PROJECT_DIR" ]; then
    log_verbose "Installing Python dependencies in $BACKEND_PROJECT_DIR..."

    cd "$BACKEND_PROJECT_DIR"
    if [ "$VERBOSE" = true ]; then
        uv sync
    else
        uv sync > /dev/null 2>&1
    fi

    if [ $? -eq 0 ]; then
        print_success "Python dependencies installed ($BACKEND_PROJECT_DIR)"
    else
        print_error "Failed to install Python dependencies"
        exit 1
    fi
    cd "$WORKTREE_PATH"
else
    log_verbose "Backend project directory not found: $BACKEND_PROJECT_DIR, skipping Python dependencies"
    print_warning "Backend project directory not found: $BACKEND_PROJECT_DIR"
fi

# Install Node dependencies for frontend (Next.js)
if [ -d "$FRONTEND_DIR" ]; then
    log_verbose "Installing frontend dependencies in $FRONTEND_DIR..."

    cd "$FRONTEND_DIR"
    if [ "$VERBOSE" = true ]; then
        npm install
    else
        npm install > /dev/null 2>&1
    fi

    if [ $? -eq 0 ]; then
        print_success "Frontend dependencies installed ($FRONTEND_DIR)"
    else
        print_error "Failed to install frontend dependencies"
        exit 1
    fi
    cd ..
else
    log_verbose "Frontend directory not found: $FRONTEND_DIR, skipping frontend dependencies"
fi

print_success "All dependencies installed"
