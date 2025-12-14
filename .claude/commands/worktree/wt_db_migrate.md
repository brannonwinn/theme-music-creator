# Run Database Migrations

Run Alembic migrations for a worktree database.

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

Then run:

```bash
./.claude/commands/worktree/scripts/migrate_database.sh ${COLOR}
```

For verbose output:

```bash
./.claude/commands/worktree/scripts/migrate_database.sh ${COLOR} --verbose
```

## What It Does

Runs `alembic upgrade head` to apply all pending migrations to the worktree database.

## When To Use

- After pulling new migrations from main
- After creating new migration locally
- Database schema out of sync
- Part of sync workflow

## Output

```
✅ Migrations completed for ${PROJECT_NAME}_blue
```

## Related Commands

- `/worktree_sync ${COLOR} --pull --migrate` - Full sync with migrations
- `/worktree_db_reset ${COLOR}` - Reset database and re-run migrations
