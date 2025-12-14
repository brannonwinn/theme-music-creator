#!/bin/bash

# stop_worktree.sh - Stop all services for a worktree
#
# Usage:
#   ./stop_worktree.sh [agent_color]
#
# If agent_color is not provided, it will be auto-detected from the current directory path.
#
# Examples:
#   ./stop_worktree.sh          # Auto-detect from path
#   ./stop_worktree.sh blue     # Explicitly stop blue worktree services

set -e

# Source common configuration and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Note: Color codes, print functions, detect_agent_color(), get_agent_color(),
# get_service_port(), and PROJECT_ROOT now provided by common.sh

# Stop service by port
stop_service_by_port() {
    local service_name="$1"
    local port="$2"

    # Find all PIDs using port (returns newline-separated list)
    local pids=$(lsof -i :$port -sTCP:LISTEN -t 2>/dev/null | tr '\n' ' ')

    if [ -z "$pids" ]; then
        print_warning "$service_name: Not running on port $port"
        return 0
    fi

    # Try graceful shutdown first for all PIDs
    echo "Stopping $service_name (PIDs: $pids, Port: $port)..."
    for pid in $pids; do
        kill "$pid" 2>/dev/null || true
    done

    # Wait up to 5 seconds for graceful shutdown
    local count=0
    local still_running=false
    while [ $count -lt 5 ]; do
        still_running=false
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                still_running=true
                break
            fi
        done
        [ "$still_running" = false ] && break
        sleep 1
        count=$((count + 1))
    done

    # Force kill if any still running
    for pid in $pids; do
        if kill -0 "$pid" 2>/dev/null; then
            print_warning "$service_name still running (PID: $pid), forcing shutdown..."
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
    sleep 1

    # Verify all are stopped
    local failed=false
    for pid in $pids; do
        if kill -0 "$pid" 2>/dev/null; then
            print_error "$service_name: Failed to stop (PID: $pid)"
            failed=true
        fi
    done

    if [ "$failed" = true ]; then
        return 1
    else
        print_success "$service_name stopped"
        return 0
    fi
}

# Stop Celery Docker container
stop_celery() {
    # Get PROJECT_NAME from centralized function
    local PROJECT_NAME=$(get_project_name)

    if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "null" ]; then
        print_warning "PROJECT_NAME not found in config, using default: agent_observer"
        PROJECT_NAME="agent_observer"
    fi

    local CONTAINER_NAME="${PROJECT_NAME}_celery_${AGENT_COLOR}"

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "Celery Worker (Docker): Not running (container: $CONTAINER_NAME)"
        return 0
    fi

    # Stop container
    echo "Stopping Celery Worker (Docker): $CONTAINER_NAME..."
    docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true

    # Wait a moment for container to stop
    sleep 2

    # Remove container
    docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true

    # Verify it's stopped
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_error "Celery Worker (Docker): Failed to stop ($CONTAINER_NAME)"
        return 1
    else
        print_success "Celery Worker (Docker) stopped: $CONTAINER_NAME"
        return 0
    fi
}

# Main execution
main() {
    cd "$MAIN_PROJECT_ROOT"

    # Determine agent color
    if [ $# -ge 1 ]; then
        AGENT_COLOR="$1"
    else
        AGENT_COLOR=$(detect_agent_color)
    fi

    # Get ports from config
    BACKEND_PORT=$(get_service_port "$AGENT_COLOR" "backend")
    FRONTEND_PORT=$(get_service_port "$AGENT_COLOR" "frontend")

    # Get color code for terminal output
    AGENT_COLOR_CODE=$(get_agent_color "$AGENT_COLOR")

    echo ""
    print_header "Stopping Worktree Services"
    echo ""
    echo -e "${AGENT_COLOR_CODE}Agent Color: ${AGENT_COLOR}${NC}"
    echo -e "${AGENT_COLOR_CODE}Backend Port: ${BACKEND_PORT}${NC}"
    echo -e "${AGENT_COLOR_CODE}Frontend Port: ${FRONTEND_PORT}${NC}"
    echo ""

    # Stop services
    print_header "Stopping Services"
    echo ""

    local failed=false

    # Stop FastAPI
    if ! stop_service_by_port "FastAPI" "$BACKEND_PORT"; then
        failed=true
    fi

    # Stop Celery
    if ! stop_celery; then
        failed=true
    fi

    # Stop Next.js
    if ! stop_service_by_port "Next.js" "$FRONTEND_PORT"; then
        # Frontend is optional, don't fail
        true
    fi

    echo ""

    # Clean up log files (optional)
    read -p "Delete log files? [y/N]: " delete_logs
    if [[ "$delete_logs" =~ ^[Yy]$ ]]; then
        rm -f "$PROJECT_ROOT/logs/fastapi_${AGENT_COLOR}.log"
        rm -f "$PROJECT_ROOT/logs/celery_${AGENT_COLOR}.log"
        rm -f "$PROJECT_ROOT/logs/nextjs_${AGENT_COLOR}.log"
        print_success "Log files deleted"
    fi

    echo ""

    # Summary
    if [ "$failed" = true ]; then
        print_header "Shutdown Incomplete"
        print_warning "Some services may still be running"
        echo ""
        echo "Check manually:"
        echo "  lsof -i :$BACKEND_PORT"
        echo "  lsof -i :$FRONTEND_PORT"
        echo "  docker ps | grep ${PROJECT_NAME}_celery_${AGENT_COLOR}"
    else
        print_header "Shutdown Complete"
        print_success "All services stopped"
        echo ""
        echo "To restart:"
        echo "  ./.claude/commands/worktree/scripts/start_worktree.sh ${AGENT_COLOR}"
    fi

    echo ""
}

# Run main function
main "$@"
