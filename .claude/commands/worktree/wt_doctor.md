# Worktree System Doctor

Comprehensive diagnostic tool that checks the health of your worktree system, including dependencies, configuration, infrastructure, port availability, and project structure.

## What It Checks

### Core Dependencies
- ✅ Git installation and version
- ✅ yq installation (for YAML configs)
- ✅ Docker installation and daemon status

### Configuration
- ✅ Config file exists
- ✅ Config format (YAML/JSON)
- ✅ Configuration validation (runs validate_config.sh)

### Database & Infrastructure
- ✅ Supabase container running
- ✅ Container status

### Port Availability
- ✅ Checks all configured ports (main + agents)
- ✅ Identifies port conflicts
- ✅ Shows which process is using each port

### Git Worktrees
- ✅ Total worktree count
- ✅ Worktree locations
- ✅ Status of configured agents

### Project Dependencies
- ✅ Python/uv environment
- ✅ Node.js/npm environment

### Project Structure
- ✅ Backend directory detection
- ✅ Frontend directory detection

## Usage

### Basic Diagnostic

```bash
./.claude/commands/worktree/scripts/doctor.sh
```

### Verbose Output

Shows detailed information for each check:

```bash
./.claude/commands/worktree/scripts/doctor.sh --verbose
```

### Auto-Fix Mode

Attempts to automatically fix some issues (e.g., install yq, create config from example):

```bash
./.claude/commands/worktree/scripts/doctor.sh --fix
```

## Example Output

```
╔════════════════════════════════════════════════════════════╗
║                 Worktree System Doctor                    ║
╚════════════════════════════════════════════════════════════╝

Running diagnostics...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Core Dependencies
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Checking: Git installation
  ✅ Git installed: v2.51.0
Checking: yq installation
  ✅ yq installed: v4.48.2 at /opt/homebrew/bin/yq
Checking: Docker installation
  ✅ Docker installed: v28.4.0
  ✅ Docker daemon is running

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Checking: Configuration file
  ✅ Config file exists: worktree.config.yaml
Checking: Configuration validation
  ✅ Configuration is valid

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Database & Infrastructure
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Checking: Supabase container
  ✅ Supabase container running: supabase-shared-db
  ✅ Container status: running

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Port Availability
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Checking: Port conflicts
  ⚠️  Some ports are in use (this is normal if services are running)
  ℹ️  To free ports: ./.claude/commands/worktree/scripts/stop_worktree.sh <agent>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Git Worktrees
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Checking: Git worktree list
  ✅ Total worktrees: 4

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Project Dependencies
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Checking: Python environment (uv)
  ✅ uv installed: v0.8.13
Checking: Node.js environment
  ✅ Node.js installed: v24.10.0
  ✅ npm installed: v11.6.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Project Structure
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Checking: Backend directory
  ✅ Backend found: app
Checking: Frontend directory
  ✅ Frontend found: frontend

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Diagnostic Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total checks: 15
Passed: 14
Warnings: 1
Failed: 0

✅ System is healthy!

Your worktree system is ready to use.
Some warnings were found, but they won't prevent normal operation.
```

## Common Issues and Fixes

### Docker Not Running

```
❌ Docker daemon is not running
ℹ️  Start Docker Desktop or run: sudo systemctl start docker
```

**Fix**: Start Docker Desktop application

### yq Not Installed

```
❌ yq not found (required for YAML config)
ℹ️  Install: brew install yq
```

**Fix**: Install yq (or run with `--fix` flag)
```bash
./.claude/commands/worktree/scripts/doctor.sh --fix
```

### Supabase Container Not Found

```
❌ Supabase container not found
ℹ️  Start Supabase: cd docker && ./start.sh
```

**Fix**: Start Supabase services
```bash
cd docker && ./start.sh
```

### Configuration File Missing

```
❌ Config file not found: worktree.config.yaml
ℹ️  Create from example: cp worktree.config.example.yaml worktree.config.yaml
```

**Fix**: Create config from example (or run with `--fix` flag)
```bash
cp .claude/commands/worktree/worktree.config.example.yaml \
   .claude/commands/worktree/worktree.config.yaml
```

### Port Conflicts

```
⚠️  Some ports are in use (this is normal if services are running)
ℹ️  To free ports: ./.claude/commands/worktree/scripts/stop_worktree.sh <agent>
```

**When It's OK**: This warning is normal if you have worktrees running

**When to Fix**: If you're getting "port already in use" errors when creating worktrees:
```bash
# Stop all worktrees
./.claude/commands/worktree/scripts/stop_worktree.sh blue
./.claude/commands/worktree/scripts/stop_worktree.sh red
./.claude/commands/worktree/scripts/stop_worktree.sh white
```

## When to Run

✅ **Before first use** - Verify system prerequisites
✅ **After installation** - Confirm everything is set up correctly
✅ **When troubleshooting** - Diagnose issues
✅ **After system updates** - Check compatibility
✅ **Regular health checks** - Periodic verification

## Diagnostic Categories

| Category | What It Checks | Critical? |
|----------|---------------|-----------|
| Core Dependencies | git, yq, docker | ✅ Required |
| Configuration | Config file and validation | ✅ Required |
| Database | Supabase container | ✅ Required |
| Ports | Port availability | ⚠️ Warning only |
| Worktrees | Git worktree status | ℹ️ Informational |
| Dependencies | Python, Node.js | ⚠️ Project-specific |
| Structure | Project directories | ℹ️ Auto-detected |

## Exit Codes

- **0**: All checks passed (warnings allowed)
- **1**: One or more checks failed (errors found)

## Verbose Mode Details

When running with `--verbose`, the doctor shows:
- Exact paths to installed binaries
- Port-by-port breakdown with process info
- Individual worktree paths
- Detailed version numbers
- Configuration format details

Example:
```bash
./.claude/commands/worktree/scripts/doctor.sh --verbose
```

Shows additional output like:
```
  Port 6789 (main-backend): Available ✓
  Port 3000 (main-frontend): In use by node (PID: 12345)
  Port 6799 (blue-backend): Available ✓
  ...
```

## Auto-Fix Capabilities

When run with `--fix`, the doctor can automatically:
- ✅ Install yq (via Homebrew)
- ✅ Create config from example template

It will NOT automatically:
- ❌ Start Docker (security concern)
- ❌ Kill processes on ports (data loss risk)
- ❌ Create worktrees (requires user intent)

## Related Commands

- `/worktree:wt_validate` - Validate configuration only
- `/worktree:wt_status` - Check specific agent status
- `/worktree:wt_health` - Health check for running services
- `/worktree:wt_ports` - View port allocations

## Best Practices

1. **Run before creating worktrees** - Catch issues early
2. **Use --verbose for debugging** - Get detailed diagnostic info
3. **Check regularly** - Especially after system updates
4. **Address failures first** - Warnings can often be ignored
5. **Use --fix for quick setup** - Automates common fixes

## Notes

- Non-destructive (read-only except with `--fix`)
- Works from both main project and worktrees
- Uses auto-detection functions from common.sh
- Safe to run multiple times
- Exit code indicates overall health
