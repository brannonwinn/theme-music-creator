# Validate Worktree Environment

Check that all required environment variables are present in `.env` files.

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

Then run:

```bash
./.claude/commands/worktree/scripts/validate_env.sh ${COLOR}
```

For verbose output showing each variable checked:

```bash
./.claude/commands/worktree/scripts/validate_env.sh ${COLOR} --verbose
```

## What It Checks

**`worktree.config.yaml` required configuration:**
- project.name (PROJECT_NAME)
- infrastructure.observability_api_url (OBSERVABILITY_API_URL)
- infrastructure.redis_url (REDIS_URL)

**`app/.env` required variables:**
- DATABASE_HOST
- DATABASE_PORT
- DATABASE_NAME
- DATABASE_USER
- DATABASE_PASSWORD

**Note:** Configuration has migrated from `.claude/.env` to `worktree.config.yaml` for better portability and single source of truth.

## When To Use

- After generating environment files
- Troubleshooting configuration issues
- Before starting services
- As part of sync workflow

## Output (Success)

```
✅ All required environment variables present
```

## Output (Failure)

```
❌ Missing DATABASE_NAME in app/.env
❌ Missing OBSERVABILITY_API_URL in .claude/.env

Environment validation failed

Fix with:
  /worktree_env_generate blue
```

## Related Commands

- `/worktree_env_generate ${COLOR}` - Generate missing `.env` files
- `/worktree_sync ${COLOR}` - Includes validation as part of sync
