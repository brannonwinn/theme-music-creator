#!/bin/bash

# health_check.sh - Test service connectivity for a worktree
#
# Usage:
#   ./health_check.sh <color> [--verbose]
#
# Examples:
#   ./health_check.sh blue
#   ./health_check.sh red --verbose

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

# Get worktree path
WORKTREE_PATH=$(get_worktree_path "$COLOR")

# Check if worktree exists
if [ ! -d "$WORKTREE_PATH" ]; then
    print_error "Worktree for color '$COLOR' doesn't exist at: $WORKTREE_PATH"
    exit 1
fi

log_verbose "Worktree path: $WORKTREE_PATH"

cd "$WORKTREE_PATH"

# Load configuration (sets BACKEND_PORT, FRONTEND_PORT, DATABASE_NAME)
load_worktree_config "$COLOR"

# Load directory configuration
FRONTEND_DIR=$(get_frontend_dir "$WORKTREE_PATH")
log_verbose "Frontend directory: $FRONTEND_DIR"

HEALTH_FAILED=false

# Test backend
log_verbose "Testing backend at http://localhost:${BACKEND_PORT}/v1/admin/health..."

if curl -s -f "http://localhost:${BACKEND_PORT}/v1/admin/health" > /dev/null 2>&1; then
    print_success "Backend healthy (port ${BACKEND_PORT})"
else
    print_error "Backend not responding (port ${BACKEND_PORT})"
    HEALTH_FAILED=true
fi

# Test frontend (if frontend directory exists)
if [ -d "$FRONTEND_DIR" ]; then
    log_verbose "Testing frontend at http://localhost:${FRONTEND_PORT}..."

    if curl -s -f "http://localhost:${FRONTEND_PORT}" > /dev/null 2>&1; then
        print_success "Frontend healthy (port ${FRONTEND_PORT})"
    else
        print_error "Frontend not responding (port ${FRONTEND_PORT})"
        HEALTH_FAILED=true
    fi
else
    log_verbose "Frontend directory not found: $FRONTEND_DIR, skipping frontend health check"
fi

# Test database using Docker exec (more reliable than psql command)
log_verbose "Testing database connection via Docker..."

# Detect Supabase container dynamically
DB_CONTAINER=$(detect_supabase_container)
if [ -z "$DB_CONTAINER" ]; then
    print_error "Supabase container not found"
    HEALTH_FAILED=true
else
    # Use DATABASE_NAME from loaded config
    if docker exec -i "$DB_CONTAINER" psql -U postgres -d "$DATABASE_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
        print_success "Database connection successful ($DATABASE_NAME)"
    else
        print_error "Database connection failed ($DATABASE_NAME)"
        HEALTH_FAILED=true
    fi
fi

# Test Redis
log_verbose "Testing Redis connection..."

if is_redis_available; then
    print_success "Redis connection successful (shared service)"
else
    print_error "Redis connection failed (shared service)"
    HEALTH_FAILED=true
fi

# Summary
echo ""
if [ "$HEALTH_FAILED" = true ]; then
    print_error "Health check failed"
    echo ""
    echo "Troubleshoot with:"
    echo "  tail -f logs/fastapi_${COLOR}.log"
    echo "  ./.claude/commands/worktree/scripts/start_worktree.sh $COLOR"
    exit 1
else
    print_success "All services healthy"
fi
