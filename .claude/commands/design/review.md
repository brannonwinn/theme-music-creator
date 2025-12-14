---
allowed-tools: Grep, LS, Read, Edit, MultiEdit, Write, NotebookEdit, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, ListMcpResourcesTool, ReadMcpResourceTool, mcp__context7__resolve-library-id, mcp__context7__get-library-docs, mcp__chrome-devtools__click, mcp__chrome-devtools__close_page, mcp__chrome-devtools__drag, mcp__chrome-devtools__emulate, mcp__chrome-devtools__evaluate_script, mcp__chrome-devtools__fill, mcp__chrome-devtools__fill_form, mcp__chrome-devtools__get_console_message, mcp__chrome-devtools__get_network_request, mcp__chrome-devtools__handle_dialog, mcp__chrome-devtools__hover, mcp__chrome-devtools__list_console_messages, mcp__chrome-devtools__list_network_requests, mcp__chrome-devtools__list_pages, mcp__chrome-devtools__navigate_page, mcp__chrome-devtools__new_page, mcp__chrome-devtools__performance_analyze_insight, mcp__chrome-devtools__performance_start_trace, mcp__chrome-devtools__performance_stop_trace, mcp__chrome-devtools__press_key, mcp__chrome-devtools__resize_page, mcp__chrome-devtools__select_page, mcp__chrome-devtools__take_screenshot, mcp__chrome-devtools__take_snapshot, mcp__chrome-devtools__upload_file, mcp__chrome-devtools__wait_for, Bash, Glob
description: Complete a design review of the pending changes on the current branch
---

# Design Review Command

**Purpose**: Create a comprehensive design review document for frontend changes that can be used by:
1. **Direct invocation**: User requests design review via `/design/review`
2. **Coordinator invocation**: Coordinator routes work to design review agent

This command can be used for:
- Pull request reviews
- Feature implementation reviews
- UI/UX quality checks
- Accessibility audits
- Visual design validation

---

## Step 1: Detect Environment Context

```bash
# Detect current worktree color
WORKTREE_DIR=$(basename $(pwd))
WORKTREE_COLOR=$(echo $WORKTREE_DIR | grep -oE "(blue|red|white|green|alpha)" || echo "main")

# Detect default remote branch dynamically
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@' || echo "main")

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# Get git SHAs for diff range
BASE_SHA=$(git merge-base origin/$DEFAULT_BRANCH HEAD)
HEAD_SHA=$(git rev-parse HEAD)

# Detect frontend port based on worktree config
case "$WORKTREE_COLOR" in
  "blue")  FRONTEND_PORT=3010 ;;
  "red")   FRONTEND_PORT=3020 ;;
  "white") FRONTEND_PORT=3030 ;;
  "main")  FRONTEND_PORT=3000 ;;
  *)       FRONTEND_PORT=3000 ;;
esac

PREVIEW_URL="http://localhost:$FRONTEND_PORT"
```

**Environment detected:**
```
!`WORKTREE_DIR=$(basename $(pwd)); WORKTREE_COLOR=$(echo $WORKTREE_DIR | grep -oE "(blue|red|white|green|alpha)" || echo "main"); DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@' || echo "main"); CURRENT_BRANCH=$(git branch --show-current); BASE_SHA=$(git merge-base origin/$DEFAULT_BRANCH HEAD); HEAD_SHA=$(git rev-parse HEAD); case "$WORKTREE_COLOR" in "blue") FRONTEND_PORT=3010 ;; "red") FRONTEND_PORT=3020 ;; "white") FRONTEND_PORT=3030 ;; "main") FRONTEND_PORT=3000 ;; *) FRONTEND_PORT=3000 ;; esac; echo "Worktree: $WORKTREE_COLOR"; echo "Default Branch: $DEFAULT_BRANCH"; echo "Current Branch: $CURRENT_BRANCH"; echo "Base SHA: $BASE_SHA"; echo "Head SHA: $HEAD_SHA"; echo "Preview URL: http://localhost:$FRONTEND_PORT"`
```

---

## Step 2: Capture Git Changes

**Git Status:**
```
!`git status`
```

**Files Modified:**
```
!`git diff --name-only $(git merge-base origin/$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@' || echo "main") HEAD)...HEAD`
```

**Commits:**
```
!`git log --no-decorate $(git merge-base origin/$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@' || echo "main") HEAD)..HEAD`
```

**Diff Summary:**
```
!`git diff --stat $(git merge-base origin/$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@' || echo "main") HEAD)...HEAD`
```

---

## Step 3: Your Task

**Read the design review template:**
```
Read file: .claude/commands/design/design-review-template.md
```

**Create review document** in `${REVIEW_BASE_DIR}/pending/` (default: `ai_docs/reviews/pending/`) using this naming pattern:
- `design_review_{branch_name}_{timestamp}.md`
- Example: `design_review_feat-dark-mode_20250123_143022.md`

**Populate template variables:**
- `{CHANGE_DESCRIPTION}`: Brief summary of what changed (e.g., "Dark Mode Implementation")
- `{ISO_TIMESTAMP}`: Current timestamp in ISO format
- `{WORKTREE_COLOR}`: Detected worktree color (blue/red/white/main)
- `{BRANCH_NAME}`: Current git branch name
- `{PREVIEW_URL}`: Preview environment URL (http://localhost:{port})
- `{BASE_SHA}`: Git base SHA for diff range
- `{HEAD_SHA}`: Git head SHA for current changes
- `{WHAT_CHANGED_DESCRIPTION}`: Detailed description of changes from git log/diff

**Launch design-review agent** with the created document path and preview URL.

**Note**: The design-review agent will automatically search for design documentation:
- `design_principles.md` - Strategic design philosophy
- `style_guide.md` - Tactical specifications (colors, typography, components)

The agent will check default locations and search the project if not found.

---

## Step 4: Design Review Agent Execution

The design-review agent will:

1. **Read review document** to understand scope and context
2. **Navigate to preview URL** using Chrome DevTools MCP
3. **Execute 7-phase review process**:
   - Phase 0: Preparation (navigate, set viewport, capture initial state)
   - Phase 1: Interaction & User Flow
   - Phase 2: Responsiveness Testing (3 viewports)
   - Phase 3: Visual Polish
   - Phase 4: Accessibility (WCAG 2.1 AA)
   - Phase 5: Robustness Testing
   - Phase 6: Code Health
   - Phase 7: Content & Console
4. **Check compliance** with design principles and style guide
5. **Append detailed findings** to review document

---

## Step 5: Final Output

**After design-review agent completes:**

1. **Signal completion** to user or coordinator:
   ```
   Design review complete.

   Review document: ${REVIEW_BASE_DIR}/pending/design_review_{branch}_{timestamp}.md

   Quality Score: [Excellent/Good/Needs Work/Critical Issues]
   Critical Issues: [count]
   High-Priority Issues: [count]

   Ready for action.
   ```

2. **Next steps**:
   - If invoked by **user**: Present findings and ask if they want to address issues
   - If invoked by **coordinator**: Coordinator will route to coding agent for fixes or approve

---

## Important Notes

**This command supports two invocation patterns:**

1. **Direct user invocation**: `/design/review`
   - User asks for design review
   - Command creates review document
   - Launches design-review agent
   - Returns findings to user

2. **Coordinator invocation**: Coordinator includes this in workflow
   - Coordinator requests design review as part of PR process
   - Command creates review document
   - Launches design-review agent
   - Returns document path to coordinator for routing

**Preview environment requirements:**
- Next.js dev server must be running on detected port
- If not running, command should notify user/coordinator

**File path references:**
- Design principles: Automatically detected by design-review agent
- Style guide: Automatically detected by design-review agent
- Review template: `.claude/commands/design/design-review-template.md`
- Review output: `${REVIEW_BASE_DIR}/pending/design_review_{branch}_{timestamp}.md`
