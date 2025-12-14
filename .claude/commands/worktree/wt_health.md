# Health Check Worktree

Test service connectivity for backend, frontend, and database.

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

Then run:

```bash
./.claude/commands/worktree/scripts/health_check.sh ${COLOR}
```

For verbose diagnostic output:

```bash
./.claude/commands/worktree/scripts/health_check.sh ${COLOR} --verbose
```

## What It Tests

1. **Backend**: HTTP GET to `http://localhost:${PORT}/health`
2. **Frontend**: HTTP GET to `http://localhost:${PORT}`
3. **Database**: PostgreSQL connection test

## When To Use

- After starting services
- Troubleshooting service issues
- Before running tests
- Verify setup after changes

## Output (Success)

```
✅ Backend healthy (port 6799)
✅ Frontend healthy (port 3010)
✅ Database connection successful (${PROJECT_NAME}_blue)

✅ All services healthy
```

## Output (Failure)

```
❌ Backend not responding (port 6799)
✅ Frontend healthy (port 3010)
❌ Database connection failed (${PROJECT_NAME}_blue)

❌ Health check failed

Troubleshoot with:
  /worktree_logs blue fastapi
  /worktree_start blue
```

## Troubleshooting

If health check fails:

1. Check logs: `/worktree_logs ${COLOR}`
2. Verify services running: `/worktree_status ${COLOR}`
3. Restart services: `/worktree_restart ${COLOR}`
4. Check database: `/worktree_db_migrate ${COLOR}`
