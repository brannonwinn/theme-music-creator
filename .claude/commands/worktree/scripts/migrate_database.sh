#!/bin/bash

# migrate_database.sh - Run Alembic migrations for a worktree database
#
# Usage:
#   ./migrate_database.sh <color> [--verbose]
#
# Examples:
#   ./migrate_database.sh blue
#   ./migrate_database.sh red --verbose

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
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
    echo -e "${RED}Error: Missing color argument${NC}"
    echo "Usage: $0 <color> [--verbose]"
    exit 1
fi

# Validate color
if ! validate_color "$COLOR"; then
    exit 1
fi

# Functions (print functions from common.sh)
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}$1${NC}"
    fi
}

# Determine worktree path using common.sh function
WORKTREE_PATH=$(get_worktree_path "$COLOR")

# Check if worktree exists
if [ ! -d "$WORKTREE_PATH" ]; then
    print_error "Worktree for color '$COLOR' doesn't exist at: $WORKTREE_PATH"
    exit 1
fi

log_verbose "Worktree path: $WORKTREE_PATH"

# Load directory configuration
# Use backend_app_dir for .env files, backend_project_dir for running migrations
BACKEND_APP_DIR=$(get_backend_app_dir)
BACKEND_PROJECT_DIR=$(get_backend_project_dir)
log_verbose "Backend app directory: $BACKEND_APP_DIR"
log_verbose "Backend project directory: $BACKEND_PROJECT_DIR"

# Navigate to worktree
cd "$WORKTREE_PATH"

# Check if backend/.env exists
if [ ! -f "$BACKEND_APP_DIR/.env" ]; then
    print_error "$BACKEND_APP_DIR/.env not found"
    exit 1
fi

# Load worktree config to get database name
load_worktree_config "$COLOR"
DB_NAME="$DATABASE_NAME"

log_verbose "Database: $DB_NAME"

# Check if database exists using common.sh function
DB_STATUS=$(db_status "$DB_NAME")

if [ "$DB_STATUS" = "NOT_FOUND" ]; then
    print_error "Database '$DB_NAME' doesn't exist"
    echo ""
    echo "Create it first with:"
    echo "  /worktree_db_create $COLOR"
    exit 1
fi

log_verbose "Database exists: $DB_NAME (migration: $DB_STATUS)"

# Run Alembic migrations
log_verbose "Running Alembic migrations..."

# Run migrations from backend PROJECT directory (where pyproject.toml and alembic.ini are)
cd "$BACKEND_PROJECT_DIR"
if [ "$VERBOSE" = true ]; then
    uv run alembic upgrade head
else
    uv run alembic upgrade head > /dev/null 2>&1
fi

if [ $? -eq 0 ]; then
    print_success "Migrations completed for $DB_NAME"
else
    print_error "Migration failed"
    exit 1
fi
