# Worktree Management Guide

Complete guide for managing parallel development environments using git worktrees with isolated databases, unique ports, and coordinated observability.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Command Reference](#command-reference)
- [Typical Workflow](#typical-workflow)
- [Architecture](#architecture)
- [Migration Workflow](#migration-workflow)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

### What is a Worktree?

A **git worktree** allows multiple branches to be checked out simultaneously in separate directories. This enables:

- **Parallel Development**: Multiple agents (or developers) working on different features simultaneously
- **Isolated Testing**: Test features in isolation without affecting main branch
- **Quick Context Switching**: Switch between features without git stash/checkout
- **Continuous Integration**: Keep main branch stable while developing

### Our Worktree Strategy

**Key Innovation**: Worktrees are **long-lived infrastructure**, not per-feature environments.

- Create N worktrees once (default: blue, red, white - but supports unlimited custom agents)
- Each worktree stays on `main` branch initially
- Create feature branches within worktrees as needed
- Reuse same worktree for multiple tasks over time

**Agent Customization**: The system supports unlimited agents with custom names. While examples use `blue`, `red`, `white`, you can add agents like `alpha`, `beta`, `gamma`, `team1`, `team2`, etc. by editing `.claude/commands/worktree/worktree.config.yaml`.

Each worktree has:
- **Separate database** (`{PROJECT_NAME}_blue`, `{PROJECT_NAME}_red`, etc.)
- **Unique ports** (backend, frontend) to avoid conflicts
- **Isolated environment** (.env files specific to worktree)
- **Shared infrastructure** (Supabase, Redis, Docker services)
- **Shared observability** (events filtered by `agent_color`)

## Quick Start

### Prerequisites (Run Once)

**Verify system health before creating worktrees:**

```bash
# Run comprehensive diagnostics
/worktree:wt_doctor

# Validate configuration
/worktree:wt_validate
```

If doctor finds issues, fix them before proceeding. Use `--fix` flag for auto-fixes:
```bash
./.claude/commands/worktree/scripts/doctor.sh --fix
```

### One-Time Setup (Beginning of Project)

```bash
# Create three persistent worktrees
/worktree:wt_create blue    # ~5 min (full setup)
/worktree:wt_create red     # ~5 min
/worktree:wt_create white   # ~5 min

# Verify all healthy
/worktree:wt_list
```

**What this does:**
- Automatically adds required .gitignore entries (first run only)
- Creates worktree directory (on `main` branch)
- Sets up isolated database with migrations
- Generates environment files with unique ports
- Generates worktree-specific Celery Docker files
- Installs Python and Node dependencies
- Starts all services
- Verifies setup with health checks

**Note**: The first `/worktree:wt_create` automatically adds these entries to `.gitignore`:
- `worktrees/` - Prevents tracking worktree directories
- `docker/docker-compose.celery.yml` - Generated per-worktree
- `docker/Dockerfile.celery` - Generated per-worktree

### Per-Task Workflow (Repeat for Each Feature)

```bash
# Start new task in blue worktree
/worktree:wt_branch blue feature/task-3a-1-1
# ~2 sec (just creates branch)

# Work on feature
cd worktrees/agent_observer_blue
# ... code, commit, push, PR, merge ...

# Start next task (reuses same worktree)
/worktree:wt_branch blue feature/task-3a-2-1
# Same database, deps, services - instant start!
```

### Daily Commands

```bash
# Check all worktrees
/worktree:wt_list

# Check specific worktree
/worktree:wt_status blue

# Sync with main before new branch
/worktree:wt_sync blue --pull --migrate

# View logs
/worktree:wt_logs blue fastapi

# Restart services
/worktree:wt_restart blue
```

## Command Reference

All commands use the namespace syntax: `/worktree:wt_<command>`

### Primary Commands (Daily Use)

| Command | Purpose | Example |
|---------|---------|---------|
| `/worktree:wt_create` | One-time worktree setup | `/worktree:wt_create blue` |
| `/worktree:wt_branch` | Create feature branch | `/worktree:wt_branch blue feature/task-1` |
| `/worktree:wt_list` | Show all worktrees | `/worktree:wt_list` |
| `/worktree:wt_start` | Start services | `/worktree:wt_start blue` |
| `/worktree:wt_stop` | Stop services | `/worktree:wt_stop blue` |
| `/worktree:wt_restart` | Restart services | `/worktree:wt_restart blue` |
| `/worktree:wt_sync` | Sync with main | `/worktree:wt_sync blue --pull --migrate` |
| `/worktree:wt_delete` | Remove worktree | `/worktree:wt_delete blue` |

### Advanced Commands (Granular Control)

| Command | Purpose | Example |
|---------|---------|---------|
| `/worktree:wt_db_create` | Create database only | `/worktree:wt_db_create blue` |
| `/worktree:wt_db_migrate` | Run migrations | `/worktree:wt_db_migrate blue` |
| `/worktree:wt_db_reset` | Reset database | `/worktree:wt_db_reset blue` |
| `/worktree:wt_env_generate` | Generate .env files | `/worktree:wt_env_generate blue` |
| `/worktree:wt_env_validate` | Validate .env | `/worktree:wt_env_validate blue` |
| `/worktree:wt_deps_install` | Install dependencies | `/worktree:wt_deps_install blue` |
| `/worktree:wt_health` | Health check | `/worktree:wt_health blue` |
| `/worktree:wt_logs` | View logs | `/worktree:wt_logs blue fastapi` |

### Diagnostic Commands (Health & Validation)

| Command | Purpose | Example |
|---------|---------|---------|
| `/worktree:wt_doctor` | System health diagnostics | `/worktree:wt_doctor` |
| `/worktree:wt_validate` | Validate configuration | `/worktree:wt_validate` |
| `/worktree:wt_health` | Service health check | `/worktree:wt_health blue` |

### Utility Commands (Information)

| Command | Purpose | Example |
|---------|---------|---------|
| `/worktree:wt_status` | Detailed status | `/worktree:wt_status blue` |
| `/worktree:wt_ports` | Port allocation table | `/worktree:wt_ports` |
| `/worktree:wt_detect` | Detect current context | `/worktree:wt_detect` |

### Verbose Mode

All commands support `--verbose` flag for detailed output (quiet by default):

```bash
/worktree:wt_create blue --verbose
/worktree:wt_branch blue feature/task-1 --verbose
/worktree:wt_health blue --verbose
```

## Typical Workflow

### Phase 1: Project Initialization (Once)

```bash
# In main agent_observer directory
/worktree:wt_create blue
# Output: ✅ Worktree Created Successfully!
#         Worktree: agent_observer_blue
#         Branch: main (use /worktree:wt_branch to create feature branches)
#         Database: agent_observer_blue
#         Service URLs: http://localhost:6799, http://localhost:3010

/worktree:wt_create red
/worktree:wt_create white

# Verify all ready
/worktree:wt_list
# Shows: 🏠 MAIN, 🔵 BLUE, 🔴 RED, ⚪ WHITE
#        All services running, databases connected
```

### Phase 2: Task Assignment (Repeat)

```bash
# Assign Task 3A.1.1 to blue agent
/worktree:wt_branch blue feature/task-3a-1-1
# ✅ Branch 'feature/task-3a-1-1' created successfully
# Ready to work!

# Work in blue worktree
cd worktrees/agent_observer_blue
# Services already running, database ready
# Code, test, commit, push

# Create PR and merge to main
git push origin feature/task-3a-1-1
gh pr create --title "Task 3A.1.1: User Authentication"
# ... PR approved and merged ...

# Assign next task to same worktree
/worktree:wt_sync blue --pull --migrate  # Sync with main
/worktree:wt_branch blue feature/task-3a-2-1
# Instant start - same environment, new branch
```

### Phase 3: Parallel Development

```bash
# Three agents working simultaneously

# Blue: Task 3A.1.1
/worktree:wt_branch blue feature/task-3a-1-1

# Red: Task 3A.1.2 (parallel with blue)
/worktree:wt_branch red feature/task-3a-1-2

# White: Task 3A.1.3 (parallel with both)
/worktree:wt_branch white feature/task-3a-1-3

# All working independently:
# - Separate databases (no data conflicts)
# - Separate ports (no service conflicts)
# - Same codebase (shared main branch)
```

### Morning Routine (Daily)

```bash
# Check status of all worktrees
/worktree:wt_list

# Sync blue worktree with latest main
/worktree:wt_sync blue --pull --migrate

# Start new branch if ready
/worktree:wt_branch blue feature/today-task
```

### End of Day

```bash
# Stop services to free resources (optional)
/worktree:wt_stop blue
/worktree:wt_stop red
/worktree:wt_stop white

# Or leave running - they'll auto-restart on reboot
```

## Architecture

### Directory Structure

```
~/projects/
├── agent_observer/              # Main worktree (main branch)
│   ├── app/
│   │   └── .env                 # DATABASE_NAME=agent_observer
│   ├── .claude/
│   │   └── .env                 # PROJECT_NAME=agent_observer
│   └── ...
├── agent_observer_blue/         # Blue worktree (main, then feature branches)
│   ├── app/
│   │   └── .env                 # DATABASE_NAME=agent_observer_blue
│   ├── .claude/
│   │   └── .env                 # AGENT_COLOR=blue
│   └── ...
├── agent_observer_red/          # Red worktree
│   └── ...
└── agent_observer_white/        # White worktree
    └── ...
```

### Database Architecture

**Shared Supabase PostgreSQL Server:**

```
supabase-shared-db (One PostgreSQL Instance)
├── agent_observer          ← Observability (SHARED, filtered by agent_color)
├── agent_observer_blue     ← Blue's isolated application data
├── agent_observer_red      ← Red's isolated application data
└── agent_observer_white    ← White's isolated application data
```

**Key Points:**
- One PostgreSQL server, multiple databases (lightweight namespaces)
- Observability database is shared, events filtered by `agent_color` field
- Application databases are isolated per worktree
- Schema migrations applied independently to each database

### Port Allocation

| Worktree | Backend | Frontend | Database Name |
|----------|---------|----------|---------------|
| main     | 6789    | 3000     | agent_observer |
| blue     | 6799    | 3010     | agent_observer_blue |
| red      | 6809    | 3020     | agent_observer_red |
| white    | 6819    | 3030     | agent_observer_white |

**Port Offset Formula:**
```bash
BACKEND_PORT = 6789 + (color_offset * 10)
FRONTEND_PORT = 3000 + (color_offset * 10)

# Offsets: blue=0, red=1, white=2
```

View port table anytime:
```bash
/worktree:wt_ports
```

### Configuring Directory Structure

**By default**, the worktree system assumes:
- Backend code is in `./app`
- Frontend code is in `./frontend`

**For projects with different structures**, configure in `.claude/.env`:

```bash
# Example: Different directory names
BACKEND_DIR=backend
FRONTEND_DIR=client

# Example: Monorepo structure
BACKEND_DIR=packages/api
FRONTEND_DIR=apps/web

# Example: Single directory
BACKEND_DIR=src
FRONTEND_DIR=ui
```

**Supported structures:**
- ✅ Standard: `app/` and `frontend/`
- ✅ Alternative names: `backend/`, `server/`, `api/`, `client/`, `web/`
- ✅ Monorepo: `packages/api/`, `apps/dashboard/`
- ✅ Nested: `src/backend/`, `src/frontend/`

**When to configure:**
- Porting worktree system to projects with non-standard layouts
- Working with existing projects that use different conventions
- Monorepo setups with nested structures

**How scripts use these values:**
- All worktree scripts automatically detect and use configured directories
- Environment files are generated in the correct locations
- Migrations run from the backend directory
- Services start from the correct directories
- No hardcoded paths anywhere in the system

See [README_ENV.md](../../README_ENV.md) for complete environment variable documentation.

## Migration Workflow

### When You Create a Migration

**Scenario**: You're in the blue worktree and need to add a new database table.

```bash
# 1. Create migration
cd ~/projects/agent_observer_blue
uv run app/makemigration.sh "add user preferences table"

# 2. Apply to your database
uv run app/migrate.sh  # Applies to agent_observer_blue

# 3. Test your changes
# ... develop and test ...

# 4. Commit migration file
git add app/alembic/versions/abc123_add_user_preferences_table.py
git commit -m "feat: add user preferences table"

# 5. Update .env.example if you added new variables
echo "PREFERENCES_CACHE_TTL=3600" >> app/.env.example
git add app/.env.example
git commit -m "docs: add PREFERENCES_CACHE_TTL to env example"

# 6. Push and create PR
git push origin feature/task-3a-1-1
gh pr create --title "Add user preferences table"
```

### When Someone Else's Migration is Merged

**Scenario**: Red agent merged a migration to main, and you need to update.

```bash
# Sync pulls code and runs migrations
/worktree:wt_sync blue --pull --migrate

# If new env vars required, you'll be prompted:
# ⚠️  Missing REQUIRED variables:
#   - PREFERENCES_CACHE_TTL
#
# Add now? [y/N]: y
# Enter PREFERENCES_CACHE_TTL: 3600

# Restart services to pick up changes
/worktree:wt_restart blue
```

### Handling Migration Conflicts

**If two agents create migrations simultaneously:**

```bash
# Problem: Both created migration with same sequence number
# app/alembic/versions/001_abc_add_users.py (blue)
# app/alembic/versions/001_def_add_posts.py (red)

# Solution: Rename one after merge
mv app/alembic/versions/001_def_add_posts.py \
   app/alembic/versions/002_def_add_posts.py

# Edit 002_def_add_posts.py:
# down_revision = '001_abc'  # Point to previous migration

# Commit the fix
git add app/alembic/versions/
git commit -m "fix: resolve migration sequence conflict"
```

**Best practice**: Coordinate schema changes to avoid conflicts.

## Troubleshooting

### Quick Diagnostics

**First, run the doctor command to identify issues automatically:**

```bash
/worktree:wt_doctor
```

This will check:
- ✅ Dependencies (git, yq, docker)
- ✅ Configuration validation
- ✅ Database status
- ✅ Port conflicts
- ✅ Project structure

**To validate your configuration:**

```bash
/worktree:wt_validate
```

**For auto-fix of common issues:**

```bash
./.claude/commands/worktree/scripts/doctor.sh --fix
```

---

### Port Already in Use

**Error**: "Port 6799 is already in use"

**Solution**:
```bash
# Check what's using the port
lsof -i :6799

# Check all worktrees
/worktree:wt_list

# Stop the conflicting worktree
/worktree:wt_stop blue

# Or kill the process
kill <PID>
```

### Database Connection Failed

**Error**: "Failed to connect to database agent_observer_blue"

**Checks**:
```bash
# 1. Is Supabase running?
docker ps | grep supabase-db

# 2. Does database exist?
/worktree:wt_status blue

# 3. Check credentials
/worktree:wt_env_validate blue

# 4. Recreate database if needed
/worktree:wt_db_reset blue
```

### Services Won't Start

**Error**: "FastAPI failed to start"

**Debug**:
```bash
# Check logs
/worktree:wt_logs blue fastapi

# Check health
/worktree:wt_health blue

# Common fixes:
/worktree:wt_env_validate blue   # Missing env vars
/worktree:wt_deps_install blue   # Outdated dependencies
/worktree:wt_db_migrate blue     # Database out of sync
/worktree:wt_restart blue        # Restart services
```

### Environment Variables Missing

**Error**: "BLOCKED: Missing required environment variables"

**Solution**:
```bash
# Validate
/worktree:wt_env_validate blue

# Regenerate if needed
/worktree:wt_env_generate blue

# Or use interactive sync
cd worktrees/agent_observer_blue
./.claude/commands/worktree/scripts/sync_worktree.sh --interactive
```

### Migration Failed

**Error**: "Migration failed with error..."

**Debug**:
```bash
# Check current migration version
cd worktrees/agent_observer_blue/app
alembic current

# Check pending migrations
alembic history

# Try migration again with verbose output
/worktree:wt_db_migrate blue --verbose

# If corrupted, reset database (CAUTION: destroys data)
/worktree:wt_db_reset blue
```

### View Detailed Status

```bash
# Single worktree
/worktree:wt_status blue --verbose

# All worktrees
/worktree:wt_list --verbose

# Health check
/worktree:wt_health blue --verbose
```

## Branch Workflow and Merge Strategy

### Understanding the Branch Structure

Each worktree uses a **two-tier branch system**:

1. **Persistent Color Branch** (`blue`, `red`, `white`)
   - Infrastructure branch that exists only so the worktree can exist
   - Mirrors `main` at all times
   - **NEVER merged to main** - it's not part of the development workflow
   - Stays synced with `main` via rebase

2. **Feature Branches** (`feature/*`, `fix/*`, etc.)
   - Actual work branches created from the color branch
   - Merged directly to `main` via PRs
   - Deleted after merge

### Complete Workflow

#### 1. Create Worktree (One-Time)

```bash
/worktree:wt_create blue
# Creates worktree with persistent 'blue' branch tracking main
```

Behind the scenes:
```bash
git worktree add worktrees/agent_observer_blue -b blue main
```

The `blue` branch now exists and mirrors `main`.

#### 2. Create Feature Branch

```bash
cd worktrees/agent_observer_blue
git checkout -b feature/add-endpoint
# Branch created from 'blue' (which mirrors main)
```

Or use the command:
```bash
/worktree:wt_branch blue feature/add-endpoint
```

#### 3. Work and Commit

```bash
# Make changes
git add .
git commit -m "Add new endpoint"
git push origin feature/add-endpoint
```

#### 4. Create PR and Merge **Directly to Main**

```bash
gh pr create --base main --title "Add new endpoint"
# PR: feature/add-endpoint → main (NOT blue!)
# ... Review, approve, merge ...
```

**CRITICAL**: The PR merges to `main`, **NOT** to the color branch (`blue`).

#### 5. Sync Color Branch After Merge

```bash
# After PR merged to main
cd worktrees/agent_observer_blue
git checkout blue
git pull origin main --rebase
# 'blue' now mirrors updated main
```

Or use the sync command:
```bash
/worktree:wt_sync blue --pull --migrate
```

#### 6. Start Next Feature

```bash
git checkout -b feature/next-task
# Branch from updated 'blue' (which now has previous merge)
```

### Visual Flow

```
main (protected branch)
  ↓ (create worktree)
blue (persistent, mirrors main)
  ↓ (create feature branch)
feature/add-endpoint ──PR──→ main ✓ merged
  ↓                            ↓
  deleted                      ↓ (rebase blue)
                              blue (synced)
                               ↓ (create next feature)
                         feature/next-task ──PR──→ main
```

### Key Rules

✅ **DO**: Merge feature branches to `main`
```bash
feature/add-endpoint → main (via PR)
```

✅ **DO**: Sync color branch with main after merges
```bash
git checkout blue && git pull origin main --rebase
```

❌ **DON'T**: Merge color branch to main
```bash
# NEVER do this:
blue → main  ❌ WRONG
```

❌ **DON'T**: Merge feature branch to color branch
```bash
# NEVER do this:
feature/add-endpoint → blue  ❌ WRONG
```

### Why This Structure?

**Problem**: Git doesn't allow the same branch to be checked out in multiple worktrees simultaneously. Since `main` is checked out in the root directory, worktrees can't check out `main`.

**Solution**: Each worktree gets a persistent color branch (`blue`, `red`, `white`) that:
- Exists solely for worktree infrastructure
- Stays synced with `main` via rebase
- Serves as base for feature branches
- Never participates in merges

This allows:
- Multiple parallel development environments
- All work eventually merges to `main`
- Clean git history without unnecessary merge commits
- Worktrees that can be reused indefinitely

## Best Practices

### DO

✅ **Create worktrees once** at project start, reuse for multiple tasks

✅ **Use `/worktree:wt_branch`** to create feature branches, not new worktrees

✅ **Sync daily** with `/worktree:wt_sync blue --pull --migrate`

✅ **Commit migration files immediately** after creating them

✅ **Update .env.example** when adding new environment variables

✅ **Communicate schema changes** with team before merging

✅ **Check status** with `/worktree:wt_list` regularly

✅ **Use descriptive branch names**: `feature/task-3a-1-1`, `fix/auth-bug`

✅ **Test migrations** on your worktree database before merging

### DON'T

❌ **Don't create new worktree per feature** (reuse existing worktrees)

❌ **Don't create feature branch during worktree creation** (worktree stays on main)

❌ **Don't modify main branch database** directly (use migrations)

❌ **Don't share databases** between worktrees (defeats isolation purpose)

❌ **Don't hard-code ports** in code (use environment variables)

❌ **Don't commit .env files** (they're gitignored for security)

❌ **Don't commit generated Docker files** (`docker/docker-compose.celery.yml`, `docker/Dockerfile.celery` - auto-ignored)

❌ **Don't run migrations on production** without testing on worktree first

❌ **Don't create conflicting migrations** (coordinate with team)

❌ **Don't leave uncommitted changes** when switching branches

## Cleanup

### When Project Phase Complete

```bash
# Delete worktree (interactive, safe)
/worktree:wt_delete blue

# Preview what will be deleted
./.claude/commands/worktree/scripts/delete_worktree.sh blue --dry-run

# Keep database for later
./.claude/commands/worktree/scripts/delete_worktree.sh blue --keep-database
```

**What gets deleted:**
- ✅ Git worktree directory
- ✅ Running services (stopped first)
- ✅ Git branches (local + remote)
- ✅ Database (unless --keep-database)
- ✅ Log files and PIDs

## Scripts Reference

All commands call scripts in `scripts/` directory. Direct script usage:

```bash
# Navigate to worktree directory
cd /Users/you/projects/agent_observer_blue

# Run scripts directly
./.claude/commands/worktree/scripts/status.sh blue
./.claude/commands/worktree/scripts/health_check.sh blue --verbose
./.claude/commands/worktree/scripts/view_logs.sh blue fastapi --lines 100
```

**Available scripts** (19 total):
- `create_branch.sh` - Create feature branch
- `delete_worktree.sh` - Remove worktree
- `detect_worktree.sh` - Detect current context
- `ensure_gitignore.sh` - Automatically add required .gitignore entries (idempotent)
- `generate_celery_compose.sh` - Generate worktree-specific Celery Docker files
- `generate_worktree_env.sh` - Generate .env files
- `health_check.sh` - Test connectivity
- `install_deps.sh` - Install dependencies
- `list_worktrees.sh` - Show all worktrees
- `migrate_database.sh` - Run migrations
- `reset_database.sh` - Reset database
- `restart_worktree.sh` - Restart services
- `setup_database.sh` - Create database
- `show_ports.sh` - Port allocation table
- `start_worktree.sh` - Start services
- `status.sh` - Single worktree status
- `stop_worktree.sh` - Stop services
- `sync_worktree.sh` - Sync with main
- `validate_config.sh` - Validate worktree configuration
- `validate_env.sh` - Validate .env
- `view_logs.sh` - Display logs

## Related Documentation

### Application Documentation
- [README_ENV.md](../../README_ENV.md) - Environment variable management
- [app/CLAUDE.md](../../../app/CLAUDE.md) - Application architecture
- [app/alembic/CLAUDE.md](../../../app/alembic/CLAUDE.md) - Migration details

### Worktree Commands
All commands documented in individual `.md` files in this directory:
- `wt_create.md`, `wt_branch.md`, `wt_list.md`, etc.

## Summary: Old vs New Workflow

### Old Workflow ❌

```bash
# Create new worktree for each feature
/create_worktree blue feature/task-1  # 5 min setup
# ... work, merge ...

/create_worktree blue feature/task-2  # 5 min setup AGAIN
# ... work, merge ...
```

**Problems:**
- Recreate database every time
- Reinstall dependencies every time
- ~5 min overhead per feature
- Worktree tied to single branch

### New Workflow ✅

```bash
# One-time setup
/worktree:wt_create blue              # 5 min (once!)

# Per feature (instant)
/worktree:wt_branch blue feature/task-1  # 2 sec
# ... work, merge ...

/worktree:wt_branch blue feature/task-2  # 2 sec
# ... work, merge ...
```

**Benefits:**
- Database persists across features
- Dependencies persist across features
- ~2 sec overhead per feature
- Worktree reused for multiple branches
- Efficient parallel development

---

**Questions?** Check individual command documentation or run:
```bash
/worktree:wt_list      # See all worktrees
/worktree:wt_ports     # See port allocation
/worktree:wt_status blue --verbose  # Detailed diagnostics
```
