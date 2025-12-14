#!/bin/bash

# show_ports.sh - Display port allocation for all worktrees
#
# Usage:
#   ./show_ports.sh

set -e

# Source common.sh for config access
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Colors from common.sh are already available
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Worktree Port Allocation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

printf "%-10s %-15s %-15s %-20s\n" "Color" "Backend Port" "Frontend Port" "Database Name"
echo "────────────────────────────────────────────────────────────"

# Load PROJECT_NAME
PROJECT_NAME=$(get_project_name)
if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "null" ]; then
    print_warning "PROJECT_NAME not found in config, using default: agent_observer"
    PROJECT_NAME="agent_observer"
fi

# Show main worktree
MAIN_BACKEND_PORT=$(get_service_port "main" "backend")
MAIN_FRONTEND_PORT=$(get_service_port "main" "frontend")
printf "%-10s %-15s %-15s %-20s\n" "main" "$MAIN_BACKEND_PORT" "$MAIN_FRONTEND_PORT" "$PROJECT_NAME"

# Show all agents from config
if [ "$CONFIG_FORMAT" = "yaml" ]; then
    # Read all agents from config
    AGENTS=$(list_agents)
    for agent in $AGENTS; do
        BACKEND_PORT=$(get_service_port "$agent" "backend")
        FRONTEND_PORT=$(get_service_port "$agent" "frontend")
        DATABASE_NAME=$(get_worktree_config "$agent" "database_name")
        printf "%-10s %-15s %-15s %-20s\n" "$agent" "$BACKEND_PORT" "$FRONTEND_PORT" "$DATABASE_NAME"
    done
else
    # JSON fallback: hardcoded blue/red/white
    for agent in blue red white; do
        BACKEND_PORT=$(get_service_port "$agent" "backend")
        FRONTEND_PORT=$(get_service_port "$agent" "frontend")
        DATABASE_NAME="${PROJECT_NAME}_${agent}"
        printf "%-10s %-15s %-15s %-20s\n" "$agent" "$BACKEND_PORT" "$FRONTEND_PORT" "$DATABASE_NAME"
    done
fi

echo ""
if [ "$CONFIG_FORMAT" = "yaml" ]; then
    echo -e "${CYAN}Configuration source:${NC} worktree.config.yaml"
    echo -e "${CYAN}Port configuration:${NC}"
    BASE_BACKEND=$(get_config_value ".port_config.base_backend_port")
    BASE_FRONTEND=$(get_config_value ".port_config.base_frontend_port")
    PORT_OFFSET=$(get_config_value ".port_config.port_offset")
    echo "  Base backend port: ${BASE_BACKEND}"
    echo "  Base frontend port: ${BASE_FRONTEND}"
    echo "  Port offset: ${PORT_OFFSET}"
else
    # For JSON/no config, show dynamic port calculation based on hardcoded defaults
    local base_backend_default=6789
    local base_frontend_default=3000
    local port_offset_default=10

    echo -e "${CYAN}Port calculation:${NC}"
    echo "  Backend:  ${base_backend_default} + (color_offset * ${port_offset_default})"
    echo "  Frontend: ${base_frontend_default} + (color_offset * ${port_offset_default})"
    echo ""
    echo -e "${CYAN}Color offsets:${NC}"
    echo "  main:  0 (no offset)"
    echo "  blue:  0"
    echo "  red:   1"
    echo "  white: 2"
fi
echo ""
