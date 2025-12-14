#!/bin/bash

# sync_worktree.sh - Synchronize worktree environment variables and database migrations
#
# Usage:
#   ./sync_worktree.sh                    # Validate .env files only
#   ./sync_worktree.sh --pull             # Pull from main + validate
#   ./sync_worktree.sh --pull --migrate   # Pull + validate + run migrations
#   ./sync_worktree.sh --interactive      # Prompt for missing variables

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common configuration and functions
source "$SCRIPT_DIR/common.sh"

# Get the CURRENT project root (could be main or a worktree)
# This ensures we sync the environment of whichever project we're running from
PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# Load directory configuration
BACKEND_DIR=$(get_backend_dir "$PROJECT_ROOT")
FRONTEND_DIR=$(get_frontend_dir "$PROJECT_ROOT")

# Ensure we use the current project's virtual environment
# This is critical - each worktree has its own .venv
export VIRTUAL_ENV="$PROJECT_ROOT/.venv"
export PATH="$VIRTUAL_ENV/bin:$PATH"

# Parse command line arguments
PULL_MAIN=false
RUN_MIGRATE=false
INTERACTIVE=false
RUN_CODEGEN=false
SYNC_DATA=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --pull)
            PULL_MAIN=true
            shift
            ;;
        --migrate)
            RUN_MIGRATE=true
            shift
            ;;
        --interactive|-i)
            INTERACTIVE=true
            shift
            ;;
        --codegen)
            RUN_CODEGEN=true
            shift
            ;;
        --data)
            SYNC_DATA=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Usage: $0 [--pull] [--migrate] [--codegen] [--data] [--interactive]"
            exit 1
            ;;
    esac
done

# Note: print_header, print_success, print_warning, print_error now come from common.sh

# Check if file exists
check_file_exists() {
    local file_path="$1"
    local file_name="$2"

    if [ ! -f "$file_path" ]; then
        print_error "$file_name not found at: $file_path"
        return 1
    fi
    return 0
}

# Get variables from .env file (handles comments and empty lines)
get_env_vars() {
    local env_file="$1"
    grep -E '^[A-Z_]+=.*$' "$env_file" 2>/dev/null | cut -d'=' -f1 | sort
}

# Get variable names from template (includes commented optional vars)
get_template_vars() {
    local template_file="$1"
    grep -E '^[#]?[A-Z_]+=.*$' "$template_file" 2>/dev/null | sed 's/^#//' | cut -d'=' -f1 | sort
}

# Find missing variables
find_missing_vars() {
    local template_file="$1"
    local env_file="$2"

    if [ ! -f "$env_file" ]; then
        # If .env doesn't exist, all template vars are missing
        get_template_vars "$template_file"
        return
    fi

    comm -23 <(get_template_vars "$template_file") <(get_env_vars "$env_file")
}

# Check if variable is required
is_required_var() {
    local var_name="$1"
    local required_claude_vars=("PROJECT_NAME" "OBSERVABILITY_API_URL" "REDIS_URL")
    local required_app_vars=("DATABASE_HOST" "DATABASE_PORT" "DATABASE_NAME" "DATABASE_USER" "DATABASE_PASSWORD")

    for req_var in "${required_claude_vars[@]}" "${required_app_vars[@]}"; do
        if [ "$var_name" == "$req_var" ]; then
            return 0
        fi
    done
    return 1
}

# Prompt for variable value
prompt_for_var() {
    local var_name="$1"
    local template_file="$2"

    # Get default value from template if exists
    local default_value=$(grep -E "^#?${var_name}=" "$template_file" 2>/dev/null | head -1 | cut -d'=' -f2- | sed 's/^#//')

    if [ -n "$default_value" ]; then
        read -p "Enter ${var_name} [${default_value}]: " var_value
        var_value="${var_value:-$default_value}"
    else
        read -p "Enter ${var_name}: " var_value
    fi

    echo "$var_value"
}

# Add variable to .env file
add_to_env() {
    local env_file="$1"
    local var_name="$2"
    local var_value="$3"

    echo "${var_name}=${var_value}" >> "$env_file"
}

# Validate and sync .env files
sync_env_files() {
    local template_file="$1"
    local env_file="$2"
    local file_label="$3"

    print_header "Checking $file_label"

    if ! check_file_exists "$template_file" "${file_label} template"; then
        return 1
    fi

    # Find missing variables
    local missing_vars=$(find_missing_vars "$template_file" "$env_file")

    if [ -z "$missing_vars" ]; then
        print_success "All variables present in $file_label"
        return 0
    fi

    # Categorize missing vars
    local required_missing=""
    local optional_missing=""

    while IFS= read -r var; do
        if [ -z "$var" ]; then
            continue
        fi

        if is_required_var "$var"; then
            required_missing="${required_missing}${var}\n"
        else
            optional_missing="${optional_missing}${var}\n"
        fi
    done <<< "$missing_vars"

    # Report missing required variables
    if [ -n "$required_missing" ]; then
        print_warning "Missing REQUIRED variables in ${file_label}:"
        echo -e "${YELLOW}${required_missing}${NC}"

        if [ "$INTERACTIVE" = true ]; then
            echo ""
            read -p "Add missing required variables now? [y/N]: " add_vars
            if [[ "$add_vars" =~ ^[Yy]$ ]]; then
                # Create .env if it doesn't exist
                if [ ! -f "$env_file" ]; then
                    touch "$env_file"
                    print_success "Created $env_file"
                fi

                # Prompt for each required variable
                while IFS= read -r var; do
                    if [ -z "$var" ]; then
                        continue
                    fi
                    var_value=$(prompt_for_var "$var" "$template_file")
                    add_to_env "$env_file" "$var" "$var_value"
                    print_success "Added ${var}"
                done <<< "$(echo -e "$required_missing")"
            fi
        else
            print_error "Run with --interactive to add missing variables"
            return 1
        fi
    fi

    # Report missing optional variables
    if [ -n "$optional_missing" ]; then
        print_warning "Missing OPTIONAL variables in ${file_label}:"
        echo -e "${YELLOW}${optional_missing}${NC}"
        echo -e "${BLUE}(Optional variables will be auto-detected or use defaults)${NC}"
    fi

    return 0
}

# Main execution
main() {
    cd "$PROJECT_ROOT"

    echo ""
    print_header "Worktree Environment Sync"
    echo ""

    # Step 1: Git pull if requested
    if [ "$PULL_MAIN" = true ]; then
        print_header "Pulling from main branch"

        # Check current branch
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        echo -e "${BLUE}Current branch: ${current_branch}${NC}"

        # Stash if there are changes
        if ! git diff-index --quiet HEAD --; then
            print_warning "Uncommitted changes detected, stashing..."
            git stash push -m "sync_worktree.sh auto-stash $(date +%Y-%m-%d_%H:%M:%S)"
        fi

        # Pull from main
        echo "Pulling latest changes from main..."
        if git pull origin main --rebase; then
            print_success "Successfully pulled from main"
        else
            print_error "Failed to pull from main"
            exit 1
        fi

        echo ""
    fi

    # Step 2: Validate Claude .env
    if ! sync_env_files \
        "$PROJECT_ROOT/.claude/.env.template" \
        "$PROJECT_ROOT/.claude/.env" \
        ".claude/.env"; then
        print_error "Claude environment validation failed"
        exit 1
    fi
    echo ""

    # Step 3: Validate Backend .env
    if ! sync_env_files \
        "$PROJECT_ROOT/$BACKEND_DIR/.env.example" \
        "$PROJECT_ROOT/$BACKEND_DIR/.env" \
        "$BACKEND_DIR/.env"; then
        print_error "Backend environment validation failed"
        exit 1
    fi
    echo ""

    # Step 4: Run migrations if requested
    if [ "$RUN_MIGRATE" = true ]; then
        print_header "Running Database Migrations"

        # Copy migration files from main project (migrations are gitignored)
        echo "Copying migration files from main project..."
        MAIN_MIGRATIONS="$PROJECT_ROOT/$BACKEND_DIR/alembic/versions"
        WORKTREE_MIGRATIONS="$PROJECT_ROOT/$BACKEND_DIR/alembic/versions"

        # For worktrees, we need to copy from the actual main project root
        # Find the main project by looking for .git file (worktrees have .git file, not directory)
        if [ -f "$PROJECT_ROOT/.git" ]; then
            # This is a worktree, find the main project
            MAIN_PROJECT=$(grep "worktree" "$PROJECT_ROOT/.git" | cut -d' ' -f2 | sed 's|/worktrees/.*||')
            if [ -z "$MAIN_PROJECT" ]; then
                # Fallback: go up from worktrees directory
                MAIN_PROJECT=$(echo "$PROJECT_ROOT" | sed 's|/worktrees/.*||')
            fi
            # Get BACKEND_DIR from main project (might use different structure)
            MAIN_BACKEND_DIR=$(get_backend_dir "$MAIN_PROJECT")
            MAIN_MIGRATIONS="$MAIN_PROJECT/$MAIN_BACKEND_DIR/alembic/versions"
        fi

        if [ -d "$MAIN_MIGRATIONS" ]; then
            # Copy all .py files except __pycache__
            cp "$MAIN_MIGRATIONS"/*.py "$WORKTREE_MIGRATIONS/" 2>/dev/null || true
            MIGRATION_COUNT=$(ls -1 "$WORKTREE_MIGRATIONS"/*.py 2>/dev/null | wc -l | tr -d ' ')
            print_success "Copied ${MIGRATION_COUNT} migration files"
        else
            print_warning "No migrations found in main project"
        fi

        if [ -f "$PROJECT_ROOT/$BACKEND_DIR/migrate.sh" ]; then
            cd "$PROJECT_ROOT/$BACKEND_DIR"
            if uv run ./migrate.sh; then
                print_success "Migrations completed successfully"
            else
                print_error "Migration failed"
                exit 1
            fi
        else
            print_warning "$BACKEND_DIR directory not found, skipping migrations"
        fi

        echo ""
    fi

    # Step 5: Run frontend codegen if requested
    if [ "$RUN_CODEGEN" = true ]; then
        print_header "Regenerating Frontend TypeScript Types"

        # Check if frontend directory exists
        if [ ! -d "$PROJECT_ROOT/$FRONTEND_DIR" ]; then
            print_warning "Frontend directory not found: $FRONTEND_DIR (skipping codegen)"
        else
            # Detect worktree color to determine backend port
            local worktree_color=$(detect_agent_color)
            local backend_port=$(get_service_port "$worktree_color" "backend")

            echo "Detected worktree: $worktree_color"
            echo "Backend port: $backend_port"
            echo ""

            # Check if backend is running on that port
            local openapi_url="http://localhost:${backend_port}/openapi.json"
            echo "Checking if backend is running at: $openapi_url"

            if curl -s --max-time 5 "$openapi_url" > /dev/null 2>&1; then
                print_success "Backend is running"

                # Run codegen with the correct port
                cd "$PROJECT_ROOT/$FRONTEND_DIR"
                echo "Running: npx openapi-typescript-codegen --input $openapi_url --output ./src/types/api.ts --useOptions"

                if npx openapi-typescript-codegen --input "$openapi_url" --output ./src/types/api.ts --useOptions; then
                    print_success "TypeScript types regenerated successfully"
                else
                    print_error "Codegen failed"
                    exit 1
                fi

                cd "$PROJECT_ROOT"
            else
                print_error "Backend is not running on port $backend_port"
                echo ""
                echo "Please start the backend first:"
                echo "  cd $PROJECT_ROOT/$BACKEND_DIR"
                echo "  uv run ./start.sh"
                echo ""
                echo "Then re-run with --codegen flag"
                exit 1
            fi
        fi

        echo ""
    fi

    # Step 6: Sync test data if requested
    if [ "$SYNC_DATA" = true ]; then
        print_header "Syncing Test Data to Worktree Database"

        # Detect worktree color to determine database name
        local worktree_color=$(detect_agent_color)

        if [ "$worktree_color" = "main" ] || [ -z "$worktree_color" ]; then
            print_warning "Cannot sync data: not in a worktree (detected: $worktree_color)"
            echo "Data sync is only available in colored worktrees (blue, red, white, green)"
        else
            # Map color to database name
            local target_database="host_hero_${worktree_color}"

            echo "Detected worktree: $worktree_color"
            echo "Target database: $target_database"
            echo ""

            # Run the sync script directly (bypasses API authentication)
            # Uses backend_project_dir from worktree.config.yaml (e.g., "backend")
            # Scripts are at {backend_project_dir}/scripts/, not {backend_app_dir}/scripts/
            local backend_project_dir=$(get_backend_project_dir)
            local sync_script="$PROJECT_ROOT/$backend_project_dir/scripts/test_worktree_sync.py"

            if [ -f "$sync_script" ]; then
                echo "Syncing test data from main database to $target_database..."
                echo ""

                # Run the Python sync script from backend project directory
                if (cd "$PROJECT_ROOT/$backend_project_dir" && uv run python scripts/test_worktree_sync.py "$target_database"); then
                    print_success "Data sync completed"
                else
                    print_error "Data sync failed"
                    echo ""
                    echo "Check that:"
                    echo "  1. Docker services are running (postgres containers)"
                    echo "  2. Main database has test data (run seed_test_data.py first)"
                    echo "  3. Target database exists: $target_database"
                fi
            else
                print_error "Sync script not found: $sync_script"
                echo ""
                echo "Expected location: $backend_project_dir/scripts/test_worktree_sync.py"
            fi
        fi

        echo ""
    fi

    # Summary
    print_header "Sync Complete"
    print_success "Worktree environment synchronized"

    if [ "$PULL_MAIN" = false ]; then
        echo -e "${BLUE}Tip: Run with --pull to sync code from main${NC}"
    fi

    if [ "$RUN_MIGRATE" = false ]; then
        echo -e "${BLUE}Tip: Run with --migrate to update database schema${NC}"
    fi

    if [ "$RUN_CODEGEN" = false ]; then
        echo -e "${BLUE}Tip: Run with --codegen to regenerate frontend TypeScript types${NC}"
    fi

    if [ "$SYNC_DATA" = false ]; then
        echo -e "${BLUE}Tip: Run with --data to sync test data from main database${NC}"
    fi

    echo ""
}

# Run main function
main
