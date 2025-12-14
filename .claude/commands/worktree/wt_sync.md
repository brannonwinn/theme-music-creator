# Sync Worktree with Main

Synchronize worktree with main branch, validate environment, run migrations, and sync test data.

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

### Basic Sync (validation only)

```bash
./.claude/commands/worktree/scripts/sync_worktree.sh
```

### Pull from main + validate

```bash
./.claude/commands/worktree/scripts/sync_worktree.sh --pull
```

### Pull + validate + migrate

```bash
./.claude/commands/worktree/scripts/sync_worktree.sh --pull --migrate
```

### Full sync with codegen

```bash
./.claude/commands/worktree/scripts/sync_worktree.sh --pull --migrate --codegen
```

### Full sync with test data

```bash
./.claude/commands/worktree/scripts/sync_worktree.sh --pull --migrate --data
```

### Complete sync (everything)

```bash
./.claude/commands/worktree/scripts/sync_worktree.sh --pull --migrate --codegen --data
```

## What It Does

1. **--pull**: Pulls latest changes from main into current branch (with auto-stash and rebase)
2. **Validation**: Checks all required environment variables exist
3. **--migrate**: Runs Alembic migrations to update database schema
4. **--codegen**: Regenerates frontend TypeScript types from backend OpenAPI spec
5. **--data**: Syncs test data (profiles, organizations, properties, role_assignments) from main Supabase database to worktree database

## When To Use

### Use Case 1: Sync Color Branch After PR Merge
After your feature branch is merged to main, sync the color branch:
```bash
cd worktrees/agent_observer_blue
git checkout blue
/worktree:wt_sync blue --pull --migrate
```
This keeps the color branch (blue/red/white) in sync with main.

### Use Case 2: Update Feature Branch with Latest Main
If main has changed while you're working on a feature branch:
```bash
cd worktrees/agent_observer_blue
git checkout feature/your-branch
/worktree:wt_sync blue --pull --migrate
```
This rebases your feature branch onto the latest main.

### Use Case 3: Validate Environment
Check that all required environment variables are set:
```bash
/worktree:wt_sync blue
```
(No --pull flag = validation only)

### Use Case 4: Regenerate Frontend Types After Backend Schema Changes
When backend Pydantic models change, regenerate TypeScript types:
```bash
/worktree:wt_sync blue --codegen
```
This fetches the OpenAPI spec from the worktree's backend port and regenerates types.

### Use Case 5: Sync Test Data to Worktree Database
After setting up a new worktree or when test data in main database changes:
```bash
/worktree:wt_sync blue --data
```
This copies profiles, organizations, properties, and role_assignments from the main Supabase database (`postgres`) to the worktree's database (`host_hero_blue`).

**Note:** The `--data` flag requires the backend to be running. It's idempotent - safe to run multiple times.

### Use Case 6: Complete Worktree Setup
For a fresh worktree or after major updates, run everything:
```bash
/worktree:wt_sync blue --pull --migrate --data
```
This pulls code, runs migrations, and syncs test data.

## Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Pulling from main branch
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Current branch: feature/task-3a-1-1
✅ Successfully pulled from main

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Checking .claude/.env
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ All variables present in .claude/.env

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Checking app/.env
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ All variables present in app/.env

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Running Database Migrations
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Migrations completed successfully

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Regenerating Frontend TypeScript Types
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Detected worktree: blue
Backend port: 6799

Checking if backend is running at: http://localhost:6799/openapi.json
✅ Backend is running
Running: openapi --input http://localhost:6799/openapi.json --output ./src/types/api.ts --useOptions
✅ TypeScript types regenerated successfully

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Syncing Test Data to Worktree Database
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Detected worktree: blue
Target database: host_hero_blue
Backend port: 6799

Checking if backend is running...
✅ Backend is running
Syncing test data from main database to host_hero_blue...
✅ Data sync complete: 37 records synced

Sync details:
  - profiles: 18/18
  - organizations: 8/8
  - properties: 3/3
  - role_assignments: 8/8

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Sync Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Worktree environment synchronized
```

## Recommended Workflow

Before creating new feature branch:

```bash
/worktree_sync blue --pull --migrate
/worktree_branch blue feature/new-task
```
