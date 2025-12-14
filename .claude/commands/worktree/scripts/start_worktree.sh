#!/bin/bash

# start_worktree.sh - Start all services for a worktree
#
# Usage:
#   ./start_worktree.sh [agent_color]
#
# If agent_color is not provided, it will be auto-detected from the current directory path.
#
# Examples:
#   ./start_worktree.sh          # Auto-detect from path
#   ./start_worktree.sh blue     # Explicitly use blue configuration

set -e

# Source common configuration and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Note: detect_agent_color() now provided by common.sh
# Removed local hardcoded implementation in favor of centralized function

# Kill process on a specific port
kill_process_on_port() {
    local port=$1
    local pids=$(lsof -t -i :"$port" 2>/dev/null)

    if [ -n "$pids" ]; then
        echo "$pids" | xargs kill -9 2>/dev/null
        print_success "Killed stale process(es) on port $port (PIDs: $pids)"
        sleep 0.5  # Give OS time to release the port
        return 0
    fi
    return 1
}

# Start FastAPI
start_fastapi() {
    print_header "Starting FastAPI Backend"

    # Auto-kill any process on the backend port
    kill_process_on_port "$BACKEND_PORT" || true

    # Change to backend APP directory (where main.py is)
    cd "$WORKTREE_PATH/$BACKEND_APP_DIR"

    # Start with uvicorn (run from backend app directory so imports work correctly)
    nohup uv run uvicorn main:app \
        --host 0.0.0.0 \
        --port "$BACKEND_PORT" \
        --reload \
        > "$WORKTREE_PATH/logs/fastapi_${AGENT_COLOR}.log" 2>&1 &

    local pid=$!
    echo $pid > "$WORKTREE_PATH/logs/fastapi_${AGENT_COLOR}.pid"

    # Wait a bit for startup
    sleep 2

    # Check if still running
    if kill -0 $pid 2>/dev/null; then
        print_success "FastAPI started on port $BACKEND_PORT (PID: $pid)"
        return 0
    else
        print_error "FastAPI failed to start. Check logs/fastapi_${AGENT_COLOR}.log"
        return 1
    fi
}

# Start Celery Worker (Docker)
start_celery() {
    print_header "Starting Celery Worker (Docker)"

    # Get docker directory from config (e.g., "backend/docker/.env" -> "backend/docker")
    local DOCKER_ENV_PATH=$(get_config_value "project.docker_env_path" "docker/.env")
    local DOCKER_DIR="$(dirname "$DOCKER_ENV_PATH")"

    cd "$WORKTREE_PATH/$DOCKER_DIR"

    # Check if docker-compose.celery.yml exists
    if [ ! -f "docker-compose.celery.yml" ]; then
        print_error "docker-compose.celery.yml not found"
        echo "Run generate_celery_compose.sh first:"
        echo "  ./.claude/commands/worktree/scripts/generate_celery_compose.sh ${AGENT_COLOR} $(pwd)"
        return 1
    fi

    # Get PROJECT_NAME for container name
    local PROJECT_NAME=$(get_config_value "project.name" "hosthero")
    local CONTAINER_NAME="${PROJECT_NAME}_celery_${AGENT_COLOR}"

    # Stop existing container if running
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "Stopping existing container: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
        docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
    fi

    # Start Celery worker container
    docker compose -f docker-compose.celery.yml up -d

    # Wait for startup
    sleep 3

    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        local DATABASE_NAME="${PROJECT_NAME}_${AGENT_COLOR}"
        print_success "Celery worker started: $CONTAINER_NAME"
        echo "  Database: $DATABASE_NAME"
        echo "  Queue: ${DATABASE_NAME}_tasks"
        return 0
    else
        print_error "Celery worker failed to start"
        echo "Check logs: docker logs $CONTAINER_NAME"
        return 1
    fi

    cd "$WORKTREE_PATH"
}

# Start Next.js Frontend
start_nextjs() {
    print_header "Starting Next.js Frontend"

    if [ ! -d "$WORKTREE_PATH/$FRONTEND_DIR" ]; then
        print_warning "Frontend directory not found: $FRONTEND_DIR, skipping"
        return 0
    fi

    # Auto-kill any process on the frontend port
    kill_process_on_port "$FRONTEND_PORT" || true

    cd "$WORKTREE_PATH/$FRONTEND_DIR"

    # Start Next.js with custom port
    PORT=$FRONTEND_PORT nohup npm run dev \
        > "$WORKTREE_PATH/logs/nextjs_${AGENT_COLOR}.log" 2>&1 &

    local pid=$!
    echo $pid > "$WORKTREE_PATH/logs/nextjs_${AGENT_COLOR}.pid"

    # Wait a bit for startup
    sleep 3

    # Check if still running
    if kill -0 $pid 2>/dev/null; then
        print_success "Next.js started on port $FRONTEND_PORT (PID: $pid)"
        return 0
    else
        print_error "Next.js failed to start. Check logs/nextjs_${AGENT_COLOR}.log"
        return 1
    fi
}

# Main execution
main() {
    # Determine agent color
    if [ $# -ge 1 ]; then
        AGENT_COLOR="$1"
    else
        AGENT_COLOR=$(detect_agent_color)
    fi

    # Validate color
    validate_color "$AGENT_COLOR"

    # Get worktree path
    WORKTREE_PATH=$(get_worktree_path "$AGENT_COLOR")

    # Check if worktree exists
    if [ ! -d "$WORKTREE_PATH" ]; then
        print_error "Worktree for color '$AGENT_COLOR' doesn't exist at: $WORKTREE_PATH"
        exit 1
    fi

    # Load configuration (sets BACKEND_PORT, FRONTEND_PORT, DATABASE_NAME)
    load_worktree_config "$AGENT_COLOR"

    # Load directory configuration
    # Use backend_app_dir for starting services (where main.py is)
    BACKEND_APP_DIR=$(get_backend_app_dir)
    FRONTEND_DIR=$(get_frontend_dir "$WORKTREE_PATH")

    # Get color code for terminal output
    AGENT_COLOR_CODE=$(get_agent_color "$AGENT_COLOR")

    # Ensure we use the worktree's virtual environment
    export VIRTUAL_ENV="$WORKTREE_PATH/.venv"
    export PATH="$VIRTUAL_ENV/bin:$PATH"

    cd "$WORKTREE_PATH"

    echo ""
    print_header "Starting Worktree Services"
    echo ""
    echo -e "${AGENT_COLOR_CODE}Agent Color: ${AGENT_COLOR}${NC}"
    echo -e "${AGENT_COLOR_CODE}Backend App Dir: ${BACKEND_APP_DIR}${NC}"
    echo -e "${AGENT_COLOR_CODE}Frontend Dir: ${FRONTEND_DIR}${NC}"
    echo -e "${AGENT_COLOR_CODE}Backend Port: ${BACKEND_PORT}${NC}"
    echo -e "${AGENT_COLOR_CODE}Frontend Port: ${FRONTEND_PORT}${NC}"
    echo ""

    # Create logs directory if it doesn't exist
    mkdir -p logs

    # Start services
    local failed=false

    if ! start_fastapi; then
        failed=true
    fi
    echo ""

    if ! start_celery; then
        failed=true
    fi
    echo ""

    if ! start_nextjs; then
        # Frontend is optional, don't fail
        true
    fi
    echo ""

    # Summary
    if [ "$failed" = true ]; then
        print_header "Startup Failed"
        print_error "One or more services failed to start"
        echo ""
        echo "Check logs:"
        echo "  - FastAPI: logs/fastapi_${AGENT_COLOR}.log"
        echo "  - Celery (Docker): docker logs ${PROJECT_NAME}_celery_${AGENT_COLOR}"
        echo "  - Next.js: logs/nextjs_${AGENT_COLOR}.log"
        exit 1
    else
        print_header "Startup Complete"
        print_success "All services started successfully"
        echo ""
        echo -e "${AGENT_COLOR_CODE}Service URLs:${NC}"
        echo "  Backend API: http://localhost:${BACKEND_PORT}"
        echo "  Frontend: http://localhost:${FRONTEND_PORT}"
        echo ""
        echo -e "${AGENT_COLOR_CODE}Logs:${NC}"
        echo "  FastAPI: tail -f logs/fastapi_${AGENT_COLOR}.log"
        echo "  Celery (Docker): docker logs -f ${PROJECT_NAME}_celery_${AGENT_COLOR}"
        echo "  Next.js: tail -f logs/nextjs_${AGENT_COLOR}.log"
        echo ""
        echo -e "${AGENT_COLOR_CODE}Management:${NC}"
        echo "  Stop services: ./.claude/scripts/stop_worktree.sh ${AGENT_COLOR}"
        echo "  Restart services: ./.claude/scripts/restart_worktree.sh ${AGENT_COLOR}"
        echo ""
    fi
}

# Run main function
main "$@"
