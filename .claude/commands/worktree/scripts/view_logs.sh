#!/bin/bash

# view_logs.sh - View logs for worktree services
#
# Usage:
#   ./view_logs.sh <color> [service] [--lines N]
#
# Examples:
#   ./view_logs.sh blue                  # Show all logs
#   ./view_logs.sh blue fastapi          # Show FastAPI logs
#   ./view_logs.sh red celery --lines 50 # Show last 50 celery log lines

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common.sh for shared utilities
source "$SCRIPT_DIR/common.sh"

# Parse arguments
COLOR=""
SERVICE=""
LINES=50

while [[ $# -gt 0 ]]; do
    case $1 in
        --lines|-n)
            LINES="$2"
            shift 2
            ;;
        *)
            if [ -z "$COLOR" ]; then
                COLOR="$1"
            elif [ -z "$SERVICE" ]; then
                SERVICE="$1"
            else
                echo -e "${RED}Error: Too many arguments${NC}"
                echo "Usage: $0 <color> [service] [--lines N]"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$COLOR" ]; then
    echo -e "${RED}Error: Missing color argument${NC}"
    echo "Usage: $0 <color> [service] [--lines N]"
    exit 1
fi

# Validate color
if ! validate_color "$COLOR"; then
    exit 1
fi

# Validate service (if provided)
if [ -n "$SERVICE" ] && [[ ! "$SERVICE" =~ ^(fastapi|celery|nextjs)$ ]]; then
    echo -e "${RED}Error: Invalid service '$SERVICE'${NC}"
    echo "Valid services: fastapi, celery, nextjs"
    exit 1
fi

# Get project name from config
PROJECT_NAME=$(get_project_name)
if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "null" ]; then
    print_warning "PROJECT_NAME not found in config, using default: agent_observer"
    PROJECT_NAME="agent_observer"
fi

# Get worktree path using common.sh utility
WORKTREE_PATH=$(get_worktree_path "$COLOR")

# Check if worktree exists
if [ ! -d "$WORKTREE_PATH" ]; then
    print_error "Worktree ${PROJECT_NAME}_${COLOR} doesn't exist"
    exit 1
fi

cd "$WORKTREE_PATH"

# Function to display log file
show_log() {
    local log_file="$1"
    local service_name="$2"

    if [ ! -f "$log_file" ]; then
        echo -e "${YELLOW}No log file found: $log_file${NC}"
        return
    fi

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $service_name Logs (last $LINES lines)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    tail -n "$LINES" "$log_file"
    echo ""
}

# Function to display Docker container logs
show_docker_log() {
    local container_name="$1"
    local service_name="$2"

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "${YELLOW}Container not found: $container_name${NC}"
        echo -e "${YELLOW}(Celery may not be running)${NC}"
        return
    fi

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $service_name Logs (last $LINES lines)${NC}"
    echo -e "${BLUE}  Container: $container_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    docker logs "$container_name" --tail "$LINES" 2>&1
    echo ""
}

# Show specific service or all
if [ -n "$SERVICE" ]; then
    case "$SERVICE" in
        fastapi)
            show_log "logs/fastapi_${COLOR}.log" "FastAPI"
            ;;
        celery)
            # Celery runs in Docker - use Docker logs
            if [ "$COLOR" = "main" ]; then
                show_docker_log "${PROJECT_NAME}_celery_worker" "Celery Worker"
            else
                show_docker_log "${PROJECT_NAME}_celery_${COLOR}" "Celery Worker"
            fi
            ;;
        nextjs)
            show_log "logs/nextjs_${COLOR}.log" "Next.js"
            ;;
    esac
else
    # Show all logs
    show_log "logs/fastapi_${COLOR}.log" "FastAPI"

    # Celery runs in Docker - use Docker logs
    if [ "$COLOR" = "main" ]; then
        show_docker_log "${PROJECT_NAME}_celery_worker" "Celery Worker"
    else
        show_docker_log "${PROJECT_NAME}_celery_${COLOR}" "Celery Worker"
    fi

    show_log "logs/nextjs_${COLOR}.log" "Next.js"
fi
