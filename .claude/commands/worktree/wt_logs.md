# View Worktree Logs

Display logs for worktree services (FastAPI, Celery, Next.js).

## Usage

Ask the user for:
1. **Agent color** (blue, red, white, or main)
2. **Service** (optional: fastapi, celery, nextjs)

### View all logs

```bash
./.claude/commands/worktree/scripts/view_logs.sh ${COLOR}
```

### View specific service

```bash
./.claude/commands/worktree/scripts/view_logs.sh ${COLOR} fastapi
```

### Custom line count

```bash
./.claude/commands/worktree/scripts/view_logs.sh ${COLOR} fastapi --lines 100
```

## Services

- **fastapi**: Backend API logs
- **celery**: Background worker logs
- **nextjs**: Frontend build and runtime logs

## Output Example

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FastAPI Logs (last 50 lines)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2025-01-14 10:30:15 | INFO | Starting FastAPI server...
2025-01-14 10:30:16 | INFO | Connected to database
2025-01-14 10:30:17 | INFO | Server started on port 6799
...
```

## Follow Logs (Live)

To follow logs in real-time:

```bash
tail -f ../${PROJECT_NAME}_${COLOR}/logs/fastapi_${COLOR}.log
```

## When To Use

- Debugging errors
- Monitoring service activity
- Investigating performance issues
- Checking startup messages
