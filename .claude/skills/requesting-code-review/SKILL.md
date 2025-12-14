---
name: requesting-code-review
description: Use when completing implementation in worktree to create review document for coordinator to route to review agent - documents what was built, test results, and suggested documentation updates
---

# Requesting Code Review (Worktree Workflow)

Create a review document that the coordinator will route to the review agent.

**Core principle:** Document thoroughly, validate rigorously.

## When to Request Review

**Mandatory:**
- After completing initial implementation and tests
- After addressing review feedback in iteration loop
- Before signaling ready for merge

**What triggers review:**
- All tests passing
- All quality checks passing (linting, type checking)
- Implementation matches task requirements
- Documentation suggestions prepared

## How to Request Review

### 1. Ensure Quality Checks Pass

**Backend:**
```bash
ruff check app/
mypy app/
pytest app/tests/ -v
```

**Frontend:**
```bash
npm run lint
npm run type-check
npm test
```

All checks must pass before creating review document.

### 2. Get Git Range

```bash
# BASE_SHA was provided by coordinator at start
HEAD_SHA=$(git rev-parse HEAD)
```

### 3. Create Review Document

Create document in `${REVIEW_BASE_DIR}/pending/` (default: `ai_docs/reviews/pending/`) with this structure:

```markdown
# Code Review: {Task Description}

**Date**: {ISO timestamp}
**Worktree**: {WORKTREE_COLOR}
**Branch**: {WORKTREE_BRANCH}
**Status**: Pending Review

## Git Range

**Base SHA**: {BASE_SHA}
**Head SHA**: {HEAD_SHA}

```bash
git diff {BASE_SHA}...{HEAD_SHA} --stat
git log {BASE_SHA}..{HEAD_SHA} --oneline
```

## What Was Implemented

{Detailed description}

**Changed files:**
- app/workflows/customer_support_workflow.py - Main workflow orchestration
- app/workflows/customer_support_nodes/analyze_request_node.py - Request analysis
- app/tests/test_workflows/test_customer_support_workflow.py - Comprehensive tests

**Key decisions:**
- Used priority-based routing pattern
- Implemented SLA tracking with timezone awareness
- Added retry logic for external API calls

## Test Coverage

**Tests created:**
- test_customer_support_happy_path - Full workflow success
- test_priority_routing_high - High priority routing
- test_sla_tracking - SLA calculation accuracy
- test_error_handling - API failure scenarios

**Test results:**
```
===== 18 passed in 2.45s =====
```

## Quality Check Results

**Linting:** ✅ Passed
**Type checking:** ✅ Passed
**Tests:** ✅ 18/18 passed

## Suggested Documentation Updates

**DO NOT apply these updates yet** - review agent will validate first.

### app/workflows/CLAUDE.md

**Section:** Extension Points
**Insert after:** Existing extension points

```markdown
### Customer Support Workflow Pattern

When implementing customer support workflows:

1. **Priority Routing**: Use PriorityRouter with enum-based levels
2. **SLA Tracking**: Store request timestamp, calculate with timezone awareness
3. **External APIs**: Wrap in try/except with configurable timeout
4. **Status Updates**: Emit events at each workflow stage

Example:
\`\`\`python
class PriorityRouter(Router):
    async def route(self, context: TaskContext) -> str:
        priority = context.data.get("priority", "medium")
        return f"handle_{priority}_priority"
\`\`\`
```

### frontend/components/CLAUDE.md

**Section:** Data Fetching Patterns
**Insert after:** Existing patterns

```markdown
### Support Request Dashboard

Use SWR with auto-refresh for real-time updates:

\`\`\`typescript
const { data, error } = useSWR('/api/support/requests', {
  refreshInterval: 5000,
  revalidateOnFocus: true
})
\`\`\`
```

---

## Review Agent Section

(Review agent will append feedback below)
```

**Key elements:**
- Clear git range for diff inspection
- Detailed description of what changed
- Test coverage summary with results
- Quality check results (all must pass)
- Suggested docs with clear insertion points
- Placeholder for review agent feedback

### 4. Signal Completion

Tell coordinator you're ready for review:

```markdown
## Implementation Complete

Review document created at: ${REVIEW_BASE_DIR}/pending/review_customer_support_20250113_143022.md

Base SHA: abc123def
Head SHA: xyz789ghi

Ready for review.
```

Coordinator will launch review agent with the document path.

## Acting on Review Feedback

When coordinator relaunches you with feedback:

### 1. Read Review Document

```python
Read(file_path="{review_document_path}")
```

Extract feedback sections:
- Critical issues (must fix)
- Important issues (should fix)
- Minor issues (nice to have)
- Documentation feedback

### 2. Read Receiving Principles

```python
Read(file_path=".claude/skills/receiving-code-review/SKILL.md")
```

### 3. Apply Validated Documentation Updates

Review agent has validated your suggestions. Apply them now:

```python
Edit(
    file_path="app/workflows/CLAUDE.md",
    old_string="## Extension Points",
    new_string="""## Extension Points

### Customer Support Workflow Pattern
[Your validated suggestion]

## Extension Points"""
)
```

### 4. Fix Issues by Priority

**Critical → Important → Minor**

For each issue:
- Read the code location mentioned
- Understand the problem
- Implement the fix
- Update/add tests if needed

### 5. Re-Run All Quality Checks

**MANDATORY** - prevents regressions:

```bash
# Backend
ruff check app/
mypy app/
pytest app/tests/ -v

# Frontend
npm run lint
npm run type-check
npm test
```

All must pass before proceeding.

### 6. Append Response to Review Document

```python
Edit(
    file_path="{review_document_path}",
    old_string="## Review Agent Section\n\n(Review agent will append feedback below)",
    new_string=f"""## Review Agent Section

[Review agent's feedback from Round 1]

---

## Coding Agent Response - {timestamp}

### Documentation Updates Applied

✅ app/workflows/CLAUDE.md - Added Customer Support Workflow Pattern
✅ frontend/components/CLAUDE.md - Added Support Request Dashboard pattern

### Issues Addressed

#### Critical Issues Fixed

1. ✅ **SQL Injection Risk** (app/api/routes/support.py:45)
   - Changed to parameterized query using SQLAlchemy
   - Code: `session.execute(text("SELECT * WHERE id = :id"), {{"id": user_id}})`

2. ✅ **Missing Error Handling** (analyze_request_node.py:67)
   - Wrapped external API call in try/except with 10s timeout
   - Added retry logic with exponential backoff

#### Important Issues Fixed

1. ✅ **Missing Test Coverage** - Error scenarios
   - Added test_api_failure_handling
   - Added test_timeout_handling
   - Added test_invalid_priority

2. ✅ **N+1 Query** (app/api/routes/support.py:78)
   - Added selectinload() for related entities
   - Query now single database round-trip

### Quality Check Results

**Linting:** ✅ Passed
**Type checking:** ✅ Passed
**Tests:** ✅ 24/24 passed (added 6 new tests)

### Ready for Re-Review

All Critical and Important issues have been addressed. Tests and quality checks passing.

---

## Review Agent Section (Round 2)

(Review agent will append next feedback if needed)
"""
)
```

### 7. Signal Ready for Re-Review

```markdown
## Fixes Complete

Review document updated at: ${REVIEW_BASE_DIR}/pending/review_customer_support_20250113_143022.md

All Critical and Important issues addressed.
Quality checks passing.

Ready for re-review.
```

## Complete Example: Initial Implementation

```
[Coordinator launches you with task]

You (coding agent):
  1. Read context documents (CLAUDE.md files, PRD, ADD)
  2. Implement customer support workflow
  3. Write 18 tests, all passing
  4. Run quality checks (ruff, mypy, pytest) - all passing
  5. Prepare documentation suggestions

You: Creating review document...

Write(
  file_path="${REVIEW_BASE_DIR}/pending/review_customer_support_20250113_143022.md",
  content="""
  # Code Review: Customer Support Workflow

  **Status**: Pending Review

  ## Git Range
  Base: abc123, Head: xyz789

  ## What Was Implemented
  - Priority-based routing
  - SLA tracking
  - External API integration

  ## Test Coverage
  18/18 tests passing

  ## Quality Check Results
  ✅ All checks passing

  ## Suggested Documentation Updates
  [Detailed suggestions for app/workflows/CLAUDE.md]

  ---
  ## Review Agent Section
  (Review agent will append feedback below)
  """
)

You: Implementation complete. Ready for review.
[Signal to coordinator with document path]
```

## Complete Example: Iteration Round

```
[Coordinator relaunches you with review feedback]

You (coding agent in iteration mode):
  1. Read review document - extract 2 Critical, 3 Important issues
  2. Read receiving-code-review skill for principles
  3. Apply validated documentation updates
  4. Fix Critical: SQL injection, error handling
  5. Fix Important: Test coverage, N+1 query
  6. Re-run all quality checks - all passing
  7. Append response to review document

Edit(
  file_path="${REVIEW_BASE_DIR}/pending/review_customer_support_20250113_143022.md",
  old_string="## Review Agent Section\n\n(Review agent will append feedback below)",
  new_string="""## Review Agent Section

  [Review Round 1 feedback]

  ---

  ## Coding Agent Response

  ### Documentation Updates Applied
  ✅ app/workflows/CLAUDE.md

  ### Issues Addressed
  ✅ SQL injection fixed
  ✅ Error handling added
  ✅ Test coverage expanded
  ✅ N+1 query optimized

  ### Quality Check Results
  ✅ 24/24 tests passing

  ---
  ## Review Agent Section (Round 2)
  (Review agent will append next feedback)
  """
)

You: Fixes complete. Quality checks passing. Ready for re-review.
[Signal to coordinator]
```

## Integration with Worktree Workflow

**Coordinator-Driven:**
- Coordinator launches you with task and context
- You create review document when complete
- Coordinator routes to review agent
- You iterate based on feedback until approved

**Your Responsibilities:**
- Document what you built thoroughly
- Run all quality checks before signaling ready
- Apply validated documentation updates during iteration
- Re-run quality checks after every fix
- Append responses to review document

**Coordinator's Responsibilities:**
- Gather context before launching you
- Pass review document path between agents
- Handle iteration loop based on verdicts
- Move document to approved/ when done

## Red Flags

**Never:**
- Create review document without running tests
- Skip quality checks before signaling ready
- Apply documentation updates before validation
- Signal ready without re-running tests after fixes
- Ignore Critical issues
- Proceed with unfixed Important issues

**Always:**
- Run all quality checks (linting, type checking, tests)
- Document thoroughly in review document
- Apply validated docs during iteration
- Re-run all checks after addressing feedback
- Append responses to review document (don't create new)

## Success Indicators

You've successfully requested review when:
- ✅ Review document created in ${REVIEW_BASE_DIR}/pending/
- ✅ All quality checks passing
- ✅ Test results documented
- ✅ Documentation suggestions prepared (not applied)
- ✅ Git range clearly specified
- ✅ Coordinator signaled with document path

You've successfully handled feedback when:
- ✅ Validated documentation updates applied
- ✅ All issues addressed by priority
- ✅ Quality checks re-run and passing
- ✅ Response appended to review document
- ✅ Coordinator signaled ready for re-review

See review document structure examples in `.claude/agents/worktree-coding-agent.md`
