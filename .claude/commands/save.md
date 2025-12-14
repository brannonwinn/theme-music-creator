---
allowed-tools: Bash, Read
description: Intelligent git assistant for creating atomic commits with conventional commit messages
---

# Save - Smart Git Commits

You are an expert git assistant that creates clean, atomic, local commits. Analyze all changes holistically and group them into logical commits with conventional commit messages.

## Workflow

### 1. Analyze All Changes

- Run `git status --porcelain` to check for changes
- If working directory is clean, report and exit
- Categorize into: modified files, staged files, and untracked files
- Analyze untracked files for common patterns that should be ignored (*.log, build/, dist/, .DS_Store, .vscode/, node_modules/, etc.)
- If .gitignore candidates found, propose adding patterns to .gitignore
  - If user approves, update .gitignore (will be first commit)
  - If user declines, treat as files to commit

### 2. Group Changes Intelligently

Run `git diff HEAD` and analyze all changes. Group into logical, atomic commits following these patterns:

**Grouping Strategy:**
- .gitignore updates: `chore: update .gitignore`
- Dependency changes (package.json, go.mod, pyproject.toml, uv.lock): `chore: update dependencies`
- Documentation (.md, .txt): `docs: <description>`
- Related code for single feature/fix: `feat:` or `fix:` + description
- Formatting/linting: `style: <description>`
- Configuration (.toml, .yaml, .env.example): `chore: update config`
- Tests related to specific feature: group with that feature

**Commit Message Format:**
- Use Conventional Commits: `type: description`
- Types: feat, fix, docs, chore, style, refactor, test
- Keep descriptions concise and clear

### 3. Present Plan & Execute

- Show complete plan: for each commit, display the message and files included
- Ask: "Do you want to proceed with this plan?"
- Only proceed after user confirmation
- For each approved commit:
  - Stage specific files: `git add <files>`
  - Commit: `git commit -m "<message>"`
- After all commits, run `git status` to verify clean state
- Show final summary: `git log --oneline -n <count>` for commits created

## Important Notes

- This command only works with local commits (never push to remote)
- All git commits will follow Claude Code's built-in safety protocols
- Pre-commit hooks are respected unless user explicitly requests bypass
- If working directory is clean, simply report "No changes to commit" and exit
