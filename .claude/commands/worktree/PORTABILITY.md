# Worktree System Portability Guide

This guide explains how to copy the complete worktree management system to any new project.

## Overview

The worktree system is **self-contained** and **portable**. Copy one directory and a few supporting files, and you have a complete multi-agent parallel development workflow.

## What Gets Copied

### Required (Core System)

```
.claude/
├── commands/
│   └── worktree/                     # ⭐ MAIN DIRECTORY - Copy this entire folder
│       ├── PORTABILITY.md            # This file
│       ├── README.md                 # Worktree management guide
│       ├── wt_*.md                   # 21 slash commands
│       ├── worktree.config.yaml      # Configuration file
│       └── scripts/                  # 19 shell scripts (includes ensure_gitignore.sh)
│
├── agents/                           # ⭐ REQUIRED - Copy these agent configs
│   ├── worktree-coding-agent.md      # Implementation agent
│   └── worktree-review-agent.md      # Code review agent
│
└── skills/                           # ⭐ REQUIRED - Copy these skills
    ├── requesting-code-review/       # How to create review docs
    │   └── SKILL.md
    └── receiving-code-review/        # How to handle feedback
        └── SKILL.md
```

### Optional (Enhanced Coordination)

```
.claude/
└── commands/
    └── coordinate/                   # 📚 OPTIONAL - Coordination documentation
        └── README.md                 # Complete workflow guide
```

---

## Step-by-Step Setup

### Step 1: Copy Core Worktree Directory

```bash
# From source project (agent_observer)
cd /path/to/agent_observer

# Copy entire worktree directory to target project
cp -r .claude/commands/worktree /path/to/target_project/.claude/commands/
```

**What this gives you:**
- ✅ 21 slash commands (`/worktree:wt_*`)
- ✅ 19 management scripts (including `ensure_gitignore.sh`)
- ✅ Complete documentation (README, PORTABILITY)
- ✅ **Automatic .gitignore setup** - The system automatically adds required entries when you create your first worktree

**Important**: When you run `/worktree:wt_create` for the first time in a new project, it automatically adds these entries to `.gitignore`:
- `worktrees/` - Prevents tracking worktree directories
- `docker/docker-compose.celery.yml` - Prevents tracking generated Celery configs
- `docker/Dockerfile.celery` - Prevents tracking generated Celery Dockerfiles

This happens automatically via the `ensure_gitignore.sh` script. No manual .gitignore editing required!

---

### Step 2: Copy Agent Configurations

```bash
# Copy both agent configs
cp .claude/agents/worktree-coding-agent.md /path/to/target_project/.claude/agents/
cp .claude/agents/worktree-review-agent.md /path/to/target_project/.claude/agents/
```

**What this gives you:**
- ✅ Coding agent (implements + tests)
- ✅ Review agent (validates code)

**Note:** These agents are required for `/worktree:wt_coordinate` to work.

---

### Step 3: Copy Review Skills

```bash
# Copy both skills directories
cp -r .claude/skills/requesting-code-review /path/to/target_project/.claude/skills/
cp -r .claude/skills/receiving-code-review /path/to/target_project/.claude/skills/
```

**What this gives you:**
- ✅ Review document templates
- ✅ Feedback processing guidelines
- ✅ Iteration protocols

**Note:** These skills guide agents on creating and responding to code reviews.

---

### Step 4: Copy Coordination Documentation (Optional)

```bash
# Optional: Copy coordination guide
cp -r .claude/commands/coordinate /path/to/target_project/.claude/commands/
```

**What this gives you:**
- 📚 Complete workflow documentation
- 📚 Best practices guide
- 📚 Troubleshooting reference

**Note:** This is just documentation. Not required for system to work.

---

### Step 5: Configure Project Settings in `worktree.config.yaml`

Update `.claude/commands/worktree/worktree.config.yaml` with your project's settings:

```yaml
# Project Configuration
project:
  name: your_project_name              # Used for database names, must match your project
  backend_project_dir: backend         # Where pyproject.toml is
  backend_app_dir: backend/app         # Where main.py/FastAPI app is
  frontend_dir: frontend               # Frontend directory (or null if no frontend)
  docker_env_path: backend/docker/.env # Docker environment file path

# Infrastructure Configuration
infrastructure:
  observability_api_url: http://localhost:6789/hooks/events/
  redis_url: redis://localhost:6380/0
```

**Critical:**
- `project.name` is used to construct database names and worktree paths
- Must match your project's name (no spaces, lowercase with underscores)
- All directory paths are relative to project root
- Set `frontend_dir: null` if your project has no frontend

---

### Step 6: Configure Database Connection (If Using)

If your project uses PostgreSQL and you want isolated worktree databases:

Create `app/.env.example` (or equivalent):

```bash
DATABASE_HOST=127.0.0.1
DATABASE_PORT=5432
DATABASE_NAME=${PROJECT_NAME}
DATABASE_USER=postgres
DATABASE_PASSWORD=your_password
```

**Note:** The worktree system will append `_blue`, `_red`, `_white` to `DATABASE_NAME` for each worktree.

---

### Step 7: Verify Installation

```bash
# In target project
cd /path/to/target_project

# List worktree commands (should see 21 commands)
ls .claude/commands/worktree/wt_*.md | wc -l

# Verify agents copied
ls .claude/agents/worktree-*.md

# Verify skills copied
ls .claude/skills/*-code-review/
```

**Expected output:**
```
21                                    # 21 worktree commands
worktree-coding-agent.md              # Coding agent
worktree-review-agent.md              # Review agent
receiving-code-review/                # Skills present
requesting-code-review/
```

---

## Complete File Checklist

Use this checklist to ensure all files are copied:

### Core System (Required)

- [ ] `.claude/commands/worktree/` (entire directory)
  - [ ] `PORTABILITY.md` (this file)
  - [ ] `README.md`
  - [ ] 21 `wt_*.md` command files
  - [ ] `scripts/` directory with 19 `.sh` files (including `ensure_gitignore.sh`)
  - [ ] `worktree.config.yaml` configuration file

### Agents (Required for Coordination)

- [ ] `.claude/agents/worktree-coding-agent.md`
- [ ] `.claude/agents/worktree-review-agent.md`

### Skills (Required for Code Review)

- [ ] `.claude/skills/requesting-code-review/SKILL.md`
- [ ] `.claude/skills/receiving-code-review/SKILL.md`

### Documentation (Optional)

- [ ] `.claude/commands/coordinate/README.md`

### Project Configuration (Create New)

- [ ] `.claude/.env` (create with `PROJECT_NAME`)
- [ ] `app/.env.example` (if using databases)

---

## Customization for Target Project

### Update Project Name References

The system auto-detects project name from `.claude/.env`, but you may want to update documentation:

1. **Update README examples** (optional):
   ```bash
   cd .claude/commands/worktree
   ```

2. **Update port allocation** (if conflicts):
   Edit `worktree.config.yaml` to change port assignments or add custom agents:
   ```yaml
   agents:
     - name: blue
       backend_port: 6799
       frontend_port: 3010
     - name: red
       backend_port: 6809
       frontend_port: 3020
     # Add unlimited custom agents:
     - name: alpha
       backend_port: 6829
       frontend_port: 3040
   ```

### Customize Agent Configurations

Edit agent prompts to match your project's tech stack:

**`.claude/agents/worktree-coding-agent.md`:**
- Update language versions (Python 3.11+ → your version)
- Update framework names (FastAPI → your framework)
- Update test framework (pytest → your test runner)
- Update linting tools (ruff → your linter)

**`.claude/agents/worktree-review-agent.md`:**
- Update code standards references
- Add project-specific security patterns
- Add project-specific performance guidelines

---

## Project-Specific Adjustments

### Directory Structure Configuration

**IMPORTANT**: The worktree system now supports **dynamic directory paths**. If your project doesn't use `app/` for backend or `frontend/` for frontend, simply configure in `.claude/.env`:

```bash
# Add to .claude/.env in your project
BACKEND_DIR=backend        # Or: server, api, src, packages/api
FRONTEND_DIR=client       # Or: web, ui, dashboard, apps/web
```

**Examples:**

```bash
# Standard Next.js project
BACKEND_DIR=server
FRONTEND_DIR=client

# Turborepo monorepo
BACKEND_DIR=apps/api
FRONTEND_DIR=apps/web

# T3 Stack
BACKEND_DIR=src
FRONTEND_DIR=src

# Separate repos structure
BACKEND_DIR=backend
FRONTEND_DIR=frontend
```

**No script modifications needed** - all scripts automatically detect and use configured directories!

See the "Configuring Directory Structure" section in [README.md](./README.md#configuring-directory-structure) for complete details.

### For Python Projects (Django, Flask, FastAPI)

**Already configured** ✅

The default setup assumes:
- Python backend with virtual environments
- Database migrations (Alembic or similar)
- Backend on port 6789+
- Frontend on port 3000+

**If your project structure differs**, add to `.claude/.env`:
```bash
BACKEND_DIR=your_backend_directory
```

### For JavaScript/TypeScript Projects (Node, Next.js, React)

**Mostly configured** ✅

**If your project structure differs**, add to `.claude/.env`:
```bash
BACKEND_DIR=server          # Or: api, backend
FRONTEND_DIR=client         # Or: web, app, ui
```

Optional updates in scripts:
- `scripts/install_deps.sh` - Confirm `npm install` (or switch to `pnpm`, `yarn`, `bun`)
- `scripts/start_worktree.sh` - Update dev server command if needed

### For Go/Rust/Other Languages

**Requires customization** ⚠️

Update these scripts:
- `install_deps.sh` - Change dependency installation
- `start_worktree.sh` - Change dev server startup
- `stop_worktree.sh` - Change process detection
- Remove Python-specific commands from agent configs

### For Non-Database Projects

**Simplification needed** ⚠️

If you don't need isolated databases:
1. Skip database-related commands (`wt_db_*`)
2. Remove database setup from `wt_create`
3. Remove database references from agent configs
4. Worktrees still provide isolation for code/branches/ports

---

## Testing the Installation

### Quick Test (No Worktree Creation)

```bash
# List all worktrees (should show just main)
/worktree:wt_list

# Show port allocation
/worktree:wt_ports

# Detect current context
/worktree:wt_detect
```

### Full Test (Create Blue Worktree)

```bash
# Create blue worktree
/worktree:wt_create blue

# Verify it was created
/worktree:wt_list

# Check status
/worktree:wt_status blue

# Create a test branch
/worktree:wt_branch blue test/verify-setup

# Clean up
cd ..
/worktree:wt_delete blue
```

**If all commands run without errors, installation is successful!**

---

## Dependencies

### System Requirements

**Required:**
- Git (worktree support)
- Bash shell

**Optional (depending on project):**
- PostgreSQL (for database isolation)
- Docker (if using containerized services)
- Python + pip/uv (for Python projects)
- Node.js + npm (for JavaScript projects)

### Claude Code Requirements

**Version:** Any version with slash command support

**Required features:**
- Task tool (for launching subagents)
- Read/Write/Edit tools
- Bash tool
- Glob/Grep tools

**Optional features:**
- TodoWrite (for agent task tracking)

---

## Troubleshooting Installation

### "Command not found: /worktree:wt_create"

**Cause:** Worktree directory not in `.claude/commands/`

**Fix:**
```bash
# Verify directory exists
ls .claude/commands/worktree/

# If missing, copy again
cp -r /path/to/source/.claude/commands/worktree .claude/commands/
```

### "detect_worktree.sh: No such file"

**Cause:** Scripts directory not copied or permissions wrong

**Fix:**
```bash
# Check scripts exist
ls .claude/commands/worktree/scripts/

# Fix permissions
chmod +x .claude/commands/worktree/scripts/*.sh
```

### "Agent config not found"

**Cause:** Agent files not copied

**Fix:**
```bash
# Copy agent configs
cp /path/to/source/.claude/agents/worktree-*.md .claude/agents/
```

### "PROJECT_NAME not defined"

**Cause:** `.claude/.env` missing or malformed

**Fix:**
```bash
# Create .claude/.env
echo "PROJECT_NAME=your_project_name" > .claude/.env
```

---

## What Each Component Does

### Commands (`worktree/wt_*.md`)

**Infrastructure Management:**
- `wt_create` - One-time worktree setup
- `wt_delete` - Remove worktree
- `wt_list` - Show all worktrees
- `wt_status` - Detailed worktree status

**Branch Management:**
- `wt_branch` - Create feature branch in worktree

**Service Management:**
- `wt_start` - Start all services
- `wt_stop` - Stop all services
- `wt_restart` - Restart all services

**Database Management:**
- `wt_db_create` - Create worktree database
- `wt_db_migrate` - Run migrations
- `wt_db_reset` - Reset database

**Environment Management:**
- `wt_env_generate` - Generate .env files
- `wt_env_validate` - Validate .env files
- `wt_deps_install` - Install dependencies

**Diagnostics:**
- `wt_health` - Health check all services
- `wt_logs` - View service logs
- `wt_ports` - Port allocation table
- `wt_detect` - Detect current context

**Maintenance:**
- `wt_sync` - Sync with main branch

**Orchestration:**
- `wt_coordinate` - Multi-agent task coordination
- `wt_prime` - Load project context

### Scripts (`scripts/*.sh`)

**Automation Layer:**
- All commands call these scripts
- Portable bash scripts (work on macOS/Linux)
- Handle low-level operations (git, database, processes)
- **`ensure_gitignore.sh`** - Automatically adds required .gitignore entries (called during worktree creation)

### Agents (`agents/worktree-*.md`)

**AI Agents:**
- `worktree-coding-agent` - Implements features + writes tests
- `worktree-review-agent` - Reviews code + validates quality

**Used by:** `/worktree:wt_coordinate` command

### Skills (`skills/*-code-review/`)

**Agent Guidelines:**
- `requesting-code-review` - How to create review documents
- `receiving-code-review` - How to process feedback

**Used by:** Agents during coordination workflow

---

## Migration Guide (Existing Projects)

If you already have git worktrees but want to add this system:

### 1. Assess Current Setup

```bash
# List existing worktrees
git worktree list

# Check for conflicts with default colors
ls ../ | grep -E "_(blue|red|white)"
```

### 2. Install System (Follow Steps 1-6)

### 3. Adopt Existing Worktrees (Optional)

If you want to manage existing worktrees with this system:

```bash
# For each existing worktree:
cd /path/to/existing_worktree

# Generate environment files
./.claude/commands/worktree/scripts/generate_worktree_env.sh <color> $(pwd)

# Set up database (if using)
./.claude/commands/worktree/scripts/setup_database.sh <color>

# Install dependencies
./.claude/commands/worktree/scripts/install_deps.sh <color>

# Start services
./.claude/commands/worktree/scripts/start_worktree.sh <color>
```

### 4. Or Start Fresh

Delete existing worktrees and create new ones using `/worktree:wt_create`.

---

## Updating the System

To update to latest version:

```bash
# In source project (agent_observer)
cd /path/to/agent_observer
git pull origin main

# Copy updated files to target project
cp -r .claude/commands/worktree /path/to/target_project/.claude/commands/
cp .claude/agents/worktree-*.md /path/to/target_project/.claude/agents/
cp -r .claude/skills/*-code-review /path/to/target_project/.claude/skills/
```

**Caution:** This will overwrite any customizations. Backup first if you made changes.

---

## Minimum Installation (Commands Only)

If you only want worktree management (no coordination):

**Copy:**
- ✅ `.claude/commands/worktree/` (entire directory)
- ✅ `.claude/.env` (create with `PROJECT_NAME`)

**Skip:**
- ❌ Agents
- ❌ Skills
- ❌ Coordinate documentation

**Available:**
- ✅ All 19 management commands (`wt_create` through `wt_sync`)
- ❌ No `/worktree:wt_coordinate` (requires agents)

---

## Full Installation (With Coordination)

For complete multi-agent workflow:

**Copy:**
- ✅ `.claude/commands/worktree/` (entire directory)
- ✅ `.claude/agents/worktree-coding-agent.md`
- ✅ `.claude/agents/worktree-review-agent.md`
- ✅ `.claude/skills/requesting-code-review/`
- ✅ `.claude/skills/receiving-code-review/`
- ✅ `.claude/commands/coordinate/` (documentation)
- ✅ `.claude/.env` (create with `PROJECT_NAME`)

**Available:**
- ✅ All 21 commands (including coordination)
- ✅ Multi-agent task orchestration
- ✅ Automated code review workflow

---

## Support

**Issues:** Check troubleshooting section above

**Questions:** Read `README.md` in worktree directory

**Customization:** Edit agent configs and scripts as needed

**Contributing:** If you improve the system, consider contributing back to source project

---

## Version History

**v1.1** - .gitignore automation update
- Automatic .gitignore setup via `ensure_gitignore.sh`
- Enhanced git tracking detection in generation scripts
- .gitignore validation in `wt_validate`
- 19 scripts (added `ensure_gitignore.sh`)

**v1.0** - Initial portable release
- 21 commands
- 18 scripts
- 2 agents
- 2 skills
- Complete documentation

---

**Installation complete?** Try:
```bash
/worktree:wt_list
/worktree:wt_ports
```

**Ready to create your first worktree?**
```bash
/worktree:wt_create blue
```

Happy parallel developing! 🎉
