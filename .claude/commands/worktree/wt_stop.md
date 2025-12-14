# Stop Worktree Services

Stop all running services (FastAPI, Celery, Next.js) for a worktree.

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

Then run:

```bash
./.claude/commands/worktree/scripts/stop_worktree.sh ${COLOR}
```

## What It Does

- Stops FastAPI backend
- Stops Celery worker
- Stops Next.js frontend
- Removes PID files
- Verifies services stopped

## Output

```
✅ FastAPI stopped
✅ Celery stopped
✅ Next.js stopped

All services stopped for ${PROJECT_NAME}_blue
```

## Verbose Mode

For detailed output:

```bash
./.claude/commands/worktree/scripts/stop_worktree.sh ${COLOR} --verbose
```
