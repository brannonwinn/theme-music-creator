# Worktree Multi-Agent Coordination System

Complete guide to using git worktrees with multi-agent coordination for parallel development.

## Overview

This system enables parallel development using git worktrees where:
- Each worktree has isolated database and environment
- Claude Code acts as coordinator within each worktree
- Subagents handle implementation and code review
- One evolving review document tracks progress
- Documentation updates validated before applying

## Architecture

```
Main Directory (${PROJECT_NAME}/)
├── app/                    # Application code
├── frontend/               # Next.js frontend
├── ai_docs/
│   └── reviews/
│       ├── pending/        # Active review documents
│       └── approved/       # Completed reviews
└── .claude/
    ├── commands/
    │   ├── prime.md        # Context scanning
    │   ├── coordinate/
    │   │   └── README.md   # This file
    │   └── worktree/
    │       ├── wt_coordinate.md        # Orchestration command
    │       └── scripts/
    │           └── detect_worktree.sh  # Context detection
    ├── agents/
    │   ├── worktree-coding-agent.md    # Implementation agent
    │   └── worktree-review-agent.md    # Review agent
    └── skills/
        ├── requesting-code-review/     # How to request review
        └── receiving-code-review/      # How to handle feedback

Worktree Directories (parallel development)
├── ${PROJECT_NAME}_blue/    # Blue worktree
│   ├── Database: ${PROJECT_NAME}_blue
│   └── Ports: 6799 (backend), 3010 (frontend)
├── ${PROJECT_NAME}_red/     # Red worktree
│   ├── Database: ${PROJECT_NAME}_red
│   └── Ports: 6809 (backend), 3020 (frontend)
└── ${PROJECT_NAME}_white/   # White worktree
    ├── Database: ${PROJECT_NAME}_white
    └── Ports: 6819 (backend), 3030 (frontend)
```

## Quick Start

### 1. Create Worktree (One-Time Setup)

```bash
# From main directory
cd /path/to/${PROJECT_NAME}

# Create blue worktree on new branch
git worktree add ../${PROJECT_NAME}_blue -b feature/blue-task

# Or use existing branch
git worktree add ../${PROJECT_NAME}_blue feature/existing-branch
```

### 2. Launch Claude Code in Worktree

```bash
# Navigate to worktree
cd ../${PROJECT_NAME}_blue

# Launch Claude Code
claude
```

### 3. Coordinate a Task

```bash
# In Claude Code session
/worktree:wt_coordinate "Implement customer support workflow with priority routing and SLA tracking"
```

That's it! Claude will:
1. Gather project context
2. Launch coding agent to implement
3. Launch review agent to validate
4. Handle iteration until approved
5. Notify you when ready to merge

## Workflow Phases

### Phase 1: Initial Implementation

**Coordinator (you):**
1. Run `/worktree:wt_coordinate "task description"`
2. Gather context using `/worktree:wt_prime` logic
3. Record BASE_SHA
4. Launch coding agent with task + context

**Coding Agent:**
1. Read all context documents (CLAUDE.md, PRD, ADD)
2. Implement feature (backend and/or frontend)
3. Write comprehensive tests
4. Run quality checks (linting, type checking, tests)
5. Suggest documentation updates (NOT applied yet)
6. Create review document in `${REVIEW_BASE_DIR}/pending/`
7. Signal completion with document path

**Review Document Created:**
```
${REVIEW_BASE_DIR}/pending/review_customer_support_20250113_143022.md
```

### Phase 2: Code Review

**Coordinator:**
1. Extract review document path from coding agent
2. Launch review agent with document path

**Review Agent:**
1. Read review document
2. Examine code changes via git diff
3. Read implementation files
4. Validate against project patterns
5. Validate documentation suggestions
6. Categorize issues (Critical/Important/Minor)
7. Append feedback to review document
8. Provide verdict: Yes/With fixes/No

### Phase 3: Iteration (If "With fixes")

**Coordinator:**
1. Relaunch coding agent with review document

**Coding Agent (Iteration Mode):**
1. Read review document feedback
2. Read receiving-code-review principles
3. **Apply validated documentation updates** (review agent approved them)
4. Fix issues (Critical → Important → Minor)
5. Update/add tests
6. **Re-run ALL quality checks** (linting, type checking, tests)
7. Append response to review document
8. Signal ready for re-review

**Coordinator:**
1. Relaunch review agent
2. Repeat until verdict is "Yes"

### Phase 4: Approval

**Coordinator:**
1. Move review document to `approved/`
2. Update status to "Approved"
3. Notify human with merge instructions

**Human:**
1. Review approved document
2. Check changes: `git diff main..HEAD`
3. Merge to main: `git merge feature-branch`
4. Push: `git push origin main`
5. Clean up worktree (optional)

## Review Document Structure

Review documents evolve through iterations:

```markdown
# Code Review: Customer Support Workflow

**Date**: 2025-01-13 14:30:22
**Worktree**: blue
**Branch**: feature/customer-support
**Status**: Pending Review  # Changes to "Approved" when done

## Git Range
**Base SHA**: abc123def
**Head SHA**: xyz789ghi

## What Was Implemented
[Detailed description by coding agent]

## Test Coverage
[Tests created and results]

## Quality Check Results
✅ Linting, type checking, tests all passing

## Suggested Documentation Updates
**DO NOT apply yet** - review agent validates first
[Detailed suggestions with insertion points]

---

## Review Agent Section

### Review Round 1 - 2025-01-13 15:00:00

#### Summary
Implementation solid but has 2 critical issues.

#### Strengths
- ✅ Clean architecture
- ✅ Good test coverage

#### Issues
##### Critical
1. 🔴 SQL injection risk...

##### Important
1. ⚠️ Missing error handling...

#### Documentation Review
✅ app/workflows/CLAUDE.md - Accurate
❌ frontend/CLAUDE.md - Import incorrect

#### Verdict
**Ready to merge?** With fixes

---

## Coding Agent Response - 2025-01-13 16:00:00

### Documentation Updates Applied
✅ app/workflows/CLAUDE.md
✅ frontend/CLAUDE.md (with import fix)

### Issues Addressed
✅ SQL injection fixed
✅ Error handling added
✅ All tests passing

---

## Review Agent Section (Round 2)

### Review Round 2 - 2025-01-13 16:30:00

#### Summary
All issues addressed. Ready to merge.

#### Verdict
**Ready to merge?** Yes

---
```

**Key Properties:**
- **Single document** evolves through all rounds
- **Complete audit trail** of what changed and why
- **Documentation validation** before applying
- **Quality proof** at each stage
- **Clear verdict** at each review round

## Database Isolation

Each worktree uses its own database:

| Worktree | Database Name | Backend Port | Frontend Port |
|----------|---------------|--------------|---------------|
| main | `${PROJECT_NAME}` | 6789 | 3000 |
| blue | `${PROJECT_NAME}_blue` | 6799 | 3010 |
| red | `${PROJECT_NAME}_red` | 6809 | 3020 |
| white | `${PROJECT_NAME}_white` | 6819 | 3030 |

**Setup:**
```bash
# In worktree, coding agent runs migrations
cd app
uv run alembic upgrade head
```

**Isolation Benefits:**
- Parallel development without conflicts
- Test migrations independently
- Rollback without affecting other work
- Clean slate for each feature

## Context Detection

The `detect_worktree.sh` script provides environment variables:

```bash
# Source in coordination commands
source <(./.claude/commands/worktree/scripts/detect_worktree.sh)

# Available variables:
echo $WORKTREE_COLOR     # blue/red/white/main
echo $WORKTREE_PATH      # Absolute path
echo $WORKTREE_BRANCH    # Current branch
echo $PROJECT_NAME       # From .claude/.env
echo $DATABASE_NAME      # ${PROJECT_NAME}_${color}
echo $AI_DOCS_DIR        # From config (project.ai_docs_dir)
echo $REVIEW_BASE_DIR    # ${AI_DOCS_DIR}/reviews
```

**Portability:**
- No hardcoded paths
- Works across projects
- Auto-detects context from directory name

## Commands Reference

### `/worktree:wt_prime` - Context Scanning

Scans project for documentation to include in agent context:

```bash
/worktree:wt_prime
```

**Discovers:**
- All `CLAUDE.md` files (patterns and conventions)
- Core docs in `ai_docs/context/core_docs/` (PRD, ADD, etc.)

**Output:**
List of documents to read before implementing.

**Used by:**
`/worktree:wt_coordinate` command (automatic)

### `/worktree:wt_coordinate` - Orchestrate Task

Main coordination command for implementing features:

```bash
/worktree:wt_coordinate "task description"
```

**What it does:**
1. Detect worktree context
2. Gather prime context
3. Record BASE_SHA
4. Launch coding agent → create review doc
5. Launch review agent → append feedback
6. Handle iteration loop → relaunch agents as needed
7. Move to approved/ when ready
8. Notify human with merge instructions

**Requirements:**
- Must be run from within worktree directory
- Clean git state (or at least committed work)
- Database set up for worktree

**Location:**
`.claude/commands/worktree/wt_coordinate.md`

## Agent Roles

### Worktree Coding Agent

**Tools:** Read, Write, Edit, Glob, Grep, Bash, TodoWrite

**Responsibilities:**
- Read context documents (CLAUDE.md, PRD, ADD)
- Implement features (backend and/or frontend)
- Write comprehensive tests
- Run quality checks
- Suggest documentation updates (not apply initially)
- Create review document
- Handle iteration feedback
- Apply validated documentation updates
- Re-run quality checks after fixes

**Configuration:**
`.claude/agents/worktree-coding-agent.md`

### Worktree Review Agent

**Tools:** Read, Glob, Grep, Bash, Edit, TodoWrite

**Responsibilities:**
- Read review document
- Examine code via git diff
- Validate against patterns
- Validate documentation suggestions
- Categorize issues (Critical/Important/Minor)
- Append feedback to review document
- Provide clear verdict

**Configuration:**
`.claude/agents/worktree-review-agent.md`

## Skills Reference

### requesting-code-review

**When to use:**
- After completing implementation
- After addressing review feedback

**What it does:**
- Guides coding agent on creating review documents
- Shows document structure and required sections
- Explains how to handle iteration feedback

**Location:**
`.claude/skills/requesting-code-review/`

### receiving-code-review

**When to use:**
- When processing review agent feedback
- Before implementing suggested fixes

**What it does:**
- Verify feedback before implementing
- Push back when technically wrong
- Implement by priority (Critical → Important → Minor)
- Test each fix individually
- Avoid performative agreement

**Location:**
`.claude/skills/receiving-code-review/`

## Quality Checks

All agents must run quality checks before signaling ready:

### Backend (Python/FastAPI)

```bash
# Linting
ruff check app/

# Type checking
mypy app/

# Tests
pytest app/tests/ -v
```

### Frontend (Next.js/React)

```bash
# Linting
npm run lint

# Type checking
npm run type-check

# Tests
npm test
```

**When to run:**
- ✅ Before creating initial review document
- ✅ After addressing each round of feedback
- ✅ Before signaling ready for re-review

**All checks must pass** before proceeding.

## Best Practices

### For Coordinators (Human's Claude Session)

1. **Run `/worktree:wt_coordinate` from worktree directory** - Context detection relies on path
2. **Let agents complete** - Don't interrupt, wait for signals
3. **Extract paths from responses** - Don't assume file names
4. **Limit iterations** - If > 3 rounds, escalate to human
5. **Preserve review documents** - Complete audit trail
6. **Verify before moving to approved** - Double-check verdict is "Yes"

### For Coding Agents

1. **Read context documents first** - CLAUDE.md files, PRD, ADD
2. **Run quality checks before review** - Tests must pass
3. **Document thoroughly** - Review document is audit trail
4. **Suggest docs, don't apply initially** - Wait for validation
5. **Apply validated docs during iteration** - Review agent approved them
6. **Re-run quality checks after fixes** - Prevent regressions
7. **Append to review document** - Don't create new documents

### For Review Agents

1. **Read the actual code** - Don't review without reading
2. **Validate docs before approval** - Check accuracy and helpfulness
3. **Be specific** - File:line references, not vague
4. **Categorize correctly** - Not everything is Critical
5. **Append feedback** - Don't create separate documents
6. **Update status if approved** - Change to "Approved"
7. **Provide clear verdict** - Yes/With fixes/No

## Troubleshooting

### "Can't find review document path"

**Symptom:** Coordinator can't extract path from coding agent

**Solution:**
```bash
# Search for recent review documents
Glob(pattern="${REVIEW_BASE_DIR}/pending/review_*.md")

# Read most recent
Read(file_path="<path from glob>")
```

### "Review agent not appending"

**Symptom:** Review agent creates new document instead of appending

**Cause:** Review document missing placeholder section

**Solution:**
Check review document has:
```markdown
## Review Agent Section

(Review agent will append feedback below)
```

### "Tests failing after fixes"

**Symptom:** Quality checks fail in iteration round

**Cause:** Coding agent didn't re-run tests after fixes

**Solution:**
Relaunch coding agent with explicit reminder:
```
CRITICAL: Re-run ALL quality checks before signaling ready
```

### "Iteration loop stuck"

**Symptom:** More than 3 review rounds without approval

**Diagnose:**
```bash
# Count review rounds
Grep(pattern="Review Round", path="<review_doc>", output_mode="count")
```

**Solutions:**
- Issues too complex for iteration → notify human
- Architectural problems → requires redesign
- Start fresh with new approach

### "Context too large for agent"

**Symptom:** Agent launch fails due to context size

**Solution:**
- Prioritize most relevant documents
- Use task-specific context section
- Link to docs instead of embedding full content

### "Database connection failed"

**Symptom:** Coding agent can't connect to database

**Solution:**
```bash
# Verify database exists
docker exec -it supabase-db psql -U postgres -l | grep ${PROJECT_NAME}

# Run migrations if needed
cd app
uv run alembic upgrade head
```

### "Port already in use"

**Symptom:** Dev server can't start (port conflict)

**Solution:**
```bash
# Check what's using the port
lsof -i :6799

# Kill if needed
kill -9 <PID>

# Or use different port offset
# Edit docker/.env or app/.env
```

## Merging Back to Main

After coordinator signals "Approved":

### 1. Review Changes

```bash
# In worktree directory
git diff main..HEAD --stat
git log main..HEAD --oneline

# Read approved review document
cat ${REVIEW_BASE_DIR}/approved/review_<task>_<timestamp>.md
```

### 2. Merge to Main

```bash
# Switch to main
cd ../${PROJECT_NAME}_${COLOR} # or wherever main is
git checkout main

# Merge the feature branch
git merge feature/customer-support

# Push to remote
git push origin main
```

### 3. Clean Up Worktree (Optional)

```bash
# Remove worktree
git worktree remove ../${PROJECT_NAME}_${COLOR}

# Delete feature branch
git branch -d feature/customer-support
```

### 4. Or Keep for Next Task

```bash
# In worktree, reset to main
cd ../${PROJECT_NAME}_${COLOR}
git checkout main
git pull origin main

# Create new feature branch
git checkout -b feature/next-task

# Coordinate new task
/worktree:wt_coordinate "next task description"
```

## File Organization

```
.claude/
├── commands/
│   ├── prime.md                       # Context scanning command
│   ├── coordinate/
│   │   └── README.md                  # This file - coordination docs
│   └── worktree/
│       ├── wt_coordinate.md           # Main orchestration command
│       └── scripts/
│           └── detect_worktree.sh     # Environment detection utility
├── agents/
│   ├── worktree-coding-agent.md       # Full-stack implementation
│   └── worktree-review-agent.md       # Code review and validation
└── skills/
    ├── requesting-code-review/        # How to create review docs
    │   └── SKILL.md
    └── receiving-code-review/         # How to process feedback
        └── SKILL.md

ai_docs/
├── context/
│   └── core_docs/                     # PRD, ADD, etc.
└── reviews/
    ├── pending/                       # Active review documents
    │   └── review_<task>_<timestamp>.md
    └── approved/                      # Completed reviews
        └── review_<task>_<timestamp>.md
```

## Advanced Usage

### Multiple Concurrent Tasks

Run different tasks in different worktrees:

```bash
# Terminal 1 - Blue worktree
cd ${PROJECT_NAME}_blue
claude
/worktree:wt_coordinate "Implement auth system"

# Terminal 2 - Red worktree
cd ${PROJECT_NAME}_red
claude
/worktree:wt_coordinate "Add notification service"

# Terminal 3 - White worktree
cd ${PROJECT_NAME}_white
claude
/worktree:wt_coordinate "Refactor API layer"
```

Each runs independently with isolated:
- Database
- Ports
- Review documents
- Git branches

### Reusing Review Documents

If iteration reveals new approach needed:

```bash
# Coding agent can reference previous attempts
Read(file_path="${REVIEW_BASE_DIR}/pending/review_previous_attempt.md")

# Learn from what didn't work
# Implement new approach
# Create new review document for new approach
```

### Custom Context Documents

Add task-specific context:

```bash
# Create planning document
Write(file_path="ai_docs/context/task_specific/auth_design.md", ...)

# Reference in /worktree:wt_coordinate prompt
/worktree:wt_coordinate "Implement auth per ai_docs/context/task_specific/auth_design.md"
```

Coding agent will read and follow the design.

## Success Metrics

You're using the system effectively when:

### Coordinators
- ✅ Agents complete work without manual intervention
- ✅ Review documents capture complete audit trail
- ✅ Iterations resolve issues (not endless loops)
- ✅ Documentation updates validated before applying
- ✅ Quality checks passing at each stage

### Coding Agents
- ✅ Read context before implementing
- ✅ Tests comprehensive and passing
- ✅ Quality checks pass before review
- ✅ Documentation suggestions accurate
- ✅ Iteration feedback addressed systematically

### Review Agents
- ✅ Issues categorized correctly
- ✅ Feedback specific with file:line references
- ✅ Documentation validation catches errors
- ✅ Verdicts clear and justified
- ✅ Approvals only when truly ready

## FAQ

**Q: Can I use this without git worktrees?**
A: Yes, but you lose isolation. Run `/worktree:wt_coordinate` from main directory and it will work, but uses main database/ports.

**Q: Do I need to create all three worktrees?**
A: No, create only what you need. One worktree for one parallel task is fine.

**Q: Can review agent make code changes?**
A: No, review agent is read-only. Only appends feedback to review document.

**Q: What if I disagree with review agent?**
A: Coding agent should push back with technical reasoning (receiving-code-review skill). Coordinator can override if needed.

**Q: How do I update agent configurations?**
A: Edit `.claude/agents/worktree-coding-agent.md` or `worktree-review-agent.md`. Changes take effect on next launch.

**Q: Can I run this in CI/CD?**
A: Not yet - requires interactive Claude Code session. Future: headless mode.

**Q: What about frontend-only or backend-only tasks?**
A: Coding agent handles both. Skips frontend/backend steps if not needed for the task.

## Getting Help

**Documentation:**
- This file - System overview
- `.claude/commands/worktree/wt_coordinate.md` - Orchestration details
- `.claude/agents/worktree-coding-agent.md` - Implementation guide
- `.claude/agents/worktree-review-agent.md` - Review guide
- `.claude/skills/requesting-code-review/` - Review document creation
- `.claude/skills/receiving-code-review/` - Feedback processing

**Debugging:**
- Check review documents in `${REVIEW_BASE_DIR}/pending/`
- Read agent configurations in `.claude/agents/`
- Verify context detection: `source <(detect_worktree.sh) && env | grep WORKTREE`

**Issues:**
- Review documents stuck in pending → check review agent feedback
- Tests failing → check quality check results in review document
- Context errors → verify CLAUDE.md files exist and are readable
- Database errors → check database name matches worktree color

Happy coordinating!
