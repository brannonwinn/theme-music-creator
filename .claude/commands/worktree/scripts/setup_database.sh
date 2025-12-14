#!/bin/bash

# setup_database.sh - Create and initialize a worktree-specific database
#
# Usage:
#   ./setup_database.sh <agent_color>
#
# Examples:
#   ./setup_database.sh blue   # Creates agent_observer_blue database
#   ./setup_database.sh red    # Creates agent_observer_red database

set -e

# Source common configuration and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Validate arguments
if [ $# -ne 1 ]; then
    print_error "Usage: $0 <agent_color>"
    echo ""
    echo "Examples:"
    echo "  $0 blue    # Creates agent_observer_blue database"
    echo "  $0 red     # Creates agent_observer_red database"
    echo "  $0 white   # Creates agent_observer_white database"
    exit 1
fi

AGENT_COLOR="$1"

# Validate agent color
validate_color "$AGENT_COLOR"

# Get worktree path
WORKTREE_PATH=$(get_worktree_path "$AGENT_COLOR")

# Check if worktree exists
if [ ! -d "$WORKTREE_PATH" ]; then
    print_error "Worktree for color '$AGENT_COLOR' doesn't exist at: $WORKTREE_PATH"
    exit 1
fi

# Load configuration (sets BACKEND_PORT, FRONTEND_PORT, DATABASE_NAME)
load_worktree_config "$AGENT_COLOR"

# Load directory configuration
# Use backend_app_dir for .env files, backend_project_dir for migrations
BACKEND_APP_DIR=$(get_backend_app_dir)
BACKEND_PROJECT_DIR=$(get_backend_project_dir)

# Ensure we use the worktree's virtual environment
export VIRTUAL_ENV="$WORKTREE_PATH/.venv"
export PATH="$VIRTUAL_ENV/bin:$PATH"

cd "$WORKTREE_PATH"

# Load environment variables from worktree backend app directory
if [ ! -f "$BACKEND_APP_DIR/.env" ]; then
    print_error "$BACKEND_APP_DIR/.env not found in worktree"
    echo "Run generate_worktree_env.sh first"
    exit 1
fi

# Source database connection info from worktree's backend .env
export $(grep -E '^DATABASE_' "$BACKEND_APP_DIR/.env" | xargs)

# Validate required env vars
if [ -z "$DATABASE_HOST" ] || [ -z "$DATABASE_PORT" ] || [ -z "$DATABASE_USER" ] || [ -z "$DATABASE_PASSWORD" ]; then
    print_error "Missing database connection variables in $BACKEND_APP_DIR/.env"
    echo "Required: DATABASE_HOST, DATABASE_PORT, DATABASE_USER, DATABASE_PASSWORD"
    exit 1
fi

# DATABASE_NAME is already set from load_worktree_config (from JSON)
# No need to compute it - it comes from the config file

# PostgreSQL connection string (without database name for admin operations)
PGPASSWORD="$DATABASE_PASSWORD"
export PGPASSWORD

# Main execution
main() {
    # Get color code for terminal output
    AGENT_COLOR_CODE=$(get_agent_color "$AGENT_COLOR")

    echo ""
    print_header "Database Setup for ${AGENT_COLOR} Worktree"
    echo ""
    echo -e "${AGENT_COLOR_CODE}Database: ${DATABASE_NAME}${NC}"
    echo -e "${AGENT_COLOR_CODE}Host: ${DATABASE_HOST}:${DATABASE_PORT}${NC}"
    echo -e "${AGENT_COLOR_CODE}User: ${DATABASE_USER}${NC}"
    echo ""

    # Step 1: Check if database already exists
    print_header "Step 1: Checking Database"

    DB_STATUS=$(db_status "$DATABASE_NAME")

    if [ "$DB_STATUS" != "NOT_FOUND" ]; then
        print_warning "Database '${DATABASE_NAME}' already exists (migration: $DB_STATUS)"
        read -p "Drop and recreate? [y/N]: " drop_db

        if [[ "$drop_db" =~ ^[Yy]$ ]]; then
            echo "Dropping existing database..."
            if db_drop "$DATABASE_NAME"; then
                print_success "Database dropped"
            else
                print_error "Failed to drop database"
                exit 1
            fi
        else
            print_warning "Skipping database creation"
            echo ""
            print_header "Step 2: Running Migrations"
            # Database exists, just run migrations
            run_migrations
            return 0
        fi
    fi

    # Step 2: Create database
    print_header "Step 2: Creating Database"

    if db_create "$DATABASE_NAME"; then
        print_success "Database '${DATABASE_NAME}' created"
    else
        print_error "Failed to create database"
        exit 1
    fi

    echo ""

    # Step 3: Verify database was created
    print_header "Step 3: Verifying Database"

    DB_STATUS=$(db_status "$DATABASE_NAME")
    if [ "$DB_STATUS" = "NOT_FOUND" ]; then
        print_error "Database verification failed"
        exit 1
    fi

    print_success "Database verified (migration: $DB_STATUS)"
    echo ""

    # Step 4: Copy Supabase schemas
    print_header "Step 4: Copying Supabase Infrastructure"
    copy_supabase_schemas

    echo ""

    # Step 5: Run migrations
    print_header "Step 5: Running Migrations"
    run_migrations
}

copy_supabase_schemas() {
    # Get container name from config
    CONTAINER_NAME=$(get_db_container_name)

    if [ -z "$CONTAINER_NAME" ]; then
        print_error "Could not determine database container name"
        exit 1
    fi

    echo "Detecting schemas in main database (container: $CONTAINER_NAME)..."

    # Get list of all schemas excluding system schemas, public, and temp schemas
    # public schema is where our application migrations run, so we don't copy it
    # Exclude pg_temp_* and pg_toast_temp_* (temporary session schemas)
    SCHEMAS=$(docker exec "$CONTAINER_NAME" psql -U postgres -d postgres -t -c "
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'public', 'pg_toast')
        AND schema_name NOT LIKE 'pg_temp_%'
        AND schema_name NOT LIKE 'pg_toast_temp_%'
        ORDER BY schema_name;
    " | tr -d ' ')

    if [ -z "$SCHEMAS" ]; then
        print_warning "No Supabase schemas found to copy"
        return 0
    fi

    echo "Found schemas to copy:"
    echo "$SCHEMAS" | while read -r schema; do
        echo "  - $schema"
    done
    echo ""

    # Copy each schema
    echo "$SCHEMAS" | while read -r schema; do
        if [ -n "$schema" ]; then
            echo "Copying schema: $schema..."

            # Dump schema structure and data from postgres database
            # Restore to worktree database
            if docker exec "$CONTAINER_NAME" pg_dump -U postgres -n "$schema" postgres | \
               docker exec -i "$CONTAINER_NAME" psql -U postgres -d "$DATABASE_NAME" > /dev/null 2>&1; then
                echo "  ✓ $schema copied"
            else
                print_warning "  ✗ Failed to copy $schema (non-critical)"
            fi
        fi
    done

    print_success "Supabase infrastructure copied to ${DATABASE_NAME}"

    # Copy publications (used for Supabase realtime)
    echo ""
    echo "Copying publications..."
    PUBLICATIONS=$(docker exec "$CONTAINER_NAME" psql -U postgres -d postgres -t -c "
        SELECT pubname FROM pg_publication WHERE pubname != 'supabase_realtime_test';
    " | tr -d ' ')

    if [ -n "$PUBLICATIONS" ]; then
        echo "$PUBLICATIONS" | while read -r pub; do
            if [ -n "$pub" ]; then
                echo "  Copying publication: $pub..."

                # Check if publication is for all tables
                IS_ALL_TABLES=$(docker exec "$CONTAINER_NAME" psql -U postgres -d postgres -t -c "
                    SELECT puballtables FROM pg_publication WHERE pubname = '$pub';
                " | tr -d ' ')

                if [ "$IS_ALL_TABLES" = "t" ]; then
                    # Create publication for all tables
                    PUB_DEF="CREATE PUBLICATION $pub FOR ALL TABLES;"
                else
                    # Create empty publication (migrations will add tables)
                    PUB_DEF="CREATE PUBLICATION $pub;"
                fi

                # Create publication in worktree database
                if docker exec "$CONTAINER_NAME" psql -U postgres -d "$DATABASE_NAME" -c "$PUB_DEF" > /dev/null 2>&1; then
                    echo "    ✓ $pub created"
                else
                    print_warning "    ✗ Failed to create $pub (non-critical)"
                fi
            fi
        done
        echo ""
        print_success "Publications copied"
    else
        echo "  No publications to copy"
    fi
}

run_migrations() {
    # Temporarily update DATABASE_NAME in backend/.env for migrations
    ORIGINAL_DB_NAME="$DATABASE_NAME"

    # Create temporary .env file with new database name
    TMP_ENV_FILE=$(mktemp)
    cp "$BACKEND_APP_DIR/.env" "$TMP_ENV_FILE"

    # Replace DATABASE_NAME in temp file
    if grep -q "^DATABASE_NAME=" "$TMP_ENV_FILE"; then
        sed -i.bak "s/^DATABASE_NAME=.*/DATABASE_NAME=${DATABASE_NAME}/" "$TMP_ENV_FILE"
    else
        echo "DATABASE_NAME=${DATABASE_NAME}" >> "$TMP_ENV_FILE"
    fi

    # Copy migration files from main project (migrations are gitignored)
    echo "Copying migration files from main project..."

    # Get backend PROJECT dir from main project (where migrations are)
    MAIN_BACKEND_PROJECT_DIR=$(cd "$PROJECT_ROOT" && get_backend_project_dir)
    MAIN_MIGRATIONS="$PROJECT_ROOT/$MAIN_BACKEND_PROJECT_DIR/alembic/versions"
    WORKTREE_MIGRATIONS="$BACKEND_PROJECT_DIR/alembic/versions"

    if [ -d "$MAIN_MIGRATIONS" ]; then
        # Copy all .py files except __pycache__
        cp "$MAIN_MIGRATIONS"/*.py "$WORKTREE_MIGRATIONS/" 2>/dev/null || true
        MIGRATION_COUNT=$(ls -1 "$WORKTREE_MIGRATIONS"/*.py 2>/dev/null | wc -l | tr -d ' ')
        print_success "Copied ${MIGRATION_COUNT} migration files"
    else
        print_warning "No migrations found in main project"
    fi

    # Run migrations with temporary .env
    echo "Running Alembic migrations on ${DATABASE_NAME}..."

    # Export vars from temp file
    export $(grep -E '^DATABASE_' "$TMP_ENV_FILE" | xargs)

    # Run migrations from backend APP directory (where alembic.ini is)
    if (cd "$BACKEND_APP_DIR" && uv run alembic upgrade head); then
        print_success "Migrations completed successfully"
    else
        print_error "Migration failed"
        rm -f "$TMP_ENV_FILE" "$TMP_ENV_FILE.bak"
        exit 1
    fi

    # Cleanup
    rm -f "$TMP_ENV_FILE" "$TMP_ENV_FILE.bak"

    echo ""
}

# Summary
print_summary() {
    print_header "Setup Complete"
    print_success "Database '${DATABASE_NAME}' is ready for use"
    echo ""
    echo -e "${AGENT_COLOR_CODE}Next steps:${NC}"
    echo "  1. Update worktree .env with: DATABASE_NAME=${DATABASE_NAME}"
    echo "  2. Start worktree services: ./.claude/scripts/start_worktree.sh"
    echo ""
}

# Run main function
main
print_summary
