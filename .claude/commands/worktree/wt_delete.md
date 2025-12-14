# Delete Worktree

Remove a worktree and optionally its database. Use when completely done with a worktree.

## Usage

Ask the user for the **agent color** (blue, red, or white).

⚠️ **Warning**: This is destructive. Confirm with user before proceeding.

Then run:

```bash
./.claude/commands/worktree/scripts/delete_worktree.sh ${COLOR} --force
```

This uses --force to skip interactive prompts and automatically deletes both the worktree and database.

## What It Does

1. Stops all running services
2. Prompts for confirmation
3. Asks if database should be deleted too
4. Removes worktree directory
5. Optionally drops database

## Interactive Prompts

The script will ask:

```
⚠️  This will DELETE the worktree: ${PROJECT_NAME}_blue
    Path: /Users/user/${PROJECT_NAME}_blue

Are you sure? Type 'yes' to confirm: yes

Delete database '${PROJECT_NAME}_blue' too? [y/N]: y
```

## Options

Available flags:

- `--force`: Skip all interactive prompts and proceed with deletion
- `--keep-database`: Don't drop the database (worktree and branch still deleted)
- `--keep-branch`: Don't delete the git branch (worktree still deleted)
- `--dry-run`: Show what would be deleted without actually deleting

Examples:

```bash
# Force delete everything (worktree + database + branch)
./.claude/commands/worktree/scripts/delete_worktree.sh ${COLOR} --force

# Keep database but delete worktree
./.claude/commands/worktree/scripts/delete_worktree.sh ${COLOR} --force --keep-database
```

## When To Use

- Project phase complete, no longer need parallel environments
- Worktree corrupted and needs fresh start
- Switching to different worktree strategy
- Cleaning up after experimentation

## Important Notes

- Cannot delete `main` worktree
- All uncommitted changes will be lost
- Database deletion is optional but recommended for full cleanup
- Can recreate worktree later with `/worktree_create`
