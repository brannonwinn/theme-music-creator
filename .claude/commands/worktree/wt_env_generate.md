# Generate Worktree Environment Files

Generate or regenerate `.env` files with color-specific configuration.

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

Navigate to the worktree directory first, then run:

```bash
cd worktrees/${PROJECT_NAME}_${COLOR}
./.claude/commands/worktree/scripts/generate_worktree_env.sh ${COLOR} $(pwd)
```

## What It Does

1. Copies `.env.template` and `.env.example` as base
2. Sets `DATABASE_NAME=${PROJECT_NAME}_${COLOR}`
3. Sets `AGENT_COLOR=${COLOR}`
4. Calculates and sets unique ports (BACKEND_PORT, FRONTEND_PORT)
5. Preserves all API keys and secrets from main

## Port Calculation

- **blue**: Backend 6799, Frontend 3010
- **red**: Backend 6809, Frontend 3020
- **white**: Backend 6819, Frontend 3030

## When To Use

- After worktree creation
- Environment files corrupted or deleted
- New environment variables added to templates
- Changing port configuration

## Output

```
✅ Generated .claude/.env
✅ Generated app/.env
✅ Environment files configured for blue worktree
```

## Validation

After generating, validate with:

```bash
/worktree_env_validate ${COLOR}
```
