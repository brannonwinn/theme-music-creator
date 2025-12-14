---
allowed-tools: Read, Bash
description: Lightweight coordinator primer - loads essential context without overwhelming window
---

# Prime Light - Coordinator Primer

Loads essential project context for coordinator agents. Uses ~10k tokens instead of 50k.

## Project Executive Summary

**Multi-Project AI Agent Observability Platform** - A centralized monitoring system that tracks AI agent activity across unlimited projects in real-time.

**Purpose**: Provide visibility into agent behavior, detect conflicts early, analyze performance patterns, and enable data-driven decisions about AI agent usage.

**Status**: Phase 3 (Frontend Dashboard) in progress
- Phase 1: Event Enhancement ✅ Complete
- Phase 2: Database Schema & Backend ✅ Complete
- Phase 3: Frontend Dashboard 🔄 In Progress
- Phase 4: Advanced Features 📋 Future

## Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│ LAYER 1: Data Collection (Portable Hooks)              │
│ - Claude Code hooks in ANY project (.claude/hooks/)    │
│ - Fires on: SessionStart, SessionEnd, Tool Use         │
│ - Custom: chat, notification, user_prompt, stop        │
│ - Auto-detects context via utils/context_detector.py   │
│ - Sends to centralized API                             │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ LAYER 2: Backend & Storage (Observability Server)      │
│ - FastAPI server (app/)                                │
│ - PostgreSQL with 6 core tables                        │
│ - Redis caching for git operations                     │
│ - Supabase realtime for WebSocket pub/sub             │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ LAYER 3: Frontend (Interactive Dashboard)              │
│ - Next.js 15+ web app (frontend/)                     │
│ - 7 specialized views                                  │
│ - Real-time updates (<500ms latency)                   │
│ - Multi-project filtering                             │
└─────────────────────────────────────────────────────────┘
```

## Codebase Discovery Commands

**Git-tracked files** (shows what's in version control):
```bash
git ls-files
```

**Full directory tree** (shows everything including untracked):
```bash
eza . --tree
```

**Find all CLAUDE.md convention files**:
```bash
find . -name "CLAUDE.md" -not -path "./node_modules/*" | sort
```

**Find core documentation**:
```bash
ls ai_docs/context/core_docs/*.md 2>/dev/null
```

**Find available context profiles**:
```bash
ls .claude/commands/profiles/*.md 2>/dev/null
```

**Find available agent configs**:
```bash
ls .claude/agents/*.md 2>/dev/null
```

## Key Directory Locations

**Backend**:
- `app/` - FastAPI application
- `app/database/` - SQLAlchemy models (6 core tables)
- `app/api/` - HTTP endpoints
- `app/schemas/` - Pydantic schemas
- `app/hooks/` - Hook event handlers
- `app/CLAUDE.md` - Backend conventions

**Frontend**:
- `frontend/` - Next.js 15+ application
- `frontend/app/` - App router pages
- `frontend/components/` - UI components (shadcn/ui)
- `frontend/hooks/` - React hooks (SWR)
- `frontend/CLAUDE.md` - Frontend conventions

**Infrastructure**:
- `.claude/hooks/` - Portable hooks (copy to any project)
- `.claude/commands/` - Slash commands (including this file)
- `.claude/commands/profiles/` - Pre-built context packages
- `.claude/agents/` - Agent configurations
- `docker/` - Docker Compose setup
- `docker/.env` - Environment variables (PROJECT_NAME defined here)

**Documentation**:
- `ai_docs/context/core_docs/` - PRD, Charter, ADD
- `ai_docs/plans/` - Strategic plans
- `README.md` - Project overview

## Database Schema (6 Core Tables)

### 1. projects
- Tracks each monitored project
- Fields: id, name, repo_url, created_at
- One project → Many agents/branches

### 2. agents
- Tracks each AI agent (Blue/Red/Coordinator)
- Fields: id, project_id, agent_type, health_score
- One agent → Many sessions

### 3. branches
- Tracks feature branch lifecycle
- Fields: id, project_id, name, status, created_at, merged_at
- One branch → Many sessions

### 4. conflicts
- Detects file/branch conflicts
- Fields: id, project_id, conflict_type, status, detected_at, resolved_at
- Links to session_activities for resolution tracking

### 5. agent_sessions
- Tracks each agent session
- Fields: id, agent_id, branch_id, started_at, ended_at, worktree_path
- One session → Many activities

### 6. session_activities
- Every tool call with enriched context
- Fields: id, session_id, activity_type, tool_name, file_path, git_context, timestamp
- Highest volume table (millions of rows)

**Relationships**:
```
projects → agents → agent_sessions → session_activities
projects → branches → agent_sessions
projects → conflicts
```

## Available Context Profiles

Use these pre-built profiles for common task types (5k-10k tokens each):

### 1. `profiles/backend.md`
**When to use**: Workflow implementation, API endpoints, database models, Celery tasks

**Includes**:
- app/CLAUDE.md - Application architecture
- app/core/CLAUDE.md - Workflow mechanics (if exists)
- app/core/nodes/CLAUDE.md - Node patterns (if exists)
- Database schema (6 tables)
- Event ingestion flow
- ~7k tokens

### 2. `profiles/frontend.md`
**When to use**: Dashboard views, UI components, real-time updates, data visualization

**Includes**:
- frontend/CLAUDE.md - Frontend conventions
- Dashboard requirements (FR-1 through FR-7)
- Component library (shadcn/ui patterns)
- WebSocket integration
- ~6k tokens

### 3. `profiles/review.md`
**When to use**: Code review tasks

**Includes**:
- Code quality standards
- Security patterns
- Performance guidelines
- Test coverage requirements
- ~4k tokens

### 4. `profiles/testing.md`
**When to use**: Test generation, test debugging

**Includes**:
- Backend testing patterns (pytest)
- Frontend testing patterns (Jest/React Testing Library)
- Test coverage targets
- Mock/stub patterns
- ~5k tokens

### 5. `profiles/docs.md`
**When to use**: Documentation updates, README changes

**Includes**:
- Documentation standards
- Markdown conventions
- API documentation patterns
- ~3k tokens

## Context Selection Logic (For Coordinators)

```
IF task involves workflow/API/database:
    context = Read(".claude/commands/profiles/backend.md")
ELIF task involves dashboard/UI/components:
    context = Read(".claude/commands/profiles/frontend.md")
ELIF task is code review:
    context = Read(".claude/commands/profiles/review.md")
ELIF task involves tests:
    context = Read(".claude/commands/profiles/testing.md")
ELIF task involves documentation:
    context = Read(".claude/commands/profiles/docs.md")
ELSE:
    # Novel/complex task - use context-coordinator
    result = Task(
        subagent_type="context-coordinator",
        prompt=f"Build context for: {task_description}"
    )
    context = result  # Context returned directly from agent

# Launch subagent with tailored context
Task(
    subagent_type="coding-agent",
    prompt=f"{context}\n\n# Task\n{task_description}"
)
```

## Key Technical Constraints

**Backend**:
- Python 3.11+
- FastAPI async/await pattern
- SQLAlchemy ORM (no raw SQL)
- Pydantic for all schemas
- Alembic for migrations

**Frontend**:
- Next.js 15+ (App Router only)
- TypeScript strict mode
- Tailwind CSS + shadcn/ui
- SWR for data fetching
- WebSocket for real-time

**Database**:
- PostgreSQL 15+
- Supabase for realtime pub/sub
- Redis for caching git operations
- No MySQL/MongoDB

**Deployment**:
- Docker Compose
- Self-hosted (no cloud dependencies)
- All services containerized

## Success Metrics

**Performance**:
- WebSocket latency <500ms (P95)
- Dashboard load time <2s (P95)
- Handle 1000+ events/min per project

**Reliability**:
- 99.9% uptime for observability server
- Zero data loss (all events persisted)
- Graceful degradation if WebSocket fails

**User Experience**:
- Multi-project filtering <100ms
- Search results <200ms
- Export data in <5s (10k rows)

## Quick Reference Commands

**Get project name** (defined in docker/.env):
```bash
grep "^PROJECT_NAME=" docker/.env | cut -d'=' -f2
```

**Start services**:
```bash
cd docker && ./start.sh
```

**View logs** (replace `${PROJECT_NAME}` with actual value from docker/.env):
```bash
docker logs -f ${PROJECT_NAME}_api
docker logs -f ${PROJECT_NAME}_celery_worker
```

**Database access**:
```bash
docker exec -it supabase-db psql -U postgres -d postgres
```

**Run backend tests**:
```bash
docker exec -it ${PROJECT_NAME}_api pytest app/tests/ -v
```

**Run frontend dev**:
```bash
cd frontend && npm run dev
```

## When to Use Full Context (/prime)

Reserve the full prime.md context loader for:
- Initial project setup
- Architecture decision-making
- Cross-cutting changes affecting multiple layers
- Complex debugging spanning backend + frontend

For most tasks, use the appropriate profile from `.claude/commands/profiles/` to keep context windows clean.

## Context-Coordinator Agent (Fallback)

For novel tasks not matching pre-built profiles, the coordinator can launch:

```
result = Task(
    subagent_type="context-coordinator",
    description="Build tailored context",
    prompt=f"Build context for: {task_description}"
)
# result contains the consolidated markdown context
```

The context-coordinator agent:
1. Loads full context via /prime (internally)
2. Analyzes task requirements
3. Selects 3-5 relevant documents
4. Builds consolidated markdown
5. Returns context content directly

**Trade-off**: Adds 15-30s overhead but handles edge cases.

---

**Token Budget**: ~10k tokens (vs. 50k for full prime.md)
**Coordinator Window**: Stays clean for managing multiple subagents
**Subagent Window**: Gets tailored context (5k-10k tokens)
