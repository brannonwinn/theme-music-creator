#!/bin/bash

# doctor.sh - Diagnose worktree system health and common issues
#
# Usage:
#   ./doctor.sh [--verbose] [--fix]
#
# Checks:
#   - Configuration file
#   - Dependencies (yq, git, docker)
#   - Supabase container
#   - Port conflicts
#   - Worktree status
#   - Python/Node dependencies

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

# Source common.sh
source "$SCRIPT_DIR/common.sh"

# Parse arguments
VERBOSE=false
FIX=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --fix)
            FIX=true
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option '$1'${NC}"
            echo "Usage: $0 [--verbose] [--fix]"
            exit 1
            ;;
    esac
done

# Diagnostic state
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

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

log_check() {
    echo -e "${CYAN}Checking: $1${NC}"
}

log_pass() {
    echo -e "${GREEN}  ✅ $1${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}  ❌ $1${NC}"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

log_warn() {
    echo -e "${YELLOW}  ⚠️  $1${NC}"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
}

log_info() {
    echo -e "${CYAN}  ℹ️  $1${NC}"
}

log_fix() {
    echo -e "${GREEN}  🔧 $1${NC}"
}

# Main diagnostic
main() {
    cd "$PROJECT_ROOT"

    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                 Worktree System Doctor                    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Running diagnostics..."

    # Section 1: Core Dependencies
    print_section "Core Dependencies"

    # Check git
    log_check "Git installation"
    if command -v git &> /dev/null; then
        local git_version=$(git --version | awk '{print $3}')
        log_pass "Git installed: v$git_version"
    else
        log_fail "Git not found"
        log_info "Install git: https://git-scm.com"
    fi

    # Check yq (for YAML config)
    log_check "yq installation"
    if check_yq_installed; then
        local yq_cmd=$(get_yq_cmd)
        local yq_version=$($yq_cmd --version | awk '{print $NF}')
        log_pass "yq installed: $yq_version at $($yq_cmd --version | awk '{print $1}' | xargs which 2>/dev/null || echo $(get_yq_cmd))"
    else
        log_fail "yq not found (required for YAML config)"
        log_info "Install: brew install yq"
        if [ "$FIX" = true ]; then
            log_fix "Installing yq..."
            brew install yq && log_pass "yq installed successfully"
        fi
    fi

    # Check docker
    log_check "Docker installation"
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        log_pass "Docker installed: v$docker_version"

        # Check if Docker is running
        if docker info &> /dev/null; then
            log_pass "Docker daemon is running"
        else
            log_fail "Docker daemon is not running"
            log_info "Start Docker Desktop or run: sudo systemctl start docker"
        fi
    else
        log_fail "Docker not found"
        log_info "Install Docker: https://docs.docker.com/get-docker/"
    fi

    # Section 2: Configuration
    print_section "Configuration"

    # Check config file exists
    log_check "Configuration file"
    if [ -f "$WORKTREE_CONFIG" ]; then
        log_pass "Config file exists: $WORKTREE_CONFIG"
        log_verbose "Format: $CONFIG_FORMAT"

        # Validate config
        if [ -x "$SCRIPT_DIR/validate_config.sh" ]; then
            log_check "Configuration validation"
            if "$SCRIPT_DIR/validate_config.sh" > /dev/null 2>&1; then
                log_pass "Configuration is valid"
            else
                log_fail "Configuration has errors"
                log_info "Run: ./.claude/commands/worktree/scripts/validate_config.sh"
            fi
        fi
    else
        log_fail "Config file not found: $WORKTREE_CONFIG"
        log_info "Create from example: cp worktree.config.example.yaml worktree.config.yaml"

        if [ "$FIX" = true ] && [ -f ".claude/commands/worktree/worktree.config.example.yaml" ]; then
            log_fix "Creating config from example..."
            cp ".claude/commands/worktree/worktree.config.example.yaml" "$WORKTREE_CONFIG"
            log_pass "Configuration file created"
        fi
    fi

    # Section 3: Database
    print_section "Database & Infrastructure"

    # Check Supabase container
    log_check "Supabase container"
    local container_name=$(detect_supabase_container 2>/dev/null || echo "")
    if [ -n "$container_name" ]; then
        log_pass "Supabase container running: $container_name"

        # Check container status
        local container_status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
        if [ "$container_status" = "running" ]; then
            log_pass "Container status: running"
        else
            log_warn "Container status: $container_status"
        fi
    else
        log_fail "Supabase container not found"
        log_info "Start Supabase: cd docker && ./start.sh"
    fi

    # Section 4: Port Conflicts
    print_section "Port Availability"

    # Get all configured ports
    local agents=$(list_agents)
    local all_ports=()

    # Main ports
    local main_backend=$(get_service_port "main" "backend")
    local main_frontend=$(get_service_port "main" "frontend")
    all_ports+=("$main_backend:main-backend")
    all_ports+=("$main_frontend:main-frontend")

    # Agent ports
    for agent in $agents; do
        local backend_port=$(get_service_port "$agent" "backend")
        local frontend_port=$(get_service_port "$agent" "frontend")
        all_ports+=("$backend_port:$agent-backend")
        all_ports+=("$frontend_port:$agent-frontend")
    done

    # Check each port
    log_check "Port conflicts"
    local conflicts_found=false
    for port_info in "${all_ports[@]}"; do
        local port="${port_info%%:*}"
        local service="${port_info##*:}"

        if lsof -i :"$port" -sTCP:LISTEN -t > /dev/null 2>&1; then
            local pid=$(lsof -i :"$port" -sTCP:LISTEN -t 2>/dev/null | head -1)
            local process=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
            log_verbose "Port $port ($service): In use by $process (PID: $pid)"
            conflicts_found=true
        else
            log_verbose "Port $port ($service): Available ✓"
        fi
    done

    if [ "$conflicts_found" = false ]; then
        log_pass "All ports are available"
    else
        log_warn "Some ports are in use (this is normal if services are running)"
        log_info "To free ports: ./.claude/commands/worktree/scripts/stop_worktree.sh <agent>"
    fi

    # Section 5: Worktrees
    print_section "Git Worktrees"

    # Check git worktree status
    log_check "Git worktree list"
    local worktree_count=$(git worktree list | wc -l | tr -d ' ')
    log_pass "Total worktrees: $worktree_count"

    if [ "$VERBOSE" = true ]; then
        git worktree list | while read line; do
            log_verbose "$line"
        done
    fi

    # Check for each configured agent
    for agent in $agents; do
        local project_name=$(get_project_name)
        local expected_path="$PROJECT_ROOT/worktrees/${project_name}_${agent}"

        if [ -d "$expected_path" ]; then
            log_verbose "Worktree exists: $agent → $expected_path"
        else
            log_verbose "Worktree missing: $agent (not created yet)"
        fi
    done

    # Section 6: Dependencies
    print_section "Project Dependencies"

    # Check Python/uv
    log_check "Python environment (uv)"
    if command -v uv &> /dev/null; then
        local uv_version=$(uv --version | awk '{print $2}')
        log_pass "uv installed: v$uv_version"
    else
        log_warn "uv not found (optional - can use pip/poetry instead)"
        log_info "Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi

    # Check Node/npm
    log_check "Node.js environment"
    if command -v node &> /dev/null; then
        local node_version=$(node --version)
        log_pass "Node.js installed: $node_version"

        if command -v npm &> /dev/null; then
            local npm_version=$(npm --version)
            log_pass "npm installed: v$npm_version"
        else
            log_warn "npm not found"
        fi
    else
        log_warn "Node.js not found (required for frontend)"
        log_info "Install: https://nodejs.org/"
    fi

    # Section 7: Project Structure
    print_section "Project Structure"

    # Check backend directory
    log_check "Backend directory"
    local backend_dir=$(detect_backend_dir 2>/dev/null || echo "")
    if [ -n "$backend_dir" ]; then
        log_pass "Backend found: $backend_dir"
    else
        log_warn "Backend directory not detected"
    fi

    # Check frontend directory
    log_check "Frontend directory"
    local frontend_dir=$(detect_frontend_dir 2>/dev/null || echo "")
    if [ -n "$frontend_dir" ]; then
        log_pass "Frontend found: $frontend_dir"
    else
        log_warn "Frontend directory not detected (optional)"
    fi

    # Summary
    print_section "Diagnostic Summary"
    echo ""

    local total_checks=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))

    echo -e "${CYAN}Total checks: $total_checks${NC}"
    echo -e "${GREEN}Passed: $CHECKS_PASSED${NC}"
    echo -e "${YELLOW}Warnings: $CHECKS_WARNING${NC}"
    echo -e "${RED}Failed: $CHECKS_FAILED${NC}"
    echo ""

    if [ $CHECKS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ System is healthy!${NC}"
        echo ""
        echo "Your worktree system is ready to use."
        if [ $CHECKS_WARNING -gt 0 ]; then
            echo "Some warnings were found, but they won't prevent normal operation."
        fi
        return 0
    else
        echo -e "${RED}❌ Issues found!${NC}"
        echo ""
        echo "Fix the failed checks before using the worktree system."
        if [ "$FIX" = false ]; then
            echo ""
            echo "Tip: Run with --fix to automatically fix some issues:"
            echo "  ./.claude/commands/worktree/scripts/doctor.sh --fix"
        fi
        return 1
    fi
}

# Run main
main
