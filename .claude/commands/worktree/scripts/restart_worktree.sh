#!/bin/bash

# restart_worktree.sh - Restart all services for a worktree
#
# Usage:
#   ./restart_worktree.sh [agent_color] [--pull] [--migrate]
#
# If agent_color is not provided, it will be auto-detected from the current directory path.
#
# Examples:
#   ./restart_worktree.sh                  # Auto-detect, just restart
#   ./restart_worktree.sh blue             # Explicitly restart blue worktree
#   ./restart_worktree.sh blue --pull      # Pull latest code before restart
#   ./restart_worktree.sh blue --pull --migrate  # Pull, migrate, then restart

set -e

# Source common configuration and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Note: Color codes, print functions, detect_agent_color(), get_agent_color()
# now provided by common.sh

# Parse arguments
AGENT_COLOR=""
PULL_FLAG=""
MIGRATE_FLAG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --pull)
            PULL_FLAG="--pull"
            shift
            ;;
        --migrate)
            MIGRATE_FLAG="--migrate"
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            echo "Usage: $0 [agent_color] [--pull] [--migrate]"
            exit 1
            ;;
        *)
            # Any non-flag argument is treated as agent color
            AGENT_COLOR="$1"
            shift
            ;;
    esac
done

# Main execution
main() {
    cd "$PROJECT_ROOT"

    # Determine agent color
    if [ -z "$AGENT_COLOR" ]; then
        AGENT_COLOR=$(detect_agent_color)
    fi

    # Validate agent color
    if ! validate_color "$AGENT_COLOR"; then
        exit 1
    fi

    # Get color code for terminal output
    AGENT_COLOR_CODE=$(get_agent_color "$AGENT_COLOR")

    echo ""
    print_header "Restarting Worktree Services"
    echo ""
    echo -e "${AGENT_COLOR_CODE}Agent Color: ${AGENT_COLOR}${NC}"
    if [ -n "$PULL_FLAG" ]; then
        echo -e "${AGENT_COLOR_CODE}Will pull latest code from main${NC}"
    fi
    if [ -n "$MIGRATE_FLAG" ]; then
        echo -e "${AGENT_COLOR_CODE}Will run database migrations${NC}"
    fi
    echo ""

    # Step 1: Stop services
    print_header "Step 1: Stopping Services"
    echo ""
    "$SCRIPT_DIR/stop_worktree.sh" "$AGENT_COLOR" <<< "N"  # Don't delete logs
    echo ""

    # Step 2: Sync worktree (optional)
    if [ -n "$PULL_FLAG" ] || [ -n "$MIGRATE_FLAG" ]; then
        print_header "Step 2: Syncing Worktree"
        echo ""

        SYNC_ARGS=""
        if [ -n "$PULL_FLAG" ]; then
            SYNC_ARGS="$SYNC_ARGS --pull"
        fi
        if [ -n "$MIGRATE_FLAG" ]; then
            SYNC_ARGS="$SYNC_ARGS --migrate"
        fi

        if ! "$SCRIPT_DIR/sync_worktree.sh" $SYNC_ARGS; then
            print_error "Sync failed, aborting restart"
            exit 1
        fi

        echo ""
    fi

    # Step 3: Start services
    print_header "Step 3: Starting Services"
    echo ""
    "$SCRIPT_DIR/start_worktree.sh" "$AGENT_COLOR"
}

# Run main function
main
