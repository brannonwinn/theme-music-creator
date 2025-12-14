# Claude Code Hooks

This directory contains hooks that execute at various points during Claude Code operations.

## Environment Variables

### CLAUDE_PROJECT_ROOT

**Purpose**: Defines the root directory for all hook-generated files and logs.

**Default Behavior**: If not set, hooks will automatically detect the git repository root using `git rev-parse --show-toplevel`. If not in a git repository, falls back to the current working directory.

**When to Set**: You typically don't need to set this variable. It's automatically handled by the git root detection. However, you may want to set it explicitly if:
- You're working in a non-git directory
- You want to override the automatic detection
- You're running hooks in a CI/CD environment

**Example**:
```bash
export CLAUDE_PROJECT_ROOT=/path/to/your/project
```

### CLAUDE_HOOKS_LOG_DIR

**Purpose**: Defines the base directory for hook logs.

**Default Behavior**: Defaults to `{CLAUDE_PROJECT_ROOT}/logs`

**Example**:
```bash
export CLAUDE_HOOKS_LOG_DIR=/custom/log/path
```

## Directory Structure

All hook-generated files are stored relative to `CLAUDE_PROJECT_ROOT`:

```
{CLAUDE_PROJECT_ROOT}/
├── .claude/
│   └── data/
│       └── sessions/          # Session data and prompts
│           └── {session_id}.json
└── logs/                       # Hook execution logs
    ├── session_start.json
    ├── session_end.json
    ├── session_statistics.json
    └── user_prompt_submit.json
```

## Why This Matters

Previously, hooks used relative paths (e.g., `.claude/data/sessions`), which caused files to be created in different locations depending on the current working directory. This led to duplicate session directories when Claude Code switched contexts (e.g., working in `./backend`).

Now all paths are resolved relative to the project root, ensuring consistent file locations regardless of where hooks execute.

## Available Hooks

- `session_start.py` - Executes when a Claude Code session starts
- `session_end.py` - Executes when a Claude Code session ends
- `user_prompt_submit.py` - Executes when a user submits a prompt
- `pre_tool_use.py` - Executes before Claude uses a tool
- `post_tool_use.py` - Executes after Claude uses a tool
- `pre_compact.py` - Executes before conversation compaction
- Additional hooks for notifications, subagents, etc.

## Troubleshooting

### Duplicate Session Directories

If you see session data appearing in multiple locations (e.g., both `./.claude/data/sessions` and `./backend/.claude/data/sessions`), this indicates:

1. Hooks were executed with different working directories before the `CLAUDE_PROJECT_ROOT` fix
2. You may safely delete the duplicate directories after verifying the correct location has the latest data

### Hook Execution Errors

If hooks fail to execute:

1. Check that `uv` is installed and available in your PATH
2. Ensure Python 3.8+ is installed
3. Verify that required dependencies are available (see script headers)
4. Check hook logs in `{CLAUDE_PROJECT_ROOT}/logs/`
