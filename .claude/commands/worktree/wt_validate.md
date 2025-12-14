# Validate Worktree Configuration

Validates the worktree configuration file (`worktree.config.yaml` or `worktree_config.json`) for syntax errors, missing fields, port conflicts, and other common issues.

## What It Checks

### Configuration File
- ✅ File exists
- ✅ YAML/JSON syntax is valid
- ✅ Format detected (YAML recommended, JSON deprecated)

### Required Fields
- ✅ Project name defined
- ✅ Agents array populated
- ✅ Port configuration present (for YAML)

### .gitignore Entries
- ✅ .gitignore file exists
- ✅ Required entries present:
  - `worktrees/` - Prevents tracking worktree directories
  - `docker/docker-compose.celery.yml` - Prevents tracking generated Celery compose files
  - `docker/Dockerfile.celery` - Prevents tracking generated Celery Dockerfiles
- ⚠️ Warns if entries are missing (use `ensure_gitignore.sh` to fix)

### Each Agent
- ✅ Agent name is not empty
- ✅ Display name present (warns if missing)
- ✅ Backend port defined and in valid range (1024-65535)
- ✅ Frontend port defined and in valid range (1024-65535)
- ✅ Database name defined
- ✅ No duplicate ports across agents
- ✅ No duplicate database names
- ✅ Backend and frontend ports don't overlap

### Dependencies
- ✅ yq installed (for YAML configs)

## Usage

Run validation without arguments:

```bash
./.claude/commands/worktree/scripts/validate_config.sh
```

For verbose output:

```bash
./.claude/commands/worktree/scripts/validate_config.sh --verbose
```

## Example Output

### Successful Validation

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Worktree Configuration Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Configuration file exists: worktree.config.yaml
✅ Configuration format: YAML (recommended)
✅ yq installed: yq
✅ YAML syntax valid
✅ Project name: agent_observer
✅ Agents defined: 3 (blue, red, white)
✅ Base backend port: 6789
✅ Base frontend port: 3000

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Agent Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Validating agent: blue
Validating agent: red
Validating agent: white

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Validation Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Configuration is valid! No errors or warnings.

Your worktree configuration is ready to use.
```

### With Errors

```
❌ Missing required field: project.name
❌ Invalid backend_port: 99999 (must be 1024-65535)
❌ Duplicate backend_port: 6799
⚠️  Missing display_name (will use default)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Validation Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

❌ Configuration has 3 error(s) and 1 warning(s)

Fix the errors before using the worktree system.
```

## Common Issues and Fixes

### Issue: "yq not installed"
**Fix**: Install yq for YAML support
```bash
brew install yq
```

### Issue: "Invalid YAML syntax"
**Fix**: Check for:
- Incorrect indentation (use 2 spaces)
- Missing colons after keys
- Unquoted special characters

### Issue: "Duplicate backend_port"
**Fix**: Ensure each agent has unique port numbers
```yaml
agents:
  - name: blue
    backend_port: 6799  # Unique
  - name: red
    backend_port: 6809  # Different from blue
```

### Issue: "Invalid port range"
**Fix**: Use ports between 1024-65535
- Avoid ports below 1024 (system reserved)
- Common ranges: 3000-3999 (frontend), 6000-6999 (backend)

### Issue: "Missing display_name"
**Fix**: Add display_name to agent config (optional but recommended)
```yaml
agents:
  - name: blue
    display_name: Blue Agent  # Recommended
```

### Issue: "Missing required .gitignore entries"
**Fix**: Run the ensure_gitignore script to add them automatically
```bash
./.claude/commands/worktree/scripts/ensure_gitignore.sh
```
This script is idempotent and safe to run multiple times. It only adds missing entries.

## When to Run

✅ **Before creating worktrees** - Ensure config is valid
✅ **After editing config** - Verify changes are correct
✅ **When adding new agents** - Check for conflicts
✅ **Troubleshooting issues** - Identify configuration problems

## Related Commands

- `/worktree:wt_doctor` - Comprehensive system diagnostics
- `/worktree:wt_create` - Create a new worktree
- `/worktree:wt_ports` - View port allocations

## Notes

- Validation is non-destructive (read-only)
- Warnings won't prevent normal operation
- Errors must be fixed before creating worktrees
- The script sources `common.sh` for utility functions
