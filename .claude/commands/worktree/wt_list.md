# List All Worktrees

Display status of all worktrees including services, database, and git status.

## Usage

Simply run:

```bash
./.claude/commands/worktree/scripts/list_worktrees.sh
```

For verbose output:

```bash
./.claude/commands/worktree/scripts/list_worktrees.sh --verbose
```

## Output Example

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Git Worktrees Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏠 MAIN ${PROJECT_NAME}
   Branch: main
   Path: /Users/user/${PROJECT_NAME}
   Services: ✅ FastAPI (6789) ✅ Celery ✅ Next.js (3000)
   Database: ✅ ${PROJECT_NAME}
   Git: Clean, up-to-date

🔵 BLUE ${PROJECT_NAME}_blue
   Branch: feature/task-3a-1-1
   Path: /Users/user/${PROJECT_NAME}/worktrees/${PROJECT_NAME}_blue
   Services: ✅ FastAPI (6799) ✅ Celery ✅ Next.js (3010)
   Database: ✅ ${PROJECT_NAME}_blue
   Git: ↑2 commits ahead of main, 3 uncommitted

🔴 RED ${PROJECT_NAME}_red
   Branch: red
   Path: /Users/user/${PROJECT_NAME}/worktrees/${PROJECT_NAME}_red
   Services: ❌ FastAPI ❌ Celery ❌ Next.js
   Database: ✅ ${PROJECT_NAME}_red
   Git: Clean, up-to-date

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total worktrees: 3
```

## No Arguments Needed

This command requires no user input - just displays all worktrees automatically.
