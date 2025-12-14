#!/bin/bash

# status.sh - Show detailed status for a single worktree
#
# Usage:
#   ./status.sh <color> [--verbose]
#
# Examples:
#   ./status.sh blue
#   ./status.sh red --verbose

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

# Load PROJECT_NAME using centralized function from common.sh
PROJECT_NAME=$(get_project_name)

if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "null" ]; then
    print_warning "PROJECT_NAME not found in config, using default: agent_observer"
    PROJECT_NAME="agent_observer"
fi

# Determine worktree path
if [ "$COLOR" = "main" ]; then
    WORKTREE_PATH="$PROJECT_ROOT"
else
    WORKTREE_PATH="$PROJECT_ROOT/worktrees/${PROJECT_NAME}_${COLOR}"
fi

# Check if worktree exists
if [ ! -d "$WORKTREE_PATH" ]; then
    echo -e "${RED}❌ Worktree ${PROJECT_NAME}_${COLOR} doesn't exist${NC}"
    exit 1
fi

# Load directory configuration
BACKEND_DIR=$(get_backend_dir "$WORKTREE_PATH")
FRONTEND_DIR=$(get_frontend_dir "$WORKTREE_PATH")

cd "$WORKTREE_PATH"

# Get emoji for color
case "$COLOR" in
    blue) EMOJI="🔵" ;;
    red) EMOJI="🔴" ;;
    white) EMOJI="⚪" ;;
    main) EMOJI="🏠" ;;
esac

# Get ports using centralized utility from common.sh
BACKEND_PORT=$(get_service_port "$COLOR" "backend")
FRONTEND_PORT=$(get_service_port "$COLOR" "frontend")

# Header
COLOR_UPPER=$(echo "$COLOR" | tr '[:lower:]' '[:upper:]')
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  ${EMOJI} ${COLOR_UPPER} Worktree Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Basic info
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${CYAN}Path:${NC} $WORKTREE_PATH"
echo -e "${CYAN}Branch:${NC} $CURRENT_BRANCH"
echo ""

# Services status (using centralized utility from common.sh)
echo -e "${CYAN}Services:${NC}"

if check_service_status "$COLOR" "fastapi" "$WORKTREE_PATH"; then
    echo -e "  ${GREEN}✅ FastAPI${NC} (port $BACKEND_PORT)"
else
    echo -e "  ${RED}❌ FastAPI${NC} (port $BACKEND_PORT)"
fi

if check_service_status "$COLOR" "celery" "$WORKTREE_PATH"; then
    echo -e "  ${GREEN}✅ Celery${NC}"
else
    echo -e "  ${RED}❌ Celery${NC}"
fi

if [ -d "client" ] || [ -d "frontend" ]; then
    if check_service_status "$COLOR" "nextjs" "$WORKTREE_PATH"; then
        echo -e "  ${GREEN}✅ Next.js${NC} (port $FRONTEND_PORT)"
    else
        echo -e "  ${RED}❌ Next.js${NC} (port $FRONTEND_PORT)"
    fi
fi

# Redis status (shared infrastructure)
# Note: Redis container/port displayed dynamically based on actual setup
if is_redis_available; then
    echo -e "  ${GREEN}✅ Redis${NC} (shared service)"
else
    echo -e "  ${RED}❌ Redis${NC} (shared service)"
fi

echo ""

# Database status
if [ -f "$BACKEND_DIR/.env" ]; then
    source <(grep -E '^DATABASE_' "$BACKEND_DIR/.env" | xargs)

    if [ "$COLOR" = "main" ]; then
        DB_NAME="${PROJECT_NAME}"
    else
        DB_NAME="${PROJECT_NAME}_${COLOR}"
    fi

    echo -e "${CYAN}Database:${NC}"

    DB_STATUS=$(db_status "$DB_NAME")
    if [ "$DB_STATUS" = "NOT_FOUND" ]; then
        echo -e "  ${RED}❌ $DB_NAME (missing)${NC}"
    else
        echo -e "  ${GREEN}✅ $DB_NAME (migration: $DB_STATUS)${NC}"
    fi

    echo ""
fi

# Git status
echo -e "${CYAN}Git Status:${NC}"

uncommitted=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
ahead=$(git rev-list --count HEAD ^main 2>/dev/null || echo "0")
behind=$(git rev-list --count main ^HEAD 2>/dev/null || echo "0")

if [ "$uncommitted" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠️  $uncommitted uncommitted changes${NC}"
fi

if [ "$ahead" -gt 0 ]; then
    echo -e "  ${GREEN}↑ $ahead commits ahead of main${NC}"
fi

if [ "$behind" -gt 0 ]; then
    echo -e "  ${YELLOW}↓ $behind commits behind main${NC}"
fi

if [ "$uncommitted" -eq 0 ] && [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
    echo -e "  ${GREEN}✅ Clean, up-to-date with main${NC}"
fi

echo ""

# Verbose details
if [ "$VERBOSE" = true ]; then
    echo -e "${CYAN}PIDs:${NC}"

    if [ -f "logs/fastapi_${COLOR}.pid" ]; then
        echo "  FastAPI: $(cat logs/fastapi_${COLOR}.pid)"
    fi

    if [ -f "logs/celery_${COLOR}.pid" ]; then
        echo "  Celery: $(cat logs/celery_${COLOR}.pid)"
    fi

    if [ -f "logs/nextjs_${COLOR}.pid" ]; then
        echo "  Next.js: $(cat logs/nextjs_${COLOR}.pid)"
    fi

    echo ""
fi

# Quick commands
echo -e "${CYAN}Quick commands:${NC}"
echo "  Logs:    /worktree_logs $COLOR"
echo "  Health:  /worktree_health $COLOR"
echo "  Restart: /worktree_restart $COLOR"
echo ""
