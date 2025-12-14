# Start Worktree Services

Start all services (FastAPI, Celery, Next.js) for a worktree.

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

Then run:

```bash
./.claude/commands/worktree/scripts/start_worktree.sh ${COLOR}
```

## What It Does

- Starts FastAPI backend
- Starts Celery worker
- Starts Next.js frontend (if client directory exists)
- Saves PIDs to log files
- Verifies services started successfully

## Output

```
✅ FastAPI started (PID: 12345, port: 6799)
✅ Celery started (PID: 12346)
✅ Next.js started (PID: 12347, port: 3010)

All services running for ${PROJECT_NAME}_blue

Service URLs:
  Backend:  http://localhost:6799
  Frontend: http://localhost:3010

Logs:
  tail -f logs/fastapi_blue.log
  tail -f logs/celery_blue.log
  tail -f logs/nextjs_blue.log
```

## Verbose Mode

For detailed startup logs:

```bash
./.claude/commands/worktree/scripts/start_worktree.sh ${COLOR} --verbose
```
