# Restart Worktree Services

Stop and restart all services (FastAPI, Celery, Next.js) for a worktree.

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

Then run:

```bash
./.claude/commands/worktree/scripts/restart_worktree.sh ${COLOR}
```

## What It Does

1. Stops all running services
2. Waits briefly for cleanup
3. Starts all services again

## When To Use

- After configuration changes
- After code changes that require restart
- When services are unresponsive
- After database migrations

## Output

```
Stopping services...
✅ All services stopped

Starting services...
✅ FastAPI started (PID: 54321, port: 6799)
✅ Celery started (PID: 54322)
✅ Next.js started (PID: 54323, port: 3010)

All services restarted for ${PROJECT_NAME}_blue
```

## Verbose Mode

For detailed output:

```bash
./.claude/commands/worktree/scripts/restart_worktree.sh ${COLOR} --verbose
```
