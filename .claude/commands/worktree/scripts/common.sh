#!/bin/bash

# common.sh - Shared configuration and functions for worktree scripts
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
#
# This file provides:
# - Path detection (MAIN_PROJECT_ROOT)
# - Configuration file paths (WORKTREE_CONFIG)
# - Color codes for output
# - Common utility functions

set -e

# ============================================================================
# PATH DETECTION
# ============================================================================

# Determine main project root using git (works from anywhere - main or worktree)
MAIN_PROJECT_ROOT="$(git worktree list | head -1 | awk '{print $1}')"

# Backwards compatibility alias (for scripts not yet refactored)
PROJECT_ROOT="$MAIN_PROJECT_ROOT"

# ============================================================================
# CONFIGURATION FILE DETECTION
# ============================================================================

# Detect which configuration file to use (YAML or JSON)
# Priority: YAML > JSON (deprecated)
WORKTREE_CONFIG_YAML="$MAIN_PROJECT_ROOT/.claude/commands/worktree/worktree.config.yaml"
WORKTREE_CONFIG_JSON="$MAIN_PROJECT_ROOT/.claude/commands/worktree/worktree_config.json"

if [ -f "$WORKTREE_CONFIG_YAML" ]; then
    WORKTREE_CONFIG="$WORKTREE_CONFIG_YAML"
    CONFIG_FORMAT="yaml"
elif [ -f "$WORKTREE_CONFIG_JSON" ]; then
    WORKTREE_CONFIG="$WORKTREE_CONFIG_JSON"
    CONFIG_FORMAT="json"
    # Warn about deprecated format (only once per session)
    if [ -z "$WORKTREE_CONFIG_DEPRECATION_WARNED" ]; then
        print_warning "Using deprecated JSON config. Run '/worktree:wt_migrate_config' to upgrade to YAML"
        export WORKTREE_CONFIG_DEPRECATION_WARNED=1
    fi
else
    # No config found - will be created during setup
    WORKTREE_CONFIG=""
    CONFIG_FORMAT="none"
fi

# ============================================================================
# COLOR CODES
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# COMMON FUNCTIONS
# ============================================================================

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# ============================================================================
# CONFIGURATION HELPERS
# ============================================================================

# Get yq command (handles both PATH and common installation locations)
# Usage: YQ_CMD=$(get_yq_cmd)
# Returns: yq command to use, or empty if not found
get_yq_cmd() {
    # Check if yq is in PATH
    if command -v yq &> /dev/null; then
        echo "yq"
        return 0
    fi

    # Check common installation locations
    if [ -f "/opt/homebrew/bin/yq" ]; then
        echo "/opt/homebrew/bin/yq"
        return 0
    fi

    if [ -f "/usr/local/bin/yq" ]; then
        echo "/usr/local/bin/yq"
        return 0
    fi

    # Not found
    return 1
}

# Check if yq is installed (required for YAML config)
# Usage: check_yq_installed
# Returns: 0 if installed, 1 if not (with installation instructions)
check_yq_installed() {
    if get_yq_cmd &> /dev/null; then
        return 0
    fi

    print_error "yq is required for YAML configuration but not installed"
    echo ""
    echo "Install yq:"
    echo "  macOS:  brew install yq"
    echo "  Linux:  wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq"
    echo ""
    echo "Or convert config to JSON (deprecated):"
    echo "  /worktree:wt_migrate_config --to-json"
    return 1
}

# Get configuration value (supports both YAML and JSON)
# Usage: get_config_value <yaml_path>
# Example: get_config_value ".project.name"
# Example: get_config_value ".agents[] | select(.name == \"blue\") | .backend_port"
get_config_value() {
    local path=$1
    local default_value=$2

    if [ -z "$WORKTREE_CONFIG" ] || [ "$CONFIG_FORMAT" = "none" ]; then
        print_error "No configuration file found"
        echo "Run '/worktree:wt_setup' to create configuration"
        return 1
    fi

    local result
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        if ! check_yq_installed; then
            return 1
        fi
        local yq_cmd=$(get_yq_cmd)
        # Add dot prefix for yq if not present
        [[ "$path" != .* ]] && path=".$path"
        result=$("$yq_cmd" "$path" "$WORKTREE_CONFIG" 2>/dev/null)
    elif [ "$CONFIG_FORMAT" = "json" ]; then
        result=$(jq -r "$path" "$WORKTREE_CONFIG" 2>/dev/null)
    fi

    # Return result or default value
    if [ -z "$result" ] || [ "$result" = "null" ]; then
        echo "$default_value"
    else
        echo "$result"
    fi
}

# Get worktree configuration value (backward compatible wrapper)
# Usage: get_worktree_config <color> <key>
# Example: get_worktree_config "blue" "backend_port"
get_worktree_config() {
    local color=$1
    local key=$2

    if [ ! -f "$WORKTREE_CONFIG" ]; then
        print_error "Configuration file not found: $WORKTREE_CONFIG"
        exit 1
    fi

    local value
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        # YAML: agents are in array, find by name
        value=$(get_config_value ".agents[] | select(.name == \"${color}\") | .${key}")
    else
        # JSON (deprecated): old format
        value=$(jq -r ".${color}.${key}" "$WORKTREE_CONFIG" 2>/dev/null)
    fi

    if [ "$value" = "null" ] || [ -z "$value" ]; then
        print_error "Invalid configuration: color='$color', key='$key'"
        exit 1
    fi

    echo "$value"
}

# Get project name from config
# Usage: get_project_name
get_project_name() {
    local project_name=$(get_config_value ".project.name" "")

    if [ -z "$project_name" ] || [ "$project_name" = "null" ]; then
        # Use directory name as fallback
        project_name=$(basename "$MAIN_PROJECT_ROOT")
    fi

    echo "$project_name"
}

# List all configured agents
# Usage: list_agents
# Returns: Space-separated list of agent names
list_agents() {
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        get_config_value ".agents[].name" | tr '\n' ' '
    else
        # JSON (deprecated) or no config: scan existing worktrees
        local project_name=$(get_project_name 2>/dev/null)
        if [ -z "$project_name" ]; then
            # No config at all - scan for worktrees
            if [ -d "$MAIN_PROJECT_ROOT/worktrees" ]; then
                # Extract agent names from worktree directory names
                # Format: {project_name}_{agent_name}
                ls -1 "$MAIN_PROJECT_ROOT/worktrees" 2>/dev/null | \
                    sed 's/.*_//' | \
                    tr '\n' ' '
            else
                # No worktrees exist yet - return empty
                echo ""
            fi
        else
            # JSON config exists, try to read from it
            if [ -f "$WORKTREE_CONFIG" ]; then
                jq -r 'keys[]' "$WORKTREE_CONFIG" 2>/dev/null | tr '\n' ' '
            else
                # Config missing, scan worktrees as fallback
                if [ -d "$MAIN_PROJECT_ROOT/worktrees" ]; then
                    ls -1 "$MAIN_PROJECT_ROOT/worktrees" 2>/dev/null | \
                        sed "s/${project_name}_//" | \
                        tr '\n' ' '
                else
                    echo ""
                fi
            fi
        fi
    fi
}

# Get agent display name
# Usage: get_agent_display_name <agent_name>
get_agent_display_name() {
    local agent_name=$1

    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        local display_name=$(get_config_value ".agents[] | select(.name == \"${agent_name}\") | .display_name")
        if [ -n "$display_name" ] && [ "$display_name" != "null" ]; then
            echo "$display_name"
        else
            # Fallback: capitalize agent name
            echo "${agent_name^} Agent"
        fi
    else
        # JSON (deprecated): use old hardcoded function
        get_agent_name "$agent_name"
    fi
}

# Load all configuration for a specific color into variables
# Usage: load_worktree_config <color>
# Sets: BACKEND_PORT, FRONTEND_PORT, DATABASE_NAME
load_worktree_config() {
    local color=$1

    BACKEND_PORT=$(get_worktree_config "$color" "backend_port")
    FRONTEND_PORT=$(get_worktree_config "$color" "frontend_port")
    DATABASE_NAME=$(get_worktree_config "$color" "database_name")
}

# Get agent name for a color
# Usage: get_agent_name <color>
get_agent_name() {
    case "$1" in
        blue) echo "Blue Guardian" ;;
        red) echo "Red Sentinel" ;;
        white) echo "White Oracle" ;;
        *) echo "Agent" ;;
    esac
}

# Get terminal color code for an agent color
# Usage: AGENT_COLOR_CODE=$(get_agent_color <color>)
# Returns: The appropriate ANSI color code for the agent
get_agent_color() {
    case "$1" in
        blue) echo "$BLUE" ;;
        red) echo "$RED" ;;
        white) echo "$NC" ;;  # White/default uses no color (plain text)
        main) echo "$GREEN" ;;
        *) echo "$BLUE" ;;  # Default to blue
    esac
}

# Validate agent name argument
# Usage: validate_agent <agent_name>
validate_agent() {
    local agent_name=$1

    # Check if "main" (always valid)
    if [ "$agent_name" = "main" ]; then
        return 0
    fi

    # Check if agent exists in config
    local agents=$(list_agents)
    for agent in $agents; do
        if [ "$agent" = "$agent_name" ]; then
            return 0
        fi
    done

    # Not found
    print_error "Agent '$agent_name' not found in config"
    echo "Available agents: main $agents"
    return 1
}

# Backward compatibility: validate_color() calls validate_agent()
# Usage: validate_color <color>
validate_color() {
    validate_agent "$1"
}

# Auto-detect agent color from current working directory path
# Usage: AGENT_COLOR=$(detect_agent_color)
# Returns: Agent name if detected, "main" if in main project, empty if cannot detect
detect_agent_color() {
    local cwd=$(pwd)

    # Check if in main project root
    # Only check against MAIN_PROJECT_ROOT (not PROJECT_ROOT which may be overwritten by calling script)
    if [ "$cwd" = "$MAIN_PROJECT_ROOT" ]; then
        echo "main"
        return 0
    fi

    # Get list of all configured agents
    local agents=$(list_agents)

    # Check if current path contains any agent name
    for agent in $agents; do
        if [[ "$cwd" == *"_${agent}"* ]] || [[ "$cwd" == *"/${agent}/"* ]] || [[ "$cwd" == *"/${agent}" ]]; then
            echo "$agent"
            return 0
        fi
    done

    # Couldn't detect - return main as safe default
    echo "main"
    return 0
}

# Get worktree path for a color
# Usage: get_worktree_path <color>
get_worktree_path() {
    local color=$1

    if [ "$color" = "main" ]; then
        echo "$MAIN_PROJECT_ROOT"
        return
    fi

    # Get PROJECT_NAME from config
    local project_name=$(get_project_name 2>/dev/null)

    if [ -z "$project_name" ] || [ "$project_name" = "null" ]; then
        print_warning "PROJECT_NAME not found in config, using directory name" >&2
        project_name=$(basename "$MAIN_PROJECT_ROOT")
    fi

    echo "$MAIN_PROJECT_ROOT/worktrees/${project_name}_${color}"
}

# Get backend PROJECT directory path (where pyproject.toml is)
# Usage: BACKEND_PROJECT_DIR=$(get_backend_project_dir)
# Returns: Backend project directory (e.g., "backend", "server", "api")
get_backend_project_dir() {
    # Check config first (new format)
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        local config_value=$(get_config_value ".project.backend_project_dir" 2>/dev/null)
        if [ -n "$config_value" ] && [ "$config_value" != "null" ]; then
            echo "$config_value"
            return 0
        fi
    fi

    # Fallback: try to detect
    local detected=$(detect_backend_dir)
    if [ -n "$detected" ]; then
        echo "$detected"
        return 0
    fi

    # Last resort: default to "backend"
    echo "backend"
}

# Get backend APP directory path (where main.py is)
# Usage: BACKEND_APP_DIR=$(get_backend_app_dir)
# Returns: Backend app directory (e.g., "backend/app", "app", "src")
get_backend_app_dir() {
    # Check config first (new format)
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        local config_value=$(get_config_value ".project.backend_app_dir" 2>/dev/null)
        if [ -n "$config_value" ] && [ "$config_value" != "null" ]; then
            echo "$config_value"
            return 0
        fi
    fi

    # Fallback: try to detect or use project dir
    local detected=$(detect_backend_app_dir)
    if [ -n "$detected" ]; then
        echo "$detected"
        return 0
    fi

    # Last resort: assume same as project dir
    get_backend_project_dir
}

# DEPRECATED: Get backend directory path (for backward compatibility)
# Usage: BACKEND_DIR=$(get_backend_dir <worktree_path>)
# Returns: Backend directory name (e.g., "app", "backend", "server")
# NOTE: This function is deprecated. Use get_backend_project_dir() or get_backend_app_dir() instead.
get_backend_dir() {
    local worktree_path=$1

    # Read from config only
    local backend_dir=$(get_backend_app_dir)

    echo "$backend_dir"
}

# Get frontend directory path (relative to worktree root)
# Usage: FRONTEND_DIR=$(get_frontend_dir <worktree_path>)
# Returns: Frontend directory name (e.g., "frontend", "client", "web")
get_frontend_dir() {
    local worktree_path=$1

    # Read from config
    local frontend_dir=$(get_config_value ".project.frontend_dir" "frontend")

    echo "$frontend_dir"
}

# Get AI docs directory path (relative to worktree root)
# Usage: AI_DOCS_DIR=$(get_ai_docs_dir)
# Returns: AI docs directory (e.g., "backend/ai_docs", "ai_docs")
get_ai_docs_dir() {
    # Check config first
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        local config_value=$(get_config_value ".project.ai_docs_dir" 2>/dev/null)
        if [ -n "$config_value" ] && [ "$config_value" != "null" ]; then
            echo "$config_value"
            return 0
        fi
    fi

    # Fallback: try to detect
    local detected=$(detect_ai_docs_dir)
    if [ -n "$detected" ]; then
        echo "$detected"
        return 0
    fi

    # Last resort: default to "ai_docs" (generic default)
    echo "ai_docs"
}

# Detect AI docs directory
# Usage: detect_ai_docs_dir
# Returns: AI docs directory path relative to project root, or empty if not found
# Priority: backend/ai_docs > ai_docs > docs/ai
detect_ai_docs_dir() {
    local search_paths=(
        "backend/ai_docs"
        "ai_docs"
        "docs/ai"
    )

    for path in "${search_paths[@]}"; do
        local full_path="${MAIN_PROJECT_ROOT}/${path}"
        if [ -d "$full_path" ]; then
            echo "$path"
            return 0
        fi
    done

    # Not found
    return 1
}

# Validate that required directories exist
# Usage: validate_project_dirs <worktree_path>
# Returns: 0 if backend exists (frontend is optional), 1 if backend missing
validate_project_dirs() {
    local worktree_path=$1
    local backend_dir=$(get_backend_dir "$worktree_path")
    local frontend_dir=$(get_frontend_dir "$worktree_path")

    if [ ! -d "$worktree_path/$backend_dir" ]; then
        print_error "Backend directory not found: $backend_dir"
        echo "Expected path: $worktree_path/$backend_dir"
        return 1
    fi

    # Frontend is optional
    if [ ! -d "$worktree_path/$frontend_dir" ]; then
        print_warning "Frontend directory not found: $frontend_dir (optional, will skip frontend setup)"
    fi

    return 0
}

# ============================================================================
# AUTO-DETECTION FUNCTIONS
# ============================================================================

# Detect Supabase container name
# Usage: detect_supabase_container
# Returns: Container name if found, empty string if not found
# Priority: config value > supabase-shared-db > supabase-db > {project}_supabase-db
detect_supabase_container() {
    # Check config first
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        local config_value=$(get_config_value ".database.container_name" 2>/dev/null)
        if [ -n "$config_value" ] && [ "$config_value" != "null" ]; then
            # Verify container actually exists
            if docker ps --filter "name=^${config_value}$" --format '{{.Names}}' 2>/dev/null | grep -q "^${config_value}$"; then
                echo "$config_value"
                return 0
            fi
        fi
    fi

    # Try common patterns in priority order
    local containers=(
        "supabase-shared-db"
        "supabase-db"
    )

    for container in "${containers[@]}"; do
        if docker ps --filter "name=^${container}$" --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
            echo "$container"
            return 0
        fi
    done

    # Try project-specific pattern
    local project_name=$(get_project_name 2>/dev/null)
    if [ -n "$project_name" ] && [ "$project_name" != "null" ]; then
        local project_container="${project_name}_supabase-db"
        if docker ps --filter "name=^${project_container}$" --format '{{.Names}}' 2>/dev/null | grep -q "^${project_container}$"; then
            echo "$project_container"
            return 0
        fi
    fi

    # Not found
    return 1
}

# Detect backend PROJECT directory (where pyproject.toml is)
# Usage: detect_backend_dir
# Returns: Backend project directory path relative to project root, or empty if not found
# Priority: config value > auto-detection
detect_backend_dir() {
    # Check config first (new format: backend_project_dir)
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        local config_value=$(get_config_value ".project.backend_project_dir" 2>/dev/null)
        if [ -n "$config_value" ] && [ "$config_value" != "null" ]; then
            echo "$config_value"
            return 0
        fi
        # Fallback to old format for backward compatibility
        config_value=$(get_config_value ".project.backend_dir" 2>/dev/null)
        if [ -n "$config_value" ] && [ "$config_value" != "null" ]; then
            echo "$config_value"
            return 0
        fi
    fi

    # Auto-detect by looking for Python project files (pyproject.toml, requirements.txt)
    local search_paths=(
        "backend"
        "server"
        "api"
        "app"
        "src"
        "."
    )

    for path in "${search_paths[@]}"; do
        local full_path="${MAIN_PROJECT_ROOT}/${path}"
        # Check for Python project indicators
        if [ -f "${full_path}/pyproject.toml" ] || [ -f "${full_path}/requirements.txt" ] || [ -f "${full_path}/setup.py" ]; then
            echo "$path"
            return 0
        fi
    done

    # Not found
    return 1
}

# Detect backend APP directory (where main.py or app entry point is)
# Usage: detect_backend_app_dir
# Returns: Backend app directory path relative to project root, or empty if not found
# Priority: config value > auto-detection
detect_backend_app_dir() {
    # Check config first (new format: backend_app_dir)
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        local config_value=$(get_config_value ".project.backend_app_dir" 2>/dev/null)
        if [ -n "$config_value" ] && [ "$config_value" != "null" ]; then
            echo "$config_value"
            return 0
        fi
    fi

    # Auto-detect by looking for FastAPI/Flask app files
    local search_paths=(
        "backend/app"
        "app"
        "backend/src"
        "src"
        "backend"
        "server"
        "api"
    )

    for path in "${search_paths[@]}"; do
        local full_path="${MAIN_PROJECT_ROOT}/${path}"
        # Check for app entry point indicators
        if [ -f "${full_path}/main.py" ] || [ -f "${full_path}/app.py" ] || [ -f "${full_path}/__init__.py" ]; then
            echo "$path"
            return 0
        fi
    done

    # Not found - fall back to project directory
    return 1
}

# Detect frontend directory
# Usage: detect_frontend_dir
# Returns: Frontend directory path relative to project root, empty if not found (optional)
# Priority: config value > auto-detection
detect_frontend_dir() {
    # Check config first
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        local config_value=$(get_config_value ".project.frontend_dir" 2>/dev/null)
        if [ -n "$config_value" ] && [ "$config_value" != "null" ]; then
            echo "$config_value"
            return 0
        fi
    fi

    # Auto-detect by looking for package.json
    local search_paths=(
        "frontend"
        "client"
        "web"
        "ui"
        "app"
    )

    for path in "${search_paths[@]}"; do
        local full_path="${MAIN_PROJECT_ROOT}/${path}"
        if [ -f "${full_path}/package.json" ]; then
            # Verify it's a frontend project (has Next.js, React, Vue, etc.)
            if grep -q -E '\"(next|react|vue|angular|svelte)\"' "${full_path}/package.json" 2>/dev/null; then
                echo "$path"
                return 0
            fi
        fi
    done

    # Frontend is optional, return empty (success)
    echo ""
    return 0
}

# Detect if project uses RLS (Row Level Security)
# Usage: detect_rls_usage
# Returns: 0 if RLS detected, 1 if not
detect_rls_usage() {
    local backend_dir=$(detect_backend_dir)
    if [ -z "$backend_dir" ]; then
        return 1
    fi

    # Check for RLS in Alembic migrations
    if [ -d "${MAIN_PROJECT_ROOT}/${backend_dir}/alembic/versions" ]; then
        if grep -r -q -E "(CREATE POLICY|ENABLE ROW LEVEL SECURITY|ALTER TABLE.*ENABLE ROW LEVEL SECURITY)" \
            "${MAIN_PROJECT_ROOT}/${backend_dir}/alembic/versions/" 2>/dev/null; then
            return 0
        fi
    fi

    # Check for multi-tenancy indicators in models
    if [ -f "${MAIN_PROJECT_ROOT}/${backend_dir}/database/models.py" ]; then
        if grep -q -E "(org_id|tenant_id|organization_id)" \
            "${MAIN_PROJECT_ROOT}/${backend_dir}/database/models.py" 2>/dev/null; then
            return 0
        fi
    fi

    # Check for models directory
    if [ -d "${MAIN_PROJECT_ROOT}/${backend_dir}/database/models" ]; then
        if grep -r -q -E "(org_id|tenant_id|organization_id)" \
            "${MAIN_PROJECT_ROOT}/${backend_dir}/database/models/" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Recommend isolation strategy based on project setup
# Usage: recommend_isolation_strategy
# Returns: "separate_databases" or "rls"
# Always recommends separate_databases (confirmed architecture decision)
recommend_isolation_strategy() {
    local setup_type="unknown"
    local has_rls="no"

    # Detect Supabase setup type
    local container=$(detect_supabase_container)
    if [ -n "$container" ]; then
        if [[ "$container" == *"shared"* ]]; then
            setup_type="shared"
        else
            setup_type="standalone"
        fi
    fi

    # Detect RLS usage
    if detect_rls_usage; then
        has_rls="yes"
    fi

    # Output recommendation with reasoning
    echo "separate_databases"

    # Print reasoning to stderr (visible but not captured in variable assignments)
    {
        echo ""
        echo "Recommendation: separate_databases"
        echo "Reasoning:"
        echo "  - Supabase setup: $setup_type"
        echo "  - RLS detected: $has_rls"
        echo "  - Strategy: Separate databases provide maximum flexibility"
        echo "  - Works for: Multi-org SaaS, single-org apps, no-org apps"
        echo "  - Allows: Multiple test organizations per worktree"
        if [ "$has_rls" = "yes" ]; then
            echo "  - Note: Your app uses RLS for production multi-tenancy"
            echo "    Worktree isolation uses separate databases (no conflict)"
        fi
        echo ""
    } >&2

    return 0
}

# ============================================================================
# DATABASE UTILITIES (Read-only status checks)
# ============================================================================

# Check database status and migration version
# Usage: status=$(db_status <database_name>)
# Returns:
#   - "NOT_FOUND" if database doesn't exist
#   - "NO_MIGRATIONS" if database exists but no migrations applied
#   - "<version_hash>" if database exists with migrations (e.g., "abc123def")
db_status() {
    local db_name=$1

    # Get database container dynamically
    local db_container=$(detect_supabase_container)
    if [ -z "$db_container" ]; then
        echo "ERROR: Supabase container not found" >&2
        echo "NOT_FOUND"
        return
    fi

    # Check if database exists
    docker exec "$db_container" psql -U postgres -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='${db_name}'" \
        2>/dev/null | grep -q 1

    if [ $? -ne 0 ]; then
        echo "NOT_FOUND"
        return
    fi

    # Database exists - get migration version
    local version=$(docker exec "$db_container" psql -U postgres -d "${db_name}" -tAc \
        "SELECT version_num FROM alembic_version LIMIT 1" \
        2>/dev/null | tr -d '[:space:]')

    if [ -z "$version" ]; then
        echo "NO_MIGRATIONS"
    else
        echo "$version"
    fi
}

# Terminate all connections to a database
# Usage: db_terminate_connections <database_name>
# Returns: 0 (always succeeds, used before dropping databases)
db_terminate_connections() {
    local db_name=$1
    local db_container=$(detect_supabase_container)

    if [ -z "$db_container" ]; then
        return 1
    fi

    docker exec "$db_container" psql -U postgres -d postgres \
        -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${db_name}';" \
        >/dev/null 2>&1 || true

    return 0
}

# Create database
# Usage: db_create <database_name>
# Returns: 0 if successful, 1 if failed
db_create() {
    local db_name=$1
    local db_container=$(detect_supabase_container)

    if [ -z "$db_container" ]; then
        echo "ERROR: Supabase container not found" >&2
        return 1
    fi

    docker exec "$db_container" psql -U postgres -d postgres \
        -c "CREATE DATABASE ${db_name};" 2>/dev/null

    return $?
}

# Drop database if it exists
# Usage: db_drop <database_name>
# Returns: 0 if successful, 1 if failed
db_drop() {
    local db_name=$1
    local db_container=$(detect_supabase_container)

    if [ -z "$db_container" ]; then
        echo "ERROR: Supabase container not found" >&2
        return 1
    fi

    # Terminate connections first
    db_terminate_connections "$db_name"

    # Drop database
    docker exec "$db_container" psql -U postgres -d postgres \
        -c "DROP DATABASE IF EXISTS ${db_name};" 2>/dev/null

    return $?
}

# Get database container name from config or auto-detect
# Usage: container=$(get_db_container_name)
# Returns: Container name (e.g., "supabase-db", "hosthero_supabase-db")
get_db_container_name() {
    # Use detect_supabase_container which reads from config and auto-detects
    local db_container=$(detect_supabase_container)
    echo "$db_container"
}

# ============================================================================
# SERVICE STATUS UTILITIES
# ============================================================================
# Centralized service checking with support for both Docker containers (main)
# and PID files (colored worktrees).
#
# Similar pattern to .claude/hooks/utils/tts_service.py - provides unified
# interface with automatic detection of service type.

# Check if a Docker container is running
# Usage: is_docker_service_running <container_name>
# Returns: 0 if running, 1 if not
is_docker_service_running() {
    local container_name=$1
    docker ps --filter "name=${container_name}" --filter "status=running" --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"
    return $?
}

# Check if a PID file service is running
# Usage: is_pid_service_running <pid_file_path>
# Returns: 0 if running, 1 if not
is_pid_service_running() {
    local pid_file="$1"

    if [ ! -f "$pid_file" ]; then
        return 1
    fi

    local pid=$(cat "$pid_file" 2>/dev/null)
    if [ -z "$pid" ]; then
        return 1
    fi

    if kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if Redis (supabase-shared-redis) is running and accessible
# Usage: is_redis_available
# Returns: 0 if Redis is accessible, 1 if not
is_redis_available() {
    # Check if the shared Redis container is running
    if ! is_docker_service_running "supabase-shared-redis"; then
        return 1
    fi

    # Try to ping Redis from host (port 6380 maps to container port 6379)
    # Use timeout to avoid hanging if Redis is unresponsive
    if command -v redis-cli >/dev/null 2>&1; then
        timeout 2 redis-cli -h localhost -p 6380 ping >/dev/null 2>&1
        return $?
    else
        # If redis-cli not available, just check if container is running
        return 0
    fi
}

# Get Redis status string with color formatting
# Usage: get_redis_status
# Returns: formatted string like "✅ Redis" or "❌ Redis"
get_redis_status() {
    if is_redis_available; then
        echo -e "${GREEN}✅ Redis${NC}"
    else
        echo -e "${RED}❌ Redis${NC}"
    fi
}

# Get the port for a service based on color
# Usage: get_service_port <color> <service_type>
# service_type: "backend" or "frontend"
# Returns: port number
get_service_port() {
    local color=$1
    local service_type=$2

    # Handle main worktree (uses base ports from config or defaults)
    if [ "$color" = "main" ]; then
        if [ "$CONFIG_FORMAT" = "yaml" ]; then
            if [ "$service_type" = "backend" ]; then
                local port=$(get_config_value ".port_config.base_backend_port" 2>/dev/null)
                echo "${port:-6789}"
            elif [ "$service_type" = "frontend" ]; then
                local port=$(get_config_value ".port_config.base_frontend_port" 2>/dev/null)
                echo "${port:-3000}"
            fi
        else
            # JSON/no config fallback
            if [ "$service_type" = "backend" ]; then
                echo "6789"
            elif [ "$service_type" = "frontend" ]; then
                echo "3000"
            fi
        fi
        return 0
    fi

    # For agent worktrees, try to get port from config first
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        local config_port=""
        if [ "$service_type" = "backend" ]; then
            config_port=$(get_config_value ".agents[] | select(.name == \"${color}\") | .backend_port" 2>/dev/null)
        elif [ "$service_type" = "frontend" ]; then
            config_port=$(get_config_value ".agents[] | select(.name == \"${color}\") | .frontend_port" 2>/dev/null)
        fi

        # If explicit port found in config, use it
        if [ -n "$config_port" ] && [ "$config_port" != "null" ]; then
            echo "$config_port"
            return 0
        fi
    fi

    # Fallback: Calculate port using hardcoded offsets (for backward compatibility)
    # This supports old JSON config or agents not explicitly defined in YAML
    local offset
    case "$color" in
        blue) offset=0 ;;
        red) offset=1 ;;
        white) offset=2 ;;
        *) offset=0 ;;
    esac

    if [ "$service_type" = "backend" ]; then
        echo $((6789 + offset * 10))
    elif [ "$service_type" = "frontend" ]; then
        echo $((3000 + offset * 10))
    fi
}

# Check if a service is running on a specific port
# Usage: is_port_in_use <port>
# Returns: 0 if port is in use, 1 if not
is_port_in_use() {
    local port=$1
    lsof -i ":${port}" >/dev/null 2>&1
    return $?
}

# Get Docker container name for a service in the main worktree
# Usage: get_docker_container_name <service>
# service: "api" or "celery_worker"
# Returns: container name based on PROJECT_NAME from docker/.env or config
get_docker_container_name() {
    local service=$1

    # Try to get PROJECT_NAME from docker/.env first (used by docker-compose)
    local docker_env_path="$MAIN_PROJECT_ROOT/backend/docker/.env"
    local docker_project_name=""

    if [ -f "$docker_env_path" ]; then
        docker_project_name=$(grep '^PROJECT_NAME=' "$docker_env_path" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | tr -d ' ')
    fi

    # Fallback to config if docker/.env doesn't have it
    if [ -z "$docker_project_name" ]; then
        docker_project_name=$(get_project_name)
        # Docker doesn't like underscores in some contexts, might need to remove them
        docker_project_name=$(echo "$docker_project_name" | tr -d '_')
    fi

    # Construct container name based on service type
    case "$service" in
        api)
            echo "${docker_project_name}_api"
            ;;
        celery_worker)
            echo "${docker_project_name}_celery_worker"
            ;;
        *)
            echo ""
            return 1
            ;;
    esac
}

# Check if main worktree is using standalone (Docker-based) setup
# Usage: is_standalone_mode
# Returns: 0 if standalone, 1 if not
is_standalone_mode() {
    if [ "$CONFIG_FORMAT" = "yaml" ]; then
        local setup_type=$(get_config_value ".database.setup_type" 2>/dev/null)
        if [ "$setup_type" = "standalone" ]; then
            return 0
        fi
    fi

    # If not explicitly set, check if docker-compose files exist
    if [ -f "$MAIN_PROJECT_ROOT/backend/docker/docker-compose.yml" ]; then
        return 0
    fi

    return 1
}

# Check service status with unified interface
# Usage: check_service_status <color> <service> <worktree_path>
# service: "fastapi", "celery", or "nextjs"
# Returns: 0 if running, 1 if not
check_service_status() {
    local color=$1
    local service=$2
    local worktree_path=$3

    if [ "$color" = "main" ]; then
        # Main worktree: check if using standalone (Docker) mode
        if is_standalone_mode; then
            # Standalone mode: check Docker containers
            case "$service" in
                fastapi)
                    local container_name=$(get_docker_container_name "api")
                    is_docker_service_running "$container_name"
                    return $?
                    ;;
                celery)
                    local container_name=$(get_docker_container_name "celery_worker")
                    is_docker_service_running "$container_name"
                    return $?
                    ;;
                nextjs)
                    # Next.js might run outside Docker even in standalone mode
                    # Check both Docker and port
                    local port=$(get_service_port "$color" "frontend")
                    is_port_in_use "$port"
                    return $?
                    ;;
                *)
                    return 1
                    ;;
            esac
        else
            # Non-standalone mode: check ports (legacy behavior)
            case "$service" in
                fastapi)
                    local port=$(get_service_port "$color" "backend")
                    is_port_in_use "$port"
                    return $?
                    ;;
                celery)
                    local port=$(get_service_port "$color" "backend")
                    # Celery doesn't have a port, check process
                    return 1
                    ;;
                nextjs)
                    local port=$(get_service_port "$color" "frontend")
                    is_port_in_use "$port"
                    return $?
                    ;;
                *)
                    return 1
                    ;;
            esac
        fi
    else
        # Colored worktrees: check ports for more reliable detection
        case "$service" in
            fastapi)
                local port=$(get_service_port "$color" "backend")
                is_port_in_use "$port"
                return $?
                ;;
            nextjs)
                local port=$(get_service_port "$color" "frontend")
                is_port_in_use "$port"
                return $?
                ;;
            celery)
                # Celery runs in Docker container for worktrees
                local PROJECT_NAME=$(get_project_name)
                local container_name="${PROJECT_NAME}_celery_${color}"
                is_docker_service_running "$container_name"
                return $?
                ;;
            *)
                return 1
                ;;
        esac
    fi
}

# Get formatted service status string for all services
# Usage: get_all_services_status <color> <worktree_path>
# Returns: formatted string with all service statuses
get_all_services_status() {
    local color=$1
    local worktree_path=$2

    local fastapi_status="❌"
    local celery_status="❌"
    local nextjs_status="❌"

    local fastapi_port=$(get_service_port "$color" "backend")
    local nextjs_port=$(get_service_port "$color" "frontend")

    # Check FastAPI
    if check_service_status "$color" "fastapi" "$worktree_path"; then
        fastapi_status="${GREEN}✅ FastAPI ($fastapi_port)${NC}"
    else
        fastapi_status="❌ FastAPI"
    fi

    # Check Celery
    if check_service_status "$color" "celery" "$worktree_path"; then
        celery_status="${GREEN}✅ Celery${NC}"
    else
        celery_status="❌ Celery"
    fi

    # Check Next.js (only if frontend directory exists)
    local frontend_dir=$(get_frontend_dir "$worktree_path")
    if [ -d "${worktree_path}/${frontend_dir}" ]; then
        if check_service_status "$color" "nextjs" "$worktree_path"; then
            nextjs_status="${GREEN}✅ Next.js ($nextjs_port)${NC}"
        else
            nextjs_status="❌ Next.js"
        fi
    fi

    echo "$fastapi_status $celery_status $nextjs_status"
}
