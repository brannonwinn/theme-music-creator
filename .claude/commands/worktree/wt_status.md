# Show Worktree Status

Display detailed status for a single worktree including services, database, git, and PIDs.

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

Then run:

```bash
./.claude/commands/worktree/scripts/status.sh ${COLOR}
```

For verbose output with PIDs:

```bash
./.claude/commands/worktree/scripts/status.sh ${COLOR} --verbose
```

## Output Example

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🔵 BLUE Worktree Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Path: /Users/user/${PROJECT_NAME}_blue
Branch: feature/task-3a-1-1

Services:
  ✅ FastAPI (port 6799)
  ✅ Celery
  ✅ Next.js (port 3010)

Database:
  ✅ ${PROJECT_NAME}_blue

Git Status:
  ↑ 3 commits ahead of main
  ⚠️  2 uncommitted changes

Quick commands:
  Logs:    /worktree_logs blue
  Health:  /worktree_health blue
  Restart: /worktree_restart blue
```

## Information Displayed

- Worktree path and current branch
- Service status with ports
- Database connection status
- Git status (commits ahead/behind, uncommitted changes)
- Quick command suggestions

## Verbose Mode

Shows additional details:
- Process IDs (PIDs) for each service
- Log file sizes
- Last restart time

## Related Commands

- `/worktree_list` - Status of all worktrees
- `/worktree_health ${COLOR}` - Test service connectivity
