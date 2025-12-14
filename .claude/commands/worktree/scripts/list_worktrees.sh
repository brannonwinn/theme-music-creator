#!/bin/bash

# list_worktrees.sh - Display all worktrees with their status and health information
#
# Usage:
#   ./list_worktrees.sh [--verbose]
#
# Examples:
#   ./list_worktrees.sh           # Standard output
#   ./list_worktrees.sh --verbose # Include detailed information

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities (provides colors, PROJECT_ROOT, service functions)
source "$SCRIPT_DIR/common.sh"

# Emoji for different colors
BLUE_EMOJI="🔵"
RED_EMOJI="🔴"
WHITE_EMOJI="⚪"
MAIN_EMOJI="🏠"
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'

# Parse arguments
VERBOSE=false
if [[ "$1" == "--verbose" ]]; then
    VERBOSE=true
fi

# Functions
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Detect agent color from path (local version that takes path parameter)
# Note: This is different from common.sh's detect_agent_color() which uses pwd
# This version extracts agent name from a provided path, using config to get valid agents
detect_agent_color() {
    local path="$1"

    # Check if path is main project root
    if [ "$path" = "$MAIN_PROJECT_ROOT" ] || [ "$path" = "$PROJECT_ROOT" ]; then
        echo "main"
        return 0
    fi

    # Get list of all configured agents dynamically
    local agents=$(list_agents)

    # Check if path contains any configured agent name
    for agent in $agents; do
        if [[ "$path" == *"_${agent}"* ]] || [[ "$path" == *"/${agent}/"* ]] || [[ "$path" == *"/${agent}" ]]; then
            echo "$agent"
            return 0
        fi
    done

    # Default to main if cannot detect
    echo "main"
}

# Get emoji for color
get_color_emoji() {
    case "$1" in
        blue) echo "$BLUE_EMOJI" ;;
        red) echo "$RED_EMOJI" ;;
        white) echo "$WHITE_EMOJI" ;;
        main) echo "$MAIN_EMOJI" ;;
        *) echo "❓" ;;
    esac
}

# Get display color for agent color
# Note: Uses get_agent_color() from common.sh as base
get_display_color() {
    case "$1" in
        blue) echo "$CYAN" ;;
        red) echo "$RED" ;;
        white) echo "$NC" ;;
        main) echo "$MAGENTA" ;;
        *)
            # For unknown agents, use get_agent_color from common.sh
            get_agent_color "$1"
            ;;
    esac
}


# Check database status
check_database_status() {
    local worktree_path="$1"
    local color="$2"

    cd "$worktree_path"

    # Get database name from centralized config
    local db_name
    if [ "$color" = "main" ]; then
        # Main project uses postgres database
        db_name="postgres"
    else
        # Worktrees use database_name from config
        db_name=$(get_worktree_config "$color" "database_name")

        # Fallback if not found in config
        if [ -z "$db_name" ] || [ "$db_name" = "null" ]; then
            local project_name=$(get_project_name)
            db_name="${project_name}_${color}"
        fi
    fi

    # Check if database exists using docker exec with dynamic container detection
    local db_container=$(detect_supabase_container)
    if [ -z "$db_container" ]; then
        echo "${RED}❌ Supabase container not found${NC}"
        return
    fi

    docker exec "$db_container" psql -U postgres -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='${db_name}'" \
        2>/dev/null | grep -q 1

    if [ $? -eq 0 ]; then
        echo "${GREEN}✅ $db_name${NC}"
    else
        echo "${RED}❌ $db_name (missing)${NC}"
    fi
}

# Get git status info
get_git_status() {
    local worktree_path="$1"

    cd "$worktree_path"

    # Check for uncommitted changes
    local uncommitted=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    # Check commits ahead/behind main
    local ahead=$(git rev-list --count HEAD ^main 2>/dev/null || echo "0")
    local behind=$(git rev-list --count main ^HEAD 2>/dev/null || echo "0")

    local status_parts=()

    if [ "$ahead" -gt 0 ]; then
        status_parts+=("${GREEN}↑$ahead ahead${NC}")
    fi

    if [ "$behind" -gt 0 ]; then
        status_parts+=("${YELLOW}↓$behind behind${NC}")
    fi

    if [ "$uncommitted" -gt 0 ]; then
        status_parts+=("${YELLOW}$uncommitted uncommitted${NC}")
    fi

    if [ ${#status_parts[@]} -eq 0 ]; then
        echo "${GREEN}Clean, up-to-date${NC}"
    else
        echo "$(IFS=', '; echo "${status_parts[*]}")"
    fi
}

# Display worktree info
display_worktree() {
    local worktree_path="$1"
    local branch="$2"
    local color=$(detect_agent_color "$worktree_path")
    local emoji=$(get_color_emoji "$color")
    local display_color=$(get_display_color "$color")

    echo ""
    local color_upper=$(echo "$color" | tr '[:lower:]' '[:upper:]')
    echo -e "${display_color}${emoji} ${color_upper} $(basename "$worktree_path")${NC}"
    echo -e "   Branch: ${CYAN}$branch${NC}"
    echo -e "   Path: $worktree_path"

    # Services status (using centralized utility from common.sh)
    local services=$(get_all_services_status "$color" "$worktree_path")
    echo -e "   Services: $services"

    # Database status
    local db_status=$(check_database_status "$worktree_path" "$color")
    echo -e "   Database: $db_status"

    # Git status
    local git_status=$(get_git_status "$worktree_path")
    echo -e "   Git: $git_status"

    # Verbose info
    if [ "$VERBOSE" = true ]; then
        cd "$worktree_path"

        # Check for log files
        if [ -f "logs/fastapi_${color}.log" ]; then
            local log_lines=$(wc -l < "logs/fastapi_${color}.log" 2>/dev/null || echo "0")
            echo -e "   ${BLUE}Logs: $log_lines lines in fastapi_${color}.log${NC}"
        fi

        # Check for PID files
        if [ -f "logs/fastapi_${color}.pid" ]; then
            local pid=$(cat "logs/fastapi_${color}.pid" 2>/dev/null)
            echo -e "   ${BLUE}FastAPI PID: $pid${NC}"
        fi
    fi
}

# Main execution
main() {
    cd "$PROJECT_ROOT"

    print_header "Git Worktrees Status"
    echo ""

    # Get all worktrees
    local worktree_list=$(git worktree list --porcelain)

    # Parse worktree list
    local current_path=""
    local current_branch=""
    local worktree_count=0

    while IFS= read -r line; do
        if [[ "$line" == worktree* ]]; then
            # New worktree entry
            if [ -n "$current_path" ]; then
                display_worktree "$current_path" "$current_branch"
                worktree_count=$((worktree_count + 1))
            fi
            current_path="${line#worktree }"
            current_branch=""
        elif [[ "$line" == branch* ]]; then
            current_branch="${line#branch refs/heads/}"
        fi
    done <<< "$worktree_list"

    # Display last worktree
    if [ -n "$current_path" ]; then
        display_worktree "$current_path" "$current_branch"
        worktree_count=$((worktree_count + 1))
    fi

    echo ""
    print_header "Summary"
    echo -e "${GREEN}Total worktrees: $worktree_count${NC}"
    echo ""

    # Quick commands reference
    echo -e "${BLUE}Quick commands:${NC}"
    echo "  Create: /create_worktree"
    echo "  Delete: /delete_worktree"
    echo "  Start:  ./.claude/scripts/start_worktree.sh <color>"
    echo "  Stop:   ./.claude/scripts/stop_worktree.sh <color>"
    echo "  Sync:   ./.claude/scripts/sync_worktree.sh --pull --migrate"
    echo ""
}

# Run main function
main
