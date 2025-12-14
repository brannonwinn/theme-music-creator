# Reset Worktree Database

Drop and recreate database with fresh migrations. ⚠️ **Destructive operation** - all data will be lost.

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

⚠️ **Warning**: Confirm with user before proceeding as this deletes all data.

Then run:

```bash
./.claude/commands/worktree/scripts/reset_database.sh ${COLOR}
```

## What It Does

1. Prompts for confirmation
2. Terminates all connections to database
3. Drops database
4. Creates fresh database
5. Runs all migrations from scratch

## Interactive Prompt

```
⚠️  This will DELETE all data in database: ${PROJECT_NAME}_blue

Are you sure? Type 'yes' to confirm: yes
```

## Force Reset (Skip Confirmation)

```bash
./.claude/commands/worktree/scripts/reset_database.sh ${COLOR} --yes
```

## When To Use

- Database corrupted or in bad state
- Want clean slate for testing
- Migration issues requiring full reset
- Schema completely out of sync

## Output

```
✅ Database '${PROJECT_NAME}_blue' reset successfully
```

## Important Notes

- All data in the database will be permanently deleted
- Services should be restarted after reset: `/worktree_restart ${COLOR}`
- Cannot be undone
