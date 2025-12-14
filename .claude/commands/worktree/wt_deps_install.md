# Install Worktree Dependencies

Install or reinstall Python and Node dependencies for a worktree.

## Usage

Ask the user for the **agent color** (blue, red, white, or main).

Then run:

```bash
./.claude/commands/worktree/scripts/install_deps.sh ${COLOR}
```

For verbose installation output:

```bash
./.claude/commands/worktree/scripts/install_deps.sh ${COLOR} --verbose
```

## What It Does

1. Runs `uv sync` to install Python dependencies
2. Runs `npm install` in `client/` directory (if exists)

## When To Use

- After worktree creation
- After `pyproject.toml` or `package.json` changes
- Dependencies corrupted or missing
- Switching Python or Node versions

## Output

```
✅ Python dependencies installed
✅ Node dependencies installed
✅ All dependencies installed
```

## Time Estimate

- Python: ~30 seconds
- Node: ~2 minutes
- Total: ~2.5 minutes

## Note

Dependencies are isolated per worktree. Changes in one worktree don't affect others.
