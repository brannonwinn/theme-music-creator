#!/bin/bash

# validate_env.sh - Validate environment variables in worktree
#
# Usage:
#   ./validate_env.sh <color> [--verbose]
#
# Examples:
#   ./validate_env.sh blue
#   ./validate_env.sh red --verbose

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "${SCRIPT_DIR}/common.sh"

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

# Functions
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}$1${NC}"
    fi
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Load PROJECT_NAME from common.sh
PROJECT_NAME=$(get_project_name)
if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "null" ]; then
    print_warning "PROJECT_NAME not found in config, using default: agent_observer"
    PROJECT_NAME="agent_observer"
fi

# Determine worktree path
if [ "$COLOR" = "main" ]; then
    WORKTREE_PATH="$MAIN_PROJECT_ROOT"
else
    WORKTREE_PATH="$MAIN_PROJECT_ROOT/worktrees/${PROJECT_NAME}_${COLOR}"
fi

# Check if worktree exists
if [ ! -d "$WORKTREE_PATH" ]; then
    log_error "Worktree ${PROJECT_NAME}_${COLOR} doesn't exist"
    exit 1
fi

log_verbose "Worktree path: $WORKTREE_PATH"

# Load directory configuration
BACKEND_DIR=$(get_backend_dir "$WORKTREE_PATH")
FRONTEND_DIR=$(get_frontend_dir "$WORKTREE_PATH")

log_verbose "Backend directory: $BACKEND_DIR"
log_verbose "Frontend directory: $FRONTEND_DIR"

cd "$WORKTREE_PATH"

# Required variables
# Note: PROJECT_NAME, OBSERVABILITY_API_URL, and REDIS_URL now come from worktree.config.yaml
REQUIRED_CLAUDE_VARS=()  # All moved to config
REQUIRED_APP_VARS=("DATABASE_HOST" "DATABASE_PORT" "DATABASE_NAME" "DATABASE_USER" "DATABASE_PASSWORD")
REQUIRED_ROOT_VARS=()  # All moved to config
REQUIRED_CONFIG_VARS=("project.name" "infrastructure.observability_api_url" "infrastructure.redis_url")
OPTIONAL_ROOT_VARS=("ENGINEER_NAME" "ENABLE_ELEVENLABS_TTS" "ENABLE_OPENAI_TTS" "ENABLE_PYTTSX3_TTS")

VALIDATION_FAILED=false

# Validate worktree.config.yaml
log_verbose "Checking worktree.config.yaml..."

if [ ! -f "$MAIN_PROJECT_ROOT/.claude/commands/worktree/worktree.config.yaml" ]; then
    log_error "worktree.config.yaml not found"
    VALIDATION_FAILED=true
else
    for config_key in "${REQUIRED_CONFIG_VARS[@]}"; do
        value=$(get_config_value ".$config_key" "" 2>/dev/null)
        if [ -z "$value" ] || [ "$value" = "null" ]; then
            log_error "Missing ${config_key} in worktree.config.yaml"
            VALIDATION_FAILED=true
        else
            log_verbose "Found ${config_key}"
        fi
    done
fi

# Validate .claude/.env
log_verbose "Checking .claude/.env..."

if [ ! -f ".claude/.env" ]; then
    log_error ".claude/.env not found"
    VALIDATION_FAILED=true
else
    for var in "${REQUIRED_CLAUDE_VARS[@]}"; do
        if ! grep -q "^${var}=" ".claude/.env"; then
            log_error "Missing ${var} in .claude/.env"
            VALIDATION_FAILED=true
        else
            log_verbose "Found ${var}"
        fi
    done
fi

# Validate backend/.env
log_verbose "Checking $BACKEND_DIR/.env..."

if [ ! -f "$BACKEND_DIR/.env" ]; then
    log_error "$BACKEND_DIR/.env not found"
    VALIDATION_FAILED=true
else
    for var in "${REQUIRED_APP_VARS[@]}"; do
        if ! grep -q "^${var}=" "$BACKEND_DIR/.env"; then
            log_error "Missing ${var} in $BACKEND_DIR/.env"
            VALIDATION_FAILED=true
        else
            log_verbose "Found ${var}"
        fi
    done
fi

# Validate root .env (TTS, API keys, Redis)
log_verbose "Checking .env (root)..."

if [ ! -f ".env" ]; then
    log_warning "Root .env not found (TTS notifications and Redis caching may not work)"
    log_verbose "  Copy from main project or create from .env.example"
else
    # Check required root variables
    for var in "${REQUIRED_ROOT_VARS[@]}"; do
        if ! grep -q "^${var}=" ".env"; then
            log_error "Missing ${var} in root .env"
            VALIDATION_FAILED=true
        else
            log_verbose "Found ${var}"
        fi
    done

    # Check optional root variables (warnings only)
    for var in "${OPTIONAL_ROOT_VARS[@]}"; do
        if ! grep -q "^${var}=" ".env"; then
            log_verbose "Optional: ${var} not set in root .env"
        else
            log_verbose "Found ${var}"
        fi
    done
fi

# Summary
if [ "$VALIDATION_FAILED" = true ]; then
    echo ""
    log_error "Environment validation failed"
    echo ""
    echo "Fix with:"
    echo "  /worktree_env_generate $COLOR"
    echo ""
    echo "Or manually copy root .env:"
    echo "  cp .env.example .env"
    echo "  # Then edit .env with your values"
    exit 1
else
    log_success "All required environment variables present"
    echo ""
    echo "Validated files:"
    echo "  ✓ .claude/.env (hook configuration)"
    echo "  ✓ $BACKEND_DIR/.env (database configuration)"
    echo "  ✓ .env (TTS, API keys, Redis)"
fi
