# Create Worktree

Create a new git worktree with complete isolated environment setup. This is a **one-time setup** per worktree color. The worktree stays on the `main` branch - use `/worktree:wt-branch` to create feature branches later.

## What It Does

1. Creates worktree directory with persistent color branch
2. Generates color-specific `.env` files with correct database credentials from main project
3. Installs Python and Node dependencies
4. Sets up isolated database and runs migrations
5. Generates Docker Compose file for worktree-specific Celery worker
6. Auto-kills any stale processes and starts all services (FastAPI, Docker Celery, Next.js)
7. Verifies setup with health checks using `/health` endpoint and Docker database verification

## Usage

Ask the user for the **agent name** (any agent defined in `worktree.config.yaml`).

Default agents are: `blue`, `red`, `white` (but you can add more in the config file).

Then run the following workflow:

### Step 0: Read Configuration

**IMPORTANT**: Read the configuration file first to get PROJECT_NAME, agent ports, database names, and other settings.

```bash
# Read the configuration to understand project structure
cat .claude/commands/worktree/worktree.config.yaml
```

All variables used in subsequent steps (${PROJECT_NAME}, ${BACKEND_PORT}, ${FRONTEND_PORT}, database names) come from this configuration file. The config defines:
- `project.name`: Used as PROJECT_NAME in paths and database names
- `agents[].backend_port`: Backend port for this agent
- `agents[].frontend_port`: Frontend port for this agent
- `agents[].database_name`: Database name for this agent
- `project.backend_project_dir`: Backend project root (where `pyproject.toml` is) - used for dependency installation
- `project.backend_app_dir`: Backend app directory (where `main.py` is) - used for starting services
- `project.frontend_dir`: Frontend directory path

**Note**: The backend has two directories:
  - `backend_project_dir` (e.g., `backend`): Where Python dependencies are managed (`pyproject.toml`, `requirements.txt`)
  - `backend_app_dir` (e.g., `backend/app`): Where the FastAPI app lives (`main.py`)

  This separation ensures that dependency installation (`uv sync`) runs from the correct location.

### Step 1: Pre-flight Checks

Check current state before proceeding:

```bash
# Verify we're in project root
pwd

# Ensure required .gitignore entries exist (idempotent, safe to run multiple times)
./.claude/commands/worktree/scripts/ensure_gitignore.sh

# Check git status
git status

# Check if color already exists
ls -la ./worktrees/${PROJECT_NAME}_${COLOR} 2>/dev/null || echo "Color available"
```

**Important**: The `ensure_gitignore.sh` script automatically adds required entries to `.gitignore` if missing:
- `worktrees/` - Prevents tracking worktree directories
- `docker/docker-compose.celery.yml` - Prevents tracking generated Celery compose files
- `docker/Dockerfile.celery` - Prevents tracking generated Celery Dockerfiles

This step is idempotent and safe to run multiple times. It only adds missing entries.

If git status is dirty, offer to stash changes.

If worktree already exists, inform user and exit (or offer to delete first).

### Step 2: Create Worktree with Persistent Color Branch

**Run from main project root:**

```bash
mkdir -p worktrees
git worktree add worktrees/${PROJECT_NAME}_${COLOR} -b ${COLOR} main
```

**IMPORTANT**: This creates a persistent `${COLOR}` branch (e.g., `blue`, `red`, `white`) that:
- Exists solely for worktree infrastructure
- Mirrors `main` at all times
- Is NEVER merged to main
- Serves as the base for feature branches

Feature branches are created later with `/worktree:wt_branch`.


### Step 3: Generate Environment Files

**IMPORTANT: Run from main project root** (`.env` files are gitignored and don't exist in fresh worktrees):

```bash
./.claude/commands/worktree/scripts/generate_worktree_env.sh ${COLOR} ./worktrees/${PROJECT_NAME}_${COLOR}
```

This script handles all environment file setup:
1. **Copies `.claude/.env` from main project** (prevents pre_tool_use hook blocking)
2. **Updates `.claude/.env`** with color-specific values (AGENT_COLOR, AGENT_NAME, WORKTREE_NAME)
3. **Reads database credentials from main project's `app/.env`** (DATABASE_HOST, DATABASE_PORT, DATABASE_USER, DATABASE_PASSWORD)
4. **Reads Supabase auth variables from `docker/.env`** if `database.provider` is `supabase` in `worktree.config.yaml` (ANON_KEY, INTERNAL_KONG_URL, SUPABASE_PUBLIC_URL)
5. **Generates `app/.env`** with correct credentials, DATABASE_NAME from `worktree_config.json`, and Supabase auth variables if applicable
6. **Copies `docker/.env`** and `client/.env`** from main project (shared infrastructure)
7. **Copies root `.env`** from main project (TTS config, API keys, Redis URL)

**Note**: All port assignments and database names are defined in `.claude/commands/worktree/worktree_config.json` as the single source of truth.

### Step 3.5: Generate MCP Configuration

**Run from main project root:**

```bash
./.claude/commands/worktree/scripts/generate_mcp_json.sh ${COLOR} ./worktrees/${PROJECT_NAME}_${COLOR}
```

This generates a worktree-specific `.mcp.json` file with:
- Chrome DevTools MCP configured with the agent's unique debug port from `worktree.config.yaml`
- All other MCP servers (context7, firecrawl, shadcn, ElevenLabs, ide)

**Why this matters**: Each worktree needs its own Chrome browser instance with a unique debug port. This prevents multiple Claude agents from accidentally connecting to the same browser and mixing up their UI testing sessions.

**Port assignments** (from `worktree.config.yaml`):
| Agent | Chrome Debug Port |
|-------|------------------|
| blue  | 9222             |
| red   | 9223             |
| white | 9224             |
| green | 9225             |

### Step 3.75: Change to Worktree Directory

**After generating environment and MCP files, change to the worktree for all subsequent steps:**

```bash
cd worktrees/${PROJECT_NAME}_${COLOR}
```

**CRITICAL: Steps 1-3 run from main project root. Steps 4-7 MUST be run from the worktree root directory using relative paths.**

The worktree is a complete copy of the project, so all scripts exist at the same relative paths (e.g., `./.claude/commands/worktree/scripts/`). This ensures:
- Consistent relative path usage
- Clear mental model (working in the worktree context)
- Scripts can still reference main project when needed (via `git worktree list`)

### Step 4: Install Dependencies

**Run from worktree root:**

```bash
./.claude/commands/worktree/scripts/install_deps.sh ${COLOR}
```

This installs Python (uv sync) and Node (npm install) dependencies. **Must run before database setup** because migrations require Python packages.

### Step 5: Setup Database

**Run from worktree root:**

```bash
./.claude/commands/worktree/scripts/setup_database.sh ${COLOR}
```

This creates the `${PROJECT_NAME}_${COLOR}` database and runs migrations using the installed dependencies.

### Step 5.5: Generate Celery Worker Docker Compose

**Run from worktree root:**

```bash
./.claude/commands/worktree/scripts/generate_celery_compose.sh ${COLOR}
```

This generates worktree-specific Docker configuration files for the Celery worker:
- **Creates**: `docker/docker-compose.celery.yml` and `docker/Dockerfile.celery` from templates
- **Configures**: Database connection to `${PROJECT_NAME}_${COLOR}` database
- **Sets queue**: `${PROJECT_NAME}_${COLOR}_tasks` for task isolation
- **Container name**: `${PROJECT_NAME}_celery_${COLOR}`

**Important**: Both generated files are in `.gitignore` to prevent worktree-specific configurations from being merged to main. The templates are stored in `.claude/commands/worktree/` and used to generate fresh files for each worktree.

**Why Docker for Celery?**
- Ensures consistent environment across all workers
- Shares network with main project and Supabase
- Lightweight (~80MB per worktree vs 500MB+ for full stack)
- Connects to shared Supabase database (no duplicate PostgreSQL)

### Step 5.75: Mark Worktree-Specific Files to Skip Tracking

**Run from worktree root:**

```bash
# Mark files that get modified in worktrees to skip git tracking
git update-index --skip-worktree backend/app/worker/config.py
git update-index --skip-worktree backend/docker/Dockerfile.celery
```

**Why this is needed:**
- `backend/app/worker/config.py` gets patched in worktrees to check REDIS_URL environment variable
- `backend/docker/Dockerfile.celery` gets generated from template for worktrees
- Both files are tracked in main branch but have worktree-specific modifications
- `--skip-worktree` tells git to ignore local changes, preventing them from showing as modified

**This is a one-time operation** per worktree. Once set, git will not show these files as modified even when they're changed by worktree scripts.

### Step 6: Start Services

**Run from worktree root:**

```bash
./.claude/commands/worktree/scripts/start_worktree.sh ${COLOR}
```

This starts FastAPI, Celery, and Next.js services.

**Auto-Cleanup**: The script automatically kills any processes on the required ports before starting, eliminating "port already in use" errors.

### Step 7: Verify Setup

**Run from worktree root:**

```bash
./.claude/commands/worktree/scripts/health_check.sh ${COLOR}
```

This tests that all services are responding:
- **Backend**: Checks `/health` endpoint at http://localhost:${BACKEND_PORT}/health
- **Frontend**: Checks root endpoint at http://localhost:${FRONTEND_PORT}/
- **Database**: Verifies connection via Docker exec (no psql dependency required)

### Step 8: Display Summary

Show the user:

```
✅ Worktree Created Successfully!

Worktree: ${PROJECT_NAME}_${COLOR}
Branch: ${COLOR} (persistent infrastructure branch, mirrors main)
Database: ${PROJECT_NAME}_${COLOR}

Service URLs:
  Backend:  http://localhost:${BACKEND_PORT}
  Frontend: http://localhost:${FRONTEND_PORT}

Branch Workflow:
  - ${COLOR} branch: Infrastructure only, mirrors main, NEVER merged to main
  - Feature branches: Created from ${COLOR}, merged directly to main
  - After merge: Sync ${COLOR} with main using /worktree:wt_sync

Next steps:
  1. Create a feature branch:
     /worktree:wt_branch ${COLOR} feature/task-name

  2. Or navigate to worktree:
     cd worktrees/${PROJECT_NAME}_${COLOR}

Management commands:
  - Create branch: /worktree:wt_branch ${COLOR} <branch-name>
  - Stop services: /worktree:wt_stop ${COLOR}
  - Restart:       /worktree:wt_restart ${COLOR}
  - View status:   /worktree:wt_status ${COLOR}
  - Health check:  /worktree:wt_health ${COLOR}
```

## Port Reference

Default agent port assignments (can be customized in `worktree.config.yaml`):

| Agent | Backend Port | Frontend Port |
|-------|--------------|---------------|
| blue  | 6799         | 3010          |
| red   | 6809         | 3020          |
| white | 6819         | 3030          |

To add custom agents with different ports, edit `.claude/commands/worktree/worktree.config.yaml`.

## Error Handling

- **Database creation fails**: Check Supabase is running (`docker ps | grep supabase-db`)
- **Port conflicts**: Now handled automatically - stale processes are killed before starting services
- **Worktree already exists**: Delete first with `/worktree:wt_delete ${COLOR}`
- **Missing credentials**: Ensure main project's `app/.env` has all required DATABASE_* variables

## Configuration Architecture

All worktree scripts use shared configuration from:

- **`.claude/commands/worktree/worktree.config.yaml`**: Single source of truth for agents, ports, and database names (YAML format, recommended)
- **`.claude/commands/worktree/worktree_config.json`**: Legacy JSON format (deprecated, backward compatible)
- **`.claude/commands/worktree/scripts/common.sh`**: Shared path detection, utility functions, and configuration loading

The system supports **unlimited agents** with custom names. Simply add new agents to the YAML config with their port assignments and database names.

## Important Notes

- This command creates the **infrastructure** for the worktree
- The worktree is created on a persistent `${COLOR}` branch (e.g., `blue`, `red`, `white`, or any custom agent name)
- The agent branch mirrors `main` and is NEVER merged to main
- Use `/worktree:wt_branch` to create feature branches for actual work
- Feature branches merge directly to `main` (not to the agent branch)
- After merges, sync the agent branch with main using `/worktree:wt_sync`
- Each worktree can be reused for multiple feature branches over time
- Typical workflow: Create N worktrees once (e.g., blue, red, white, or alpha, beta, gamma), then create branches as needed
- **Scalable**: Support unlimited agents - just add them to `worktree.config.yaml`
- **Execution Context**:
  - **Steps 1-3**: Run from main project root (where `.env` files exist)
  - **Steps 4-7**: Run from worktree root using relative paths (e.g., `./.claude/commands/worktree/scripts/setup_database.sh`)
  - The worktree is a complete copy of the project, so all scripts exist at the same relative locations
  - Scripts internally use `git worktree list` to reference the main project when needed
