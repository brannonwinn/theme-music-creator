# Environment Variable Management

This document explains how environment variables are managed across the project and worktrees, including validation, synchronization, and troubleshooting.

## Overview

This project uses **multiple .env files** for different purposes:

| File Location | Purpose | Validation |
|--------------|---------|------------|
| `.claude/.env` | Claude Code hook configuration | ✅ Required vars checked by pre_tool_use hook |
| `app/.env` | Application runtime configuration | ✅ Required vars checked by pre_tool_use hook |
| `docker/.env` | Docker infrastructure configuration | ❌ No automatic validation |
| `client/.env` | Frontend-specific configuration | ❌ No automatic validation |

## Required vs Optional Variables

### `.claude/.env` - REQUIRED

These variables are **validated before every tool execution**. Operations will be BLOCKED if missing:

- `PROJECT_NAME` - Project identifier (must match across worktrees)
- `OBSERVABILITY_API_URL` - Centralized observability server endpoint
- `REDIS_URL` - Shared Redis cache connection string

### `.claude/.env` - OPTIONAL (Auto-detected)

- `WORKTREE_NAME` - Auto-detected from path (e.g., `agent_observer_blue` → `blue`)
- `AGENT_COLOR` - Auto-detected from worktree name
- `AGENT_NAME` - Friendly agent name
- `GIT_REPO_NAME` - Auto-detected from git remote
- `FRONTEND_DEV_URL` - Only needed during frontend development

### `.claude/.env` - OPTIONAL (Project Structure)

- `BACKEND_DIR` - Backend directory relative to project root (default: `app`)
  - Use when your project uses a different backend directory name
  - Examples: `backend`, `server`, `api`, `src`, `packages/api`
- `FRONTEND_DIR` - Frontend directory relative to project root (default: `frontend`)
  - Use when your project uses a different frontend directory name
  - Examples: `client`, `web`, `ui`, `dashboard`, `apps/web`

**When to set these:**
- When porting worktree system to projects with non-standard directory structures
- For monorepo setups with nested directories
- When the backend is not in `./app` or frontend is not in `./frontend`

**Examples:**

```bash
# Standard Next.js project structure
BACKEND_DIR=backend
FRONTEND_DIR=client

# Monorepo with packages
BACKEND_DIR=packages/api
FRONTEND_DIR=apps/dashboard

# Different naming convention
BACKEND_DIR=server
FRONTEND_DIR=web
```

### `app/.env` - REQUIRED

These variables are **validated before every tool execution**. Operations will be BLOCKED if missing:

- `DATABASE_HOST` - Database server hostname
- `DATABASE_PORT` - Database server port
- `DATABASE_NAME` - Database name (changes per worktree)
- `DATABASE_USER` - Database username
- `DATABASE_PASSWORD` - Database password

### `app/.env` - OPTIONAL

- `OPENAI_API_KEY` - Only if using OpenAI providers
- `ANTHROPIC_API_KEY` - Only if using Anthropic providers
- `AZURE_OPENAI_ENDPOINT` - Only if using Azure OpenAI
- All other LLM provider keys - Only if used in workflows

## Validation System

### How Validation Works

1. **Pre-hook validation**: Every tool call triggers `.claude/hooks/pre_tool_use.py`
2. **Environment loading**: Hook loads both `.claude/.env` and `app/.env`
3. **Required check**: Verifies all required variables are present and non-empty
4. **Blocking**: If validation fails, tool execution is BLOCKED with clear error message

### Error Example

```bash
BLOCKED: Missing required .claude environment variables:
  - REDIS_URL

Fix by running:
  ./.claude/commands/worktree/scripts/sync_worktree.sh --interactive
```

### Fixing Validation Errors

Run the sync script with interactive mode:

```bash
./.claude/commands/worktree/scripts/sync_worktree.sh --interactive
```

The script will:
1. Detect missing variables
2. Prompt you for values
3. Update your .env files
4. Validate the configuration

## Synchronization Workflow

### Daily Team Workflow

**Morning routine (sync your worktree):**
```bash
cd ~/projects/agent_observer_blue
./.claude/commands/worktree/scripts/sync_worktree.sh --pull --migrate
```

This will:
- Pull latest code from main
- Check for missing environment variables
- Run database migrations
- Prompt for any new required variables

### Adding New Environment Variables

**When you add a new variable that other team members need:**

1. **Add to your `.env` file:**
   ```bash
   echo "NEW_FEATURE_API_KEY=sk-abc123..." >> app/.env
   ```

2. **Update the `.env.example` file (CRITICAL):**
   ```bash
   echo "NEW_FEATURE_API_KEY=" >> app/.env.example
   echo "# OPTIONAL - Required for feature X" >> app/.env.example
   ```

3. **Commit the .env.example:**
   ```bash
   git add app/.env.example
   git commit -m "feat: add NEW_FEATURE_API_KEY for feature X"
   ```

4. **Document in PR description:**
   ```markdown
   ## New Environment Variables

   This PR introduces `NEW_FEATURE_API_KEY`:
   - Purpose: Authenticates with Feature X API
   - How to get: Available in 1Password vault under "Feature X"
   - Required for: Feature X workflows
   ```

5. **After merge, team members sync:**
   ```bash
   ./.claude/commands/worktree/scripts/sync_worktree.sh --pull --interactive
   ```

   The script will detect the missing variable and prompt for it.

## Worktree-Specific Configuration

### Database Isolation

Each worktree uses a **separate database** for isolated development:

```bash
# Main worktree
DATABASE_NAME=agent_observer

# Blue worktree
DATABASE_NAME=agent_observer_blue

# Red worktree
DATABASE_NAME=agent_observer_red
```

This is automatically configured when creating worktrees (see README_WORKTREE.md).

### Port Offsets

Each worktree uses **unique ports** to avoid conflicts:

| Worktree | Backend Port | Frontend Port | Database |
|----------|--------------|---------------|----------|
| main | 6789 | 3000 | agent_observer |
| blue | 6799 | 3010 | agent_observer_blue |
| red | 6809 | 3020 | agent_observer_red |
| white | 6819 | 3030 | agent_observer_white |

These are calculated automatically based on agent color.

## Troubleshooting

### "BLOCKED: Missing required environment variables"

**Cause**: Required variables are missing from .env files

**Fix**:
```bash
./.claude/commands/worktree/scripts/sync_worktree.sh --interactive
```

### "Missing variables detected" after git pull

**Cause**: Someone added new required variables to .env.example

**Fix**:
```bash
./.claude/commands/worktree/scripts/sync_worktree.sh --interactive
```

The script will prompt you for the new variables.

### Variables not being detected

**Cause**: .env file might have syntax errors or extra spaces

**Fix**:
1. Check .env file format (no spaces around `=`)
   ```bash
   # CORRECT
   PROJECT_NAME=agent_observer

   # INCORRECT
   PROJECT_NAME = agent_observer  # spaces around =
   PROJECT_NAME=                   # empty value
   ```

2. Validate manually:
   ```bash
   cat .claude/.env
   cat app/.env
   ```

### Pre-hook validation not running

**Cause**: Hook might not be executable or has syntax errors

**Fix**:
```bash
# Make hook executable
chmod +x .claude/hooks/pre_tool_use.py

# Test hook manually
echo '{"tool_name": "Bash", "tool_input": {"command": "ls"}, "session_id": "test"}' | \
  .claude/hooks/pre_tool_use.py
```

Should exit with code 0 if validation passes, code 2 if blocked.

## Scripts Reference

### sync_worktree.sh

**Purpose**: Synchronize environment variables and database schema

**Usage**:
```bash
# Just validate .env files
./.claude/commands/worktree/scripts/sync_worktree.sh

# Pull from main and validate
./.claude/commands/worktree/scripts/sync_worktree.sh --pull

# Full sync: pull + validate + migrate
./.claude/commands/worktree/scripts/sync_worktree.sh --pull --migrate

# Interactive mode: prompt for missing vars
./.claude/commands/worktree/scripts/sync_worktree.sh --interactive
```

**What it does**:
1. Compares `.env.example` with `.env` to find missing variables
2. Categorizes variables as REQUIRED or OPTIONAL
3. Optionally pulls latest code from main
4. Optionally runs database migrations
5. Provides helpful error messages with remediation steps

## Best Practices

### DO

- ✅ Always update `.env.example` when adding new variables
- ✅ Document new variables in PR descriptions
- ✅ Run `sync_worktree.sh` after pulling main
- ✅ Use meaningful variable names with clear purpose
- ✅ Add comments in `.env.example` explaining each variable
- ✅ Store secrets in 1Password or secure vault, not in git

### DON'T

- ❌ Commit `.env` files to git (they're gitignored)
- ❌ Hardcode secrets in code
- ❌ Skip updating `.env.example` when adding variables
- ❌ Use spaces around `=` in .env files
- ❌ Leave required variables empty

## Security Notes

### What's Gitignored

These files contain secrets and are **never committed**:
- `.claude/.env`
- `app/.env`
- `docker/.env`
- `client/.env`

### What's Committed

These files are **templates** and are committed:
- `.claude/.env.template`
- `app/.env.example`
- `docker/.env.example`
- `client/.env.sample`

### Sharing Secrets

**For team development**:
1. Use 1Password shared vaults
2. Document in team wiki where to get secrets
3. Include instructions in README

**For production**:
1. Use environment variables from deployment platform
2. Never store production secrets in development .env files
3. Use different API keys for dev vs prod

## Related Documentation

- [README_WORKTREE.md](./README_WORKTREE.md) - Worktree setup and management
- [app/.env.example](/app/.env.example) - Application environment template
- [.claude/.env.template](./.env.template) - Claude Code hooks template
