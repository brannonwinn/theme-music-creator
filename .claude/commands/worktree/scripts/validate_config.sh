#!/bin/bash

# validate_config.sh - Validate worktree configuration file
#
# Usage:
#   ./validate_config.sh [--verbose]
#
# Validates:
#   - YAML syntax
#   - Required fields
#   - Port uniqueness and valid ranges
#   - Database name uniqueness
#   - Agent definitions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get main project root (works from both main and worktree)
PROJECT_ROOT="$(git worktree list | head -1 | awk '{print $1}')"

# Source common.sh for utility functions
source "$SCRIPT_DIR/common.sh"

# Parse arguments
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option '$1'${NC}"
            echo "Usage: $0 [--verbose]"
            exit 1
            ;;
    esac
done

# Validation state
ERRORS=0
WARNINGS=0

# Functions
print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}  $1${NC}"
    fi
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    ERRORS=$((ERRORS + 1))
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

# Main validation
main() {
    cd "$PROJECT_ROOT"

    print_section "Worktree Configuration Validation"
    echo ""

    # Check 1: Config file exists
    if [ ! -f "$WORKTREE_CONFIG" ]; then
        log_error "Configuration file not found: $WORKTREE_CONFIG"
        echo ""
        echo "Create one with:"
        echo "  cp .claude/commands/worktree/worktree.config.example.yaml .claude/commands/worktree/worktree.config.yaml"
        exit 1
    fi
    log_success "Configuration file exists: $WORKTREE_CONFIG"

    # Check 2: Detect config format
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        log_success "Configuration format: YAML (recommended)"
    elif [ "$CONFIG_FORMAT" = "json" ]; then
        log_warning "Configuration format: JSON (deprecated - consider migrating to YAML)"
    else
        log_error "Unknown configuration format"
        exit 1
    fi

    # Check 3: yq installed (for YAML)
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        if ! check_yq_installed; then
            log_error "yq not installed (required for YAML config)"
            echo ""
            echo "Install with: brew install yq"
            exit 1
        fi
        log_success "yq installed: $(get_yq_cmd)"
    fi

    # Check 4: YAML syntax (for YAML)
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        log_verbose "Checking YAML syntax..."
        local yq_cmd=$(get_yq_cmd)
        if ! "$yq_cmd" eval '.' "$WORKTREE_CONFIG" > /dev/null 2>&1; then
            log_error "Invalid YAML syntax in $WORKTREE_CONFIG"
            "$yq_cmd" eval '.' "$WORKTREE_CONFIG" 2>&1 | head -5
            exit 1
        fi
        log_success "YAML syntax valid"
    fi

    # Check 5: Required fields
    log_verbose "Checking required fields..."

    local project_name=$(get_project_name)
    if [ -z "$project_name" ] || [ "$project_name" = "null" ]; then
        log_error "Missing required field: project.name"
    else
        log_success "Project name: $project_name"
    fi

    # Check 6: Agents array
    local agents=$(list_agents)
    if [ -z "$agents" ]; then
        log_error "No agents defined in configuration"
    else
        local agent_count=$(echo "$agents" | wc -w | tr -d ' ')
        log_success "Agents defined: $agent_count ($(echo $agents | tr ' ' ', '))"
    fi

    # Check 7: Port configuration
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        local base_backend=$(get_config_value ".port_config.base_backend_port")
        local base_frontend=$(get_config_value ".port_config.base_frontend_port")
        local port_offset=$(get_config_value ".port_config.port_offset")

        if [ -z "$base_backend" ] || [ "$base_backend" = "null" ]; then
            log_error "Missing port_config.base_backend_port"
        else
            log_success "Base backend port: $base_backend"
        fi

        if [ -z "$base_frontend" ] || [ "$base_frontend" = "null" ]; then
            log_error "Missing port_config.base_frontend_port"
        else
            log_success "Base frontend port: $base_frontend"
        fi
    fi

    # Check 8: .gitignore entries
    print_section ".gitignore Validation"
    echo ""

    if [ ! -f "$PROJECT_ROOT/.gitignore" ]; then
        log_warning ".gitignore file not found - consider creating one"
    else
        log_success ".gitignore file exists"

        local required_entries=(
            "worktrees/"
            "docker/docker-compose.celery.yml"
            "docker/Dockerfile.celery"
        )

        local missing_entries=()

        for entry in "${required_entries[@]}"; do
            if ! grep -qF "$entry" "$PROJECT_ROOT/.gitignore"; then
                missing_entries+=("$entry")
            else
                log_verbose "  Found: $entry"
            fi
        done

        if [ ${#missing_entries[@]} -gt 0 ]; then
            log_warning "Missing required .gitignore entries:"
            for entry in "${missing_entries[@]}"; do
                echo "    - $entry"
            done
            echo ""
            echo "These entries prevent worktree-specific files from being committed."
            echo "Add them manually or run this script with --fix-gitignore"
        else
            log_success "All required .gitignore entries present"
        fi
    fi

    # Check 9: Validate each agent
    print_section "Agent Validation"
    echo ""

    local seen_backend_ports=()
    local seen_frontend_ports=()
    local seen_databases=()

    for agent in $agents; do
        echo -e "${CYAN}Validating agent: $agent${NC}"

        # Get agent config
        local backend_port=$(get_service_port "$agent" "backend")
        local frontend_port=$(get_service_port "$agent" "frontend")
        local database_name=$(get_worktree_config "$agent" "database_name")
        local display_name=$(get_agent_display_name "$agent")

        # Check agent name
        if [ -z "$agent" ]; then
            log_error "  Agent has empty name"
            continue
        fi
        log_verbose "  Name: $agent"

        # Check display name
        if [ -z "$display_name" ] || [ "$display_name" = "null" ]; then
            log_warning "  Missing display_name (will use default)"
        else
            log_verbose "  Display name: $display_name"
        fi

        # Check backend port
        if [ -z "$backend_port" ] || [ "$backend_port" = "null" ]; then
            log_error "  Missing backend_port"
        elif [ "$backend_port" -lt 1024 ] || [ "$backend_port" -gt 65535 ]; then
            log_error "  Invalid backend_port: $backend_port (must be 1024-65535)"
        elif [[ " ${seen_backend_ports[@]} " =~ " ${backend_port} " ]]; then
            log_error "  Duplicate backend_port: $backend_port"
        else
            seen_backend_ports+=("$backend_port")
            log_verbose "  Backend port: $backend_port ✓"
        fi

        # Check frontend port
        if [ -z "$frontend_port" ] || [ "$frontend_port" = "null" ]; then
            log_error "  Missing frontend_port"
        elif [ "$frontend_port" -lt 1024 ] || [ "$frontend_port" -gt 65535 ]; then
            log_error "  Invalid frontend_port: $frontend_port (must be 1024-65535)"
        elif [[ " ${seen_frontend_ports[@]} " =~ " ${frontend_port} " ]]; then
            log_error "  Duplicate frontend_port: $frontend_port"
        else
            seen_frontend_ports+=("$frontend_port")
            log_verbose "  Frontend port: $frontend_port ✓"
        fi

        # Check ports don't overlap
        if [ "$backend_port" = "$frontend_port" ]; then
            log_error "  Backend and frontend ports are the same: $backend_port"
        fi

        # Check database name
        if [ -z "$database_name" ] || [ "$database_name" = "null" ]; then
            log_error "  Missing database_name"
        elif [[ " ${seen_databases[@]} " =~ " ${database_name} " ]]; then
            log_error "  Duplicate database_name: $database_name"
        else
            seen_databases+=("$database_name")
            log_verbose "  Database: $database_name ✓"
        fi

        echo ""
    done

    # Summary
    print_section "Validation Summary"
    echo ""

    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        log_success "Configuration is valid! No errors or warnings."
        echo ""
        echo "Your worktree configuration is ready to use."
        return 0
    elif [ $ERRORS -eq 0 ]; then
        log_warning "Configuration has $WARNINGS warning(s) but no errors"
        echo ""
        echo "Your configuration will work, but consider addressing the warnings."
        return 0
    else
        log_error "Configuration has $ERRORS error(s) and $WARNINGS warning(s)"
        echo ""
        echo "Fix the errors before using the worktree system."
        return 1
    fi
}

# Run main
main
