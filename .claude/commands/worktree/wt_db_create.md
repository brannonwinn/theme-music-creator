# Create Worktree Database

Create and initialize database for a worktree (without creating the full worktree).

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

Then run:

```bash
./.claude/commands/worktree/scripts/setup_database.sh ${COLOR}
```

## What It Does

1. Creates `${PROJECT_NAME}_${COLOR}` database
2. Grants permissions to database user
3. Runs all Alembic migrations
4. Verifies connectivity

## When To Use

- Manually setting up database component
- Database was deleted but worktree still exists
- Troubleshooting database issues
- Advanced setup scenarios

## Output

```
✅ Database '${PROJECT_NAME}_blue' created
✅ Permissions granted
✅ Migrations completed
✅ Database ready
```

## Note

For normal worktree creation, use `/worktree_create` instead which handles database creation automatically.
