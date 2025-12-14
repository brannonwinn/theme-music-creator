# Detect Current Worktree

Detect which worktree you're currently in and display context information.

## Usage

No arguments needed. Run from any directory:

```bash
./.claude/commands/worktree/scripts/detect_worktree.sh
```

Or source it to export environment variables:

```bash
source <(./.claude/commands/worktree/scripts/detect_worktree.sh)
echo $WORKTREE_COLOR
```

## Output

The script exports these environment variables:

```bash
export WORKTREE_COLOR="blue"
export WORKTREE_PATH="/Users/user/${PROJECT_NAME}/worktrees/${PROJECT_NAME}_blue"
export WORKTREE_BRANCH="feature/task-3a-1-1"
export PROJECT_NAME="${PROJECT_NAME}"
export DATABASE_NAME="${PROJECT_NAME}_blue"
export AI_DOCS_DIR="ai_docs"           # From config (project.ai_docs_dir)
export REVIEW_BASE_DIR="ai_docs/reviews"  # ${AI_DOCS_DIR}/reviews
```

## Detection Logic

Worktree color is detected from the directory path:
- Path contains `_blue` → color is "blue"
- Path contains `_red` → color is "red"
- Path contains `_white` → color is "white"
- Otherwise → color is "main"

## When To Use

- In scripts that need to know current worktree context
- Verifying which worktree you're in
- Debugging path-based issues
- Integration with other tools

## Example Usage in Scripts

```bash
#!/bin/bash
# Auto-detect current worktree
source <(./.claude/commands/worktree/scripts/detect_worktree.sh)

echo "Working in $WORKTREE_COLOR worktree"
echo "Database: $DATABASE_NAME"
echo "Branch: $WORKTREE_BRANCH"
```
