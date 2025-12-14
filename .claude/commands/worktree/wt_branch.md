# Create Branch in Worktree

Create a feature branch in an existing worktree. This is how you start work on a new task after the worktree infrastructure is set up.

## What It Does

1. Validates worktree exists
2. Checks out the color branch (blue/red/white)
3. Syncs color branch with `main` (pulls latest changes with rebase)
4. Creates new feature branch from the updated color branch
5. Displays next steps

**Important**: This creates a feature branch from the color branch (which mirrors main). The feature branch will be merged directly to `main` via PR, NOT to the color branch.

## Usage

Ask the user for:
1. **Agent color** (blue, red, or white)
2. **Branch name** (e.g., `feature/task-3a-1-1`, `feat/user-auth`)

Validate inputs:
- Color must be one of: `blue`, `red`, `white`
- Branch name should be provided

Then run:

```bash
./.claude/commands/worktree/scripts/create_branch.sh ${COLOR} ${BRANCH_NAME}
```

## Example Interaction

```
Assistant: I'll create a new branch in the blue worktree. What's the branch name?
User: feature/task-3a-1-1
Assistant: Creating branch 'feature/task-3a-1-1' in blue worktree...

[runs script]

✅ Branch 'feature/task-3a-1-1' created successfully

Worktree: ${PROJECT_NAME}_blue
Branch: feature/task-3a-1-1
Path: /path/to/${PROJECT_NAME}_blue

Service URLs:
  Backend:  http://localhost:6799
  Frontend: http://localhost:3010

Next steps:
  1. cd worktrees/${PROJECT_NAME}_blue
  2. Start coding
  3. When done:
     git push origin feature/task-3a-1-1
     Create PR: feature/task-3a-1-1 → main
```

## Verbose Mode

For detailed output, add `--verbose`:

```bash
./.claude/commands/worktree/scripts/create_branch.sh ${COLOR} ${BRANCH_NAME} --verbose
```

## Error Handling

- **Worktree doesn't exist**: User needs to create it first with `/worktree:wt_create`
- **Branch already exists**: User should check existing branches or choose different name
- **Failed to pull main**: Check network connection or merge conflicts

## Important Notes

- Always syncs color branch (blue/red/white) with latest `main` before creating feature branch
- Feature branch is created from the color branch, which mirrors main
- **Feature branches merge to `main`, NOT to the color branch**
- After merging a feature branch to main, sync the color branch with `/worktree:wt_sync`
- Stashes uncommitted changes if present
- Services remain running (no restart needed)
- Database and dependencies are preserved

## Branch Workflow Reminder

```
Color Branch (blue) ← synced with main
    ↓
Feature Branch (feature/add-endpoint) ── PR ──→ main ✓ merged
                                                  ↓
                                        Color Branch resyncs
```
