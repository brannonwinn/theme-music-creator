#!/bin/bash

# generate_celery_compose.sh - Generate docker-compose.celery.yml and Dockerfile from templates
#
# Usage:
#   ./generate_celery_compose.sh <agent_color> [--force]
#
# Options:
#   --force    Overwrite existing files without prompting
#
# This script generates worktree-specific Celery configuration files:
#   - docker-compose.celery.yml (Docker Compose configuration)
#   - Dockerfile.celery (Celery worker Dockerfile)
#
# Variables substituted:
#   {{PROJECT_NAME}}    - From docker/.env
#   {{AGENT_COLOR}}     - From argument
#   {{POSTGRES_DB}}     - From worktree config (e.g., hosthero_blue)
#   {{BACKEND_DIR}}     - Backend directory path
#   ... and other LLM/database variables

set -e

# Arguments
AGENT_COLOR=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        *)
            if [ -z "$AGENT_COLOR" ]; then
                AGENT_COLOR="$1"
            else
                echo "Error: Too many arguments"
                echo "Usage: $0 <agent_color> [--force]"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$AGENT_COLOR" ]; then
    echo "Usage: $0 <agent_color> [--force]"
    exit 1
fi

# Source common configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Validate agent color
validate_color "$AGENT_COLOR"

# Get worktree path from color (uses get_worktree_path from common.sh)
WORKTREE_PATH=$(get_worktree_path "$AGENT_COLOR")

# Check if worktree exists
if [ ! -d "$WORKTREE_PATH" ]; then
    print_error "Worktree for color '$AGENT_COLOR' doesn't exist at: $WORKTREE_PATH"
    exit 1
fi

# Check if Celery is enabled in config
CELERY_ENABLED=$(get_config_value "features.celery_enabled" "true")
if [ "$CELERY_ENABLED" != "true" ]; then
    echo "Celery is disabled in worktree.config.yaml (features.celery_enabled=false)"
    echo "Skipping Celery Docker Compose generation"
    exit 0
fi

# Helper function to check if we should overwrite a file
should_generate_file() {
    local file=$1
    local file_type=$2

    if [ ! -f "$file" ]; then
        return 0  # File doesn't exist, generate it
    fi

    # Check if file is tracked by git (safety check)
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        print_warning "$file_type is tracked by git: $file"
        print_warning "This file should be in .gitignore to prevent merge conflicts"
        echo "Please add '$(basename $(dirname "$file"))/$(basename "$file")' to .gitignore"
        if [ "$FORCE" != true ]; then
            read -p "Continue anyway? [y/N]: " continue_tracked
            if [[ ! "$continue_tracked" =~ ^[Yy]$ ]]; then
                echo "Skipping $file_type generation"
                return 1
            fi
        fi
    fi

    if [ "$FORCE" = true ]; then
        print_warning "Overwriting existing $file_type (--force)"
        return 0
    fi

    print_warning "$file_type already exists: $file"
    read -p "Overwrite? [y/N]: " overwrite
    if [[ "$overwrite" =~ ^[Yy]$ ]]; then
        return 0
    else
        echo "Skipping $file_type generation"
        return 1
    fi
}

# Paths
MAIN_PROJECT_ROOT=$(git worktree list | head -1 | awk '{print $1}')
COMPOSE_TEMPLATE="$MAIN_PROJECT_ROOT/.claude/commands/worktree/docker-compose.celery.yml.template"
DOCKERFILE_TEMPLATE="$MAIN_PROJECT_ROOT/.claude/commands/worktree/Dockerfile.celery.template"

# Get docker directory from docker_env_path (e.g., "backend/docker/.env" -> "backend/docker")
DOCKER_ENV_PATH_CONFIG=$(get_config_value "project.docker_env_path" "docker/.env")
DOCKER_DIR=$(dirname "$DOCKER_ENV_PATH_CONFIG")

COMPOSE_OUTPUT="$WORKTREE_PATH/$DOCKER_DIR/docker-compose.celery.yml"
DOCKERFILE_OUTPUT="$WORKTREE_PATH/$DOCKER_DIR/Dockerfile.celery"

# Get docker env path from config, fallback to docker/.env
DOCKER_ENV_PATH=$(get_config_value "project.docker_env_path" "docker/.env")
ENV_FILE="$MAIN_PROJECT_ROOT/$DOCKER_ENV_PATH"

# Get backend directory from config
BACKEND_DIR=$(get_config_value "project.backend_dir" "backend")

# Validate templates exist
if [ ! -f "$COMPOSE_TEMPLATE" ]; then
    print_error "Compose template not found: $COMPOSE_TEMPLATE"
    exit 1
fi

if [ ! -f "$DOCKERFILE_TEMPLATE" ]; then
    print_error "Dockerfile template not found: $DOCKERFILE_TEMPLATE"
    exit 1
fi

# Validate env file exists
if [ ! -f "$ENV_FILE" ]; then
    print_error "Environment file not found: $ENV_FILE"
    exit 1
fi

print_header "Generating Celery Docker Configuration"
echo "Templates:"
echo "  Dockerfile: $DOCKERFILE_TEMPLATE"
echo "  Compose:    $COMPOSE_TEMPLATE"
echo "Outputs:"
echo "  Dockerfile: $DOCKERFILE_OUTPUT"
echo "  Compose:    $COMPOSE_OUTPUT"
echo ""

# Load environment variables from main project
set -a  # Auto-export all variables
source "$ENV_FILE"
set +a

# Load worktree configuration for database name
load_worktree_config "$AGENT_COLOR"

# Override PROJECT_NAME with worktree configuration (source of truth for worktree system)
# This ensures consistent naming across all worktree scripts
PROJECT_NAME=$(get_project_name)
if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "null" ]; then
    print_warning "PROJECT_NAME not found in worktree config, using fallback"
    PROJECT_NAME="agent_observer"
fi

# Detect or get Docker network name
DOCKER_NETWORK=$(get_config_value "infrastructure.docker_network" "")
if [ -z "$DOCKER_NETWORK" ]; then
    # Auto-detect: try multiple naming patterns
    # Remove underscores from PROJECT_NAME for flexible matching
    PROJECT_NAME_NORMALIZED=$(echo "$PROJECT_NAME" | tr -d '_')

    # Try exact match first, then normalized version
    DOCKER_NETWORK=$(docker network ls --format '{{.Name}}' | grep -iE "^${PROJECT_NAME}[_]?network$" | head -1)

    if [ -z "$DOCKER_NETWORK" ]; then
        # Try normalized version (without underscores)
        DOCKER_NETWORK=$(docker network ls --format '{{.Name}}' | grep -iE "^${PROJECT_NAME_NORMALIZED}[_]?network$" | head -1)
    fi

    if [ -z "$DOCKER_NETWORK" ]; then
        print_error "Could not auto-detect Docker network for project '${PROJECT_NAME}'"
        print_error ""
        print_error "Available networks:"
        docker network ls
        print_error ""
        print_error "Fix by either:"
        print_error "  1. Creating the network: docker network create ${PROJECT_NAME}_network"
        print_error "  2. Setting explicitly in worktree.config.yaml:"
        print_error "     infrastructure:"
        print_error "       docker_network: your_network_name"
        exit 1
    fi

    echo "✓ Auto-detected Docker network: $DOCKER_NETWORK"
else
    echo "✓ Using configured Docker network: $DOCKER_NETWORK"
fi

# Get Redis URL from config (defaults to shared Redis on localhost:6380)
REDIS_URL=$(get_config_value "infrastructure.redis_url" "redis://localhost:6380/0")
echo "✓ Using Redis URL: $REDIS_URL"

# Export variables for envsubst
export PROJECT_NAME
export AGENT_COLOR
export BACKEND_DIR
export DOCKER_NETWORK
export REDIS_URL
export POSTGRES_HOST
export POSTGRES_PORT
export POSTGRES_PASSWORD
export POSTGRES_DB="${PROJECT_NAME}_${AGENT_COLOR}"  # Worktree-specific database
export OPENAI_API_KEY
export AZURE_OPENAI_ENDPOINT
export AZURE_OPENAI_API_KEY
export OPENAI_API_VERSION
export ANTHROPIC_API_KEY
export OLLAMA_BASE_URL
export BEDROCK_AWS_ACCESS_KEY_ID
export BEDROCK_AWS_SECRET_ACCESS_KEY
export BEDROCK_AWS_REGION
export GOOGLE_API_KEY
export GOOGLE_APPLICATION_CREDENTIALS
export GOOGLE_VERTEX_AI_LOCATION

# Ensure output directory exists
mkdir -p "$(dirname "$DOCKERFILE_OUTPUT")"

# Generate Dockerfile.celery
if should_generate_file "$DOCKERFILE_OUTPUT" "Dockerfile.celery"; then
    sed "s|{{BACKEND_DIR}}|$BACKEND_DIR|g" "$DOCKERFILE_TEMPLATE" > "$DOCKERFILE_OUTPUT"
    print_success "Generated: $DOCKERFILE_OUTPUT"
fi

# Generate docker-compose.celery.yml
if should_generate_file "$COMPOSE_OUTPUT" "docker-compose.celery.yml"; then
    envsubst < "$COMPOSE_TEMPLATE" > "$COMPOSE_OUTPUT"
    print_success "Generated: $COMPOSE_OUTPUT"
fi

# Patch worker/config.py to check REDIS_URL environment variable
# This allows worktrees to use shared Redis instead of PROJECT_NAME-based Redis
BACKEND_APP_DIR=$(get_config_value "project.backend_app_dir" "backend/app")
WORKER_CONFIG_FILE="$WORKTREE_PATH/$BACKEND_APP_DIR/worker/config.py"

if [ -f "$WORKER_CONFIG_FILE" ]; then
    # Check if already patched
    if ! grep -q "os.getenv.*REDIS_URL" "$WORKER_CONFIG_FILE"; then
        echo ""
        echo "Patching worker/config.py for REDIS_URL support..."

        # Use sed to insert REDIS_URL check before the PROJECT_NAME fallback
        sed -i.backup '/redis_host = f"{os.getenv.*PROJECT_NAME.*}_redis"/i\
    # Check for explicit REDIS_URL first (worktrees use this)\
    redis_url = os.getenv("REDIS_URL")\
    if redis_url:\
        return redis_url\
\
    # Fallback to PROJECT_NAME construction (main project)
' "$WORKER_CONFIG_FILE"

        print_success "Patched: $WORKER_CONFIG_FILE"
        echo "  - Added REDIS_URL environment variable check"
        echo "  - Backup: ${WORKER_CONFIG_FILE}.backup"
    fi
fi

echo ""
echo "Configuration:"
echo "  Container: ${PROJECT_NAME}_celery_${AGENT_COLOR}"
echo "  Database:  ${POSTGRES_DB}"
echo "  Queue:     ${POSTGRES_DB}_tasks"
echo "  Backend:   ${BACKEND_DIR}"
echo ""
