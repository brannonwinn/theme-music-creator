#!/bin/bash

# delete_worktree.sh - Safely remove a worktree with all associated resources
#
# Usage:
#   ./delete_worktree.sh <agent_color> [options]
#
# Options:
#   --force           Skip safety checks and force deletion
#   --dry-run         Show what would be deleted without actually deleting
#   --keep-database   Preserve the database (can be recovered later)
#   --keep-branch     Don't delete the git branch
#
# Examples:
#   ./delete_worktree.sh blue              # Interactive deletion
#   ./delete_worktree.sh blue --dry-run    # Preview what would be deleted
#   ./delete_worktree.sh blue --force      # Force delete (skip confirmations)

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/common.sh"

# Colors from common.sh are already available
# PROJECT_ROOT from common.sh (MAIN_PROJECT_ROOT) is already available

# Parse arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Usage: $0 <agent_color> [--force] [--dry-run] [--keep-database] [--keep-branch]${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 blue              # Interactive deletion"
    echo "  $0 blue --dry-run    # Preview deletion"
    echo "  $0 blue --force      # Force delete"
    exit 1
fi

AGENT_COLOR="$1"
shift

FORCE=false
DRY_RUN=false
KEEP_DATABASE=false
KEEP_BRANCH=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --keep-database)
            KEEP_DATABASE=true
            shift
            ;;
        --keep-branch)
            KEEP_BRANCH=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Validate agent color
if [ "$AGENT_COLOR" = "main" ]; then
    echo -e "${RED}Cannot delete main worktree!${NC}"
    exit 1
fi

# Validate agent exists in config
if ! validate_color "$AGENT_COLOR"; then
    exit 1
fi

# Functions (print_header, print_success, print_warning, print_error are from common.sh)

print_dry_run() {
    echo -e "${YELLOW}[DRY RUN] $1${NC}"
}

# Get worktree path
get_worktree_path() {
    cd "$PROJECT_ROOT"
    local worktree_path=$(git worktree list --porcelain | grep -A2 "$DB_NAME" | grep "^worktree" | cut -d' ' -f2)
    echo "$worktree_path"
}

# Get current branch for worktree
get_worktree_branch() {
    local worktree_path="$1"
    cd "$worktree_path"
    git rev-parse --abbrev-ref HEAD
}

# Check if branch is pushed to remote
is_branch_pushed() {
    local branch="$1"
    git ls-remote --heads origin "$branch" | grep -q "$branch"
}

# Check for uncommitted changes
has_uncommitted_changes() {
    local worktree_path="$1"
    cd "$worktree_path"
    ! git diff-index --quiet HEAD --
}

# Get list of uncommitted files
get_uncommitted_files() {
    local worktree_path="$1"
    cd "$worktree_path"
    git status --porcelain
}

# Get database name for worktree
get_database_name() {
    local color="$1"

    # Load PROJECT_NAME from config
    local project_name=$(get_project_name 2>/dev/null)

    # Get worktree path to determine BACKEND_DIR
    local worktree_path=$(get_worktree_path "$color")
    local backend_dir=$(get_backend_dir "$worktree_path")

    # Load DATABASE_NAME from backend/.env
    local database_name=""
    if [ -f "$worktree_path/$backend_dir/.env" ]; then
        database_name=$(grep "^DATABASE_NAME=" "$worktree_path/$backend_dir/.env" | cut -d'=' -f2)
    fi

    # Determine base name
    local base_name
    if [ -n "$database_name" ]; then
        base_name="$database_name"
    elif [ -n "$project_name" ]; then
        base_name="$project_name"
    else
        # Use centralized function with warning
        base_name=$(get_project_name)
        if [ -z "$base_name" ] || [ "$base_name" = "null" ]; then
            print_warning "PROJECT_NAME not found in config, using default: agent_observer" >&2
            base_name="agent_observer"
        fi
    fi

    # Return database name with color suffix
    echo "${base_name}_${color}"
}

# Main execution
main() {
    cd "$PROJECT_ROOT"

    # Get database name for this worktree
    DB_NAME=$(get_database_name "$AGENT_COLOR")

    # Get color code for terminal output
    AGENT_COLOR_CODE=$(get_agent_color "$AGENT_COLOR")

    # Convert color to uppercase for display
    local color_upper=$(echo "$AGENT_COLOR" | tr '[:lower:]' '[:upper:]')

    echo ""
    if [ "$DRY_RUN" = true ]; then
        print_header "DRY RUN: Delete Worktree Preview"
    else
        print_header "Delete Worktree: ${color_upper}"
    fi
    echo ""

    # Step 1: Find worktree
    local worktree_path=$(get_worktree_path)

    if [ -z "$worktree_path" ] || [ ! -d "$worktree_path" ]; then
        print_error "Worktree for ${AGENT_COLOR} not found"
        echo ""
        echo "Run: ./.claude/scripts/list_worktrees.sh to see available worktrees"
        exit 1
    fi

    # Get branch info
    local branch=$(get_worktree_branch "$worktree_path")

    # Step 2: Gather information
    print_header "Worktree Information"
    echo ""
    echo -e "${AGENT_COLOR_CODE}Path:${NC} $worktree_path"
    echo -e "${AGENT_COLOR_CODE}Branch:${NC} $branch"
    echo -e "${AGENT_COLOR_CODE}Database:${NC} $DB_NAME"
    echo ""

    # Check git status
    cd "$worktree_path"
    local ahead=$(git rev-list --count HEAD ^main 2>/dev/null || echo "0")
    local behind=$(git rev-list --count main ^HEAD 2>/dev/null || echo "0")

    echo -e "${AGENT_COLOR_CODE}Git Status:${NC}"
    if [ "$ahead" -gt 0 ]; then
        echo -e "  ${YELLOW}$ahead commits ahead of main${NC}"
    fi
    if [ "$behind" -gt 0 ]; then
        echo -e "  ${YELLOW}$behind commits behind main${NC}"
    fi

    # Check for uncommitted changes
    if has_uncommitted_changes "$worktree_path"; then
        echo -e "  ${RED}Uncommitted changes detected!${NC}"
        echo ""
        print_warning "Modified files:"
        get_uncommitted_files "$worktree_path" | head -10
        local total_changes=$(get_uncommitted_files "$worktree_path" | wc -l | tr -d ' ')
        if [ "$total_changes" -gt 10 ]; then
            echo "  ... and $((total_changes - 10)) more files"
        fi
        echo ""

        if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
            print_error "Cannot delete worktree with uncommitted changes"
            echo ""
            echo "Options:"
            echo "  1. Commit changes: git add . && git commit"
            echo "  2. Stash changes: git stash"
            echo "  3. Force delete: $0 ${AGENT_COLOR} --force"
            exit 1
        fi
    else
        echo -e "  ${GREEN}No uncommitted changes${NC}"
    fi

    # Check if branch is pushed
    if ! is_branch_pushed "$branch"; then
        echo -e "  ${YELLOW}Branch not pushed to remote${NC}"
    else
        echo -e "  ${GREEN}Branch pushed to remote${NC}"
    fi

    echo ""

    # Step 3: Confirmation (unless --force or --dry-run)
    if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
        print_header "Confirmation Required"
        echo ""
        print_warning "About to delete worktree: ${color_upper}"
        echo ""
        echo "This will:"
        echo "  - Stop all services (FastAPI, Celery, Next.js)"
        echo "  - Remove git worktree at: $worktree_path"
        if [ "$KEEP_BRANCH" = false ]; then
            echo "  - Delete branch: $branch"
        fi
        if [ "$KEEP_DATABASE" = false ]; then
            echo "  - Drop database: $DB_NAME"
        fi
        echo "  - Remove logs and PID files"
        echo ""

        # Offer to push if not pushed
        if ! is_branch_pushed "$branch"; then
            read -p "Branch not pushed. Push to remote first? [Y/n]: " push_first
            if [[ ! "$push_first" =~ ^[Nn]$ ]]; then
                cd "$worktree_path"
                if git push origin "$branch"; then
                    print_success "Branch pushed to origin"
                else
                    print_error "Failed to push branch"
                    read -p "Continue with deletion anyway? [y/N]: " continue_anyway
                    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                        echo "Aborted"
                        exit 0
                    fi
                fi
                echo ""
            fi
        fi

        read -p "Continue with deletion? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Aborted"
            exit 0
        fi
        echo ""
    fi

    # Step 4: Stop services
    print_header "Stopping Services"
    echo ""

    cd "$PROJECT_ROOT"

    if [ "$DRY_RUN" = true ]; then
        print_dry_run "Would stop services for ${AGENT_COLOR}"
    else
        # Call stop script non-interactively
        "$SCRIPT_DIR/stop_worktree.sh" "$AGENT_COLOR" <<< "y" 2>/dev/null || {
            print_warning "Some services may not have been running"
        }
        print_success "Services stopped"
    fi

    echo ""

    # Step 5: Drop database (optional) - MUST happen before removing worktree
    if [ "$KEEP_DATABASE" = false ]; then
        print_header "Dropping Database"
        echo ""

        if [ "$DRY_RUN" = true ]; then
            print_dry_run "Would drop database: $DB_NAME"
        else
            if db_drop "$DB_NAME"; then
                print_success "Database dropped: $DB_NAME"
            else
                print_warning "Failed to drop database (may not exist)"
            fi
        fi

        echo ""
    else
        print_warning "Keeping database: $DB_NAME"
        local db_container=$(detect_supabase_container)
        if [ -n "$db_container" ]; then
            echo "  To drop later: docker exec $db_container psql -U postgres -d postgres -c 'DROP DATABASE $DB_NAME;'"
        else
            echo "  To drop later: docker exec <db_container> psql -U postgres -d postgres -c 'DROP DATABASE $DB_NAME;'"
        fi
        echo ""
    fi

    # Step 6: Remove git worktree
    print_header "Removing Git Worktree"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        print_dry_run "Would remove worktree: $worktree_path"
    else
        if git worktree remove "$worktree_path" --force; then
            print_success "Worktree removed"
        else
            print_error "Failed to remove worktree"
            exit 1
        fi
    fi

    echo ""

    # Step 7: Delete branch (optional)
    if [ "$KEEP_BRANCH" = false ]; then
        print_header "Deleting Branch"
        echo ""

        if [ "$DRY_RUN" = true ]; then
            print_dry_run "Would delete branch: $branch"
            if is_branch_pushed "$branch"; then
                print_dry_run "Would delete remote branch: origin/$branch"
            fi
        else
            # Delete local branch
            if git branch -D "$branch" 2>/dev/null; then
                print_success "Local branch deleted: $branch"
            else
                print_warning "Failed to delete local branch (may not exist)"
            fi

            # Delete remote branch if pushed
            if is_branch_pushed "$branch"; then
                if git push origin --delete "$branch" 2>/dev/null; then
                    print_success "Remote branch deleted: origin/$branch"
                else
                    print_warning "Failed to delete remote branch"
                fi
            fi
        fi

        echo ""
    fi

    # Step 8: Clean up logs/PIDs
    print_header "Cleaning Up Logs"
    echo ""

    cd "$PROJECT_ROOT"

    if [ "$DRY_RUN" = true ]; then
        print_dry_run "Would delete log files:"
        [ -f "logs/fastapi_${AGENT_COLOR}.log" ] && print_dry_run "  - logs/fastapi_${AGENT_COLOR}.log"
        [ -f "logs/celery_${AGENT_COLOR}.log" ] && print_dry_run "  - logs/celery_${AGENT_COLOR}.log"
        [ -f "logs/nextjs_${AGENT_COLOR}.log" ] && print_dry_run "  - logs/nextjs_${AGENT_COLOR}.log"
        [ -f "logs/fastapi_${AGENT_COLOR}.pid" ] && print_dry_run "  - logs/fastapi_${AGENT_COLOR}.pid"
        [ -f "logs/celery_${AGENT_COLOR}.pid" ] && print_dry_run "  - logs/celery_${AGENT_COLOR}.pid"
        [ -f "logs/nextjs_${AGENT_COLOR}.pid" ] && print_dry_run "  - logs/nextjs_${AGENT_COLOR}.pid"
    else
        rm -f "logs/fastapi_${AGENT_COLOR}.log"
        rm -f "logs/celery_${AGENT_COLOR}.log"
        rm -f "logs/nextjs_${AGENT_COLOR}.log"
        rm -f "logs/fastapi_${AGENT_COLOR}.pid"
        rm -f "logs/celery_${AGENT_COLOR}.pid"
        rm -f "logs/nextjs_${AGENT_COLOR}.pid"

        print_success "Log files cleaned up"
    fi

    echo ""

    # Summary
    print_header "Summary"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN COMPLETE - No changes were made${NC}"
        echo ""
        echo "Would have deleted:"
    else
        print_success "Worktree ${color_upper} deleted successfully"
        echo ""
        echo "Deleted:"
    fi

    echo "  ✓ Worktree: $worktree_path"
    if [ "$KEEP_BRANCH" = false ]; then
        echo "  ✓ Branch: $branch"
    else
        echo "  - Branch: $branch (kept)"
    fi
    if [ "$KEEP_DATABASE" = false ]; then
        echo "  ✓ Database: $DB_NAME"
    else
        echo "  - Database: $DB_NAME (kept)"
    fi
    echo "  ✓ Logs and PID files"

    echo ""

    if [ "$DRY_RUN" = false ]; then
        echo "To recreate this worktree:"
        echo "  /create_worktree"
        echo ""
    fi
}

# Run main function
main
