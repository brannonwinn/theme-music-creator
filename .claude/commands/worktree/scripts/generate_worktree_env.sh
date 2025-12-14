#!/bin/bash

# generate_worktree_env.sh - Generate .env files for a new worktree (PORTABLE)
#
# This script auto-discovers ALL .env files in the main project and copies them
# to the worktree, applying worktree-specific overrides where needed.
#
# Usage:
#   ./generate_worktree_env.sh <agent_color> <worktree_path>
#
# Examples:
#   ./generate_worktree_env.sh blue ~/projects/agent_observer_blue
#   ./generate_worktree_env.sh red ~/projects/agent_observer_red

set -e

# Source common configuration and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Validate arguments
if [ $# -ne 2 ]; then
    print_error "Usage: $0 <agent_color> <worktree_path>"
    echo ""
    echo "Examples:"
    echo "  $0 blue ~/projects/agent_observer_blue"
    echo "  $0 red ~/projects/agent_observer_red"
    exit 1
fi

AGENT_COLOR="$1"
WORKTREE_PATH="$2"

# Validate agent color
validate_color "$AGENT_COLOR"

# Validate worktree path
if [ ! -d "$WORKTREE_PATH" ]; then
    print_error "Worktree path does not exist: $WORKTREE_PATH"
    exit 1
fi

# Get main project root
MAIN_PROJECT_ROOT="$(git worktree list | head -1 | awk '{print $1}')"

# Load configuration from worktree.config.yaml
load_worktree_config "$AGENT_COLOR"

# Get agent name and color code for terminal output
AGENT_NAME=$(get_agent_name "$AGENT_COLOR")
AGENT_COLOR_CODE=$(get_agent_color "$AGENT_COLOR")

# Get project configuration
PROJECT_NAME=$(get_config_value "project.name" "$(basename "$MAIN_PROJECT_ROOT")")
BACKEND_PROJECT_DIR=$(get_config_value "project.backend_project_dir" "backend")
BACKEND_APP_DIR=$(get_config_value "project.backend_app_dir" "backend/app")
FRONTEND_DIR=$(get_config_value "project.frontend_dir" "frontend")

# ============================================================================
# MAIN FUNCTION
# ============================================================================

main() {
    echo ""
    print_header "Generating Environment Files for ${AGENT_COLOR} Worktree"
    echo ""
    echo -e "${AGENT_COLOR_CODE}Worktree: ${WORKTREE_PATH}${NC}"
    echo -e "${AGENT_COLOR_CODE}Agent Color: ${AGENT_COLOR}${NC}"
    echo -e "${AGENT_COLOR_CODE}Agent Name: ${AGENT_NAME}${NC}"
    echo -e "${AGENT_COLOR_CODE}Backend Port: ${BACKEND_PORT}${NC}"
    echo -e "${AGENT_COLOR_CODE}Frontend Port: ${FRONTEND_PORT}${NC}"
    echo -e "${AGENT_COLOR_CODE}Database: ${DATABASE_NAME}${NC}"
    echo ""

    # Step 1: Auto-discover all .env files in main project
    print_header "Step 1: Discovering .env files in main project"

    local env_files=()
    while IFS= read -r -d '' file; do
        # Get relative path from main project root
        local rel_path="${file#$MAIN_PROJECT_ROOT/}"
        env_files+=("$rel_path")
        echo "  Found: $rel_path"
    done < <(find "$MAIN_PROJECT_ROOT" -type f \( -name ".env" -o -name ".env.*" \) \
        ! -name "*.sample" \
        ! -name "*.example" \
        ! -name "*.template" \
        ! -path "*/node_modules/*" \
        ! -path "*/.git/*" \
        ! -path "*/worktrees/*" \
        ! -path "*/.venv/*" \
        ! -path "*/venv/*" \
        ! -path "*/__pycache__/*" \
        -print0)

    if [ ${#env_files[@]} -eq 0 ]; then
        print_warning "No .env files found in main project"
        echo "This might be normal if your project doesn't use .env files"
        echo ""
    else
        print_success "Found ${#env_files[@]} .env file(s)"
        echo ""
    fi

    # Step 2: Copy and process each .env file
    print_header "Step 2: Copying and processing .env files"
    echo ""

    for rel_path in "${env_files[@]}"; do
        local source_file="$MAIN_PROJECT_ROOT/$rel_path"
        local target_file="$WORKTREE_PATH/$rel_path"
        local target_dir="$(dirname "$target_file")"

        # Create target directory if needed
        mkdir -p "$target_dir"

        # Determine how to process this file based on its path
        process_env_file "$source_file" "$target_file" "$rel_path"
    done

    echo ""

    # Step 3: Final validation - verify critical files were copied
    print_header "Step 3: Validating copied files"
    echo ""

    local validation_errors=0
    local critical_files=(
        "$BACKEND_APP_DIR/.env"
        ".claude/.env"
    )

    for file in "${critical_files[@]}"; do
        if [ ! -f "$WORKTREE_PATH/$file" ]; then
            print_error "MISSING: $file"
            ((validation_errors++))
        else
            echo "  ✓ $file"
        fi
    done

    if [ $validation_errors -gt 0 ]; then
        echo ""
        print_error "$validation_errors critical file(s) missing"
        print_error "Worktree setup cannot proceed without these files"
        exit 1
    fi

    print_success "All critical files validated"
    echo ""
}

# ============================================================================
# PROCESS ENV FILE - Apply smart overrides based on file location
# ============================================================================

process_env_file() {
    local source="$1"
    local target="$2"
    local rel_path="$3"

    echo -e "${BLUE}Processing: ${rel_path}${NC}"

    # Verify source file exists
    if [ ! -f "$source" ]; then
        print_error "Source file not found: $source"
        print_error "This file may not exist in the main project"
        exit 1
    fi

    # Copy the file first
    cp "$source" "$target"

    # Verify the copy was successful
    if [ ! -f "$target" ]; then
        print_error "CRITICAL: Failed to copy $rel_path"
        print_error "  Source: $source"
        print_error "  Target: $target"
        print_error "This will cause worktree setup to fail"
        exit 1
    fi

    # Apply overrides based on file location/type
    local needs_override=false

    # 1. .claude/.env - Override agent-specific values
    if [[ "$rel_path" == ".claude/.env" ]]; then
        override_claude_env "$target"
        needs_override=true
        echo "  ✓ Applied agent overrides (AGENT_COLOR, AGENT_NAME, WORKTREE_NAME)"

    # 2. Backend app .env - Override database and ports
    elif [[ "$rel_path" == *"$BACKEND_APP_DIR"*".env"* ]] || \
         [[ "$rel_path" == "app/.env"* ]] || \
         [[ "$rel_path" == "$BACKEND_PROJECT_DIR/app/.env"* ]]; then
        override_backend_app_env "$target"
        needs_override=true
        echo "  ✓ Applied database override (DATABASE_NAME=${DATABASE_NAME})"

    # 3. Frontend .env - Override API port
    elif [[ "$rel_path" == *"$FRONTEND_DIR"*".env"* ]] || \
         [[ "$rel_path" == "frontend/.env"* ]] || \
         [[ "$rel_path" == "client/.env"* ]]; then
        override_frontend_env "$target"
        needs_override=true
        echo "  ✓ Applied port override (API_PORT=${BACKEND_PORT})"

    # 4. Everything else - Straight copy (docker/.env, root .env, etc.)
    else
        echo "  ✓ Copied as-is (no overrides needed)"
    fi

    echo ""
}

# ============================================================================
# OVERRIDE FUNCTIONS
# ============================================================================

override_claude_env() {
    local target="$1"

    # Update or append agent-specific variables
    update_or_append_env_var "$target" "AGENT_COLOR" "$AGENT_COLOR"
    update_or_append_env_var "$target" "AGENT_NAME" "$AGENT_NAME"
    update_or_append_env_var "$target" "WORKTREE_NAME" "$AGENT_COLOR"
}

override_backend_app_env() {
    local target="$1"

    # Override database name (critical for isolation)
    update_or_append_env_var "$target" "DATABASE_NAME" "$DATABASE_NAME"

    # Override backend port if present
    if grep -q "^BACKEND_PORT=" "$target" || grep -q "^PORT=" "$target"; then
        update_or_append_env_var "$target" "BACKEND_PORT" "$BACKEND_PORT"
        update_or_append_env_var "$target" "PORT" "$BACKEND_PORT"
    fi
}

override_frontend_env() {
    local target="$1"

    # Update various API port variables that might exist
    # Vite projects
    if grep -q "^VITE_API_PORT=" "$target"; then
        sed -i.bak "s/^VITE_API_PORT=.*/VITE_API_PORT=${BACKEND_PORT}/" "$target"
    fi
    if grep -q "^VITE_API_URL=" "$target"; then
        sed -i.bak "s|^VITE_API_URL=.*|VITE_API_URL=http://localhost:${BACKEND_PORT}|" "$target"
    fi

    # Next.js projects
    if grep -q "^NEXT_PUBLIC_API_PORT=" "$target"; then
        sed -i.bak "s/^NEXT_PUBLIC_API_PORT=.*/NEXT_PUBLIC_API_PORT=${BACKEND_PORT}/" "$target"
    fi
    if grep -q "^NEXT_PUBLIC_API_URL=" "$target"; then
        sed -i.bak "s|^NEXT_PUBLIC_API_URL=.*|NEXT_PUBLIC_API_URL=http://localhost:${BACKEND_PORT}|" "$target"
    fi

    # Generic
    if grep -q "^API_PORT=" "$target"; then
        sed -i.bak "s/^API_PORT=.*/API_PORT=${BACKEND_PORT}/" "$target"
    fi
    if grep -q "^API_URL=" "$target"; then
        sed -i.bak "s|^API_URL=.*|API_URL=http://localhost:${BACKEND_PORT}|" "$target"
    fi

    # Clean up backup files
    rm -f "${target}.bak"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

update_or_append_env_var() {
    local file="$1"
    local var_name="$2"
    local var_value="$3"

    if grep -q "^${var_name}=" "$file"; then
        # Variable exists, update it
        sed -i.bak "s|^${var_name}=.*|${var_name}=${var_value}|" "$file"
    else
        # Variable doesn't exist, append it
        echo "${var_name}=${var_value}" >> "$file"
    fi

    # Clean up backup file
    rm -f "${file}.bak"
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
    print_header "Environment Generation Complete"
    print_success "All .env files generated for ${AGENT_COLOR} worktree"
    echo ""
    echo -e "${AGENT_COLOR_CODE}Key overrides applied:${NC}"
    echo "  - Agent: ${AGENT_COLOR} (${AGENT_NAME})"
    echo "  - Database: ${DATABASE_NAME}"
    echo "  - Backend Port: ${BACKEND_PORT}"
    echo "  - Frontend Port: ${FRONTEND_PORT}"
    echo ""
    echo -e "${AGENT_COLOR_CODE}Next steps:${NC}"
    echo "  1. Review generated .env files in worktrees/${PROJECT_NAME}_${AGENT_COLOR}/"
    echo "  2. Install dependencies: /worktree:wt_deps_install ${AGENT_COLOR}"
    echo "  3. Setup database: /worktree:wt_db_create ${AGENT_COLOR}"
    echo "  4. Start services: /worktree:wt_start ${AGENT_COLOR}"
    echo ""
}

# ============================================================================
# RUN
# ============================================================================

main
print_summary
