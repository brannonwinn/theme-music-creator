---
name: chrome-devtools-multiagent
description: Use when performing UI testing with Chrome DevTools MCP in a multi-agent worktree environment - ensures proper Chrome instance isolation to prevent cross-contamination between agents
---

# Chrome DevTools Multi-Agent Usage

When using Chrome DevTools MCP for UI testing in a worktree environment, you **MUST** manage Chrome browser instances carefully. This prevents:
- Multiple agents from accidentally controlling each other's browser sessions
- Zombie Chrome processes from accumulating and consuming system resources

## Why This Matters

Each worktree has a unique Chrome debug port configured in `.mcp.json`:

| Agent | Frontend Port | Chrome Debug Port |
|-------|--------------|-------------------|
| blue  | 3010         | 9226              |
| red   | 3020         | 9223              |
| white | 3030         | 9224              |
| green | 3040         | 9225              |

If two agents try to connect to the same Chrome debug port:
- One agent may control the other's browser
- UI tests will produce incorrect results
- Actions may affect the wrong application

**Resource Warning**: Chrome instances that are never cleaned up will accumulate and slow down the machine significantly.

## Isolated Mode (Recommended)

Your worktree's `.mcp.json` should be configured with the `--isolated` flag:

```json
"chrome-devtools": {
  "command": "npx",
  "args": [
    "-y",
    "chrome-devtools-mcp@latest",
    "--browserUrl=http://127.0.0.1:9226",
    "--isolated"
  ]
}
```

The port is specified directly in `--browserUrl`. No environment variable needed.

**What `--isolated` does:**
- Creates a temporary browser profile for each session
- Profile is automatically cleaned up when the session ends
- Prevents accumulation of zombie Chrome processes and profiles
- Ensures your automation doesn't interfere with personal browser data

If your `.mcp.json` doesn't have `--isolated`, regenerate it:
```bash
./.claude/commands/worktree/scripts/generate_mcp_json.sh {COLOR} {WORKTREE_PATH}
```

## Before Using Chrome DevTools

### 1. Verify Your Debug Port

Check your worktree's `.mcp.json` to confirm your Chrome debug port:

```bash
cat .mcp.json | grep -A2 "chrome-devtools"
```

Look for the `--browser-url` argument, e.g., `http://127.0.0.1:9226`

### 2. Check for Existing Instance FIRST

**CRITICAL**: Before launching a new Chrome instance, check if one is already running on your port:

```bash
# Check if Chrome is already listening on your debug port
curl -s http://127.0.0.1:9226/json/version
```

**If you get a JSON response**: Chrome is already running! You can reuse it.

**If you get "Connection refused"**: No instance exists, proceed to launch one.

You can also check for processes:

```bash
# Find Chrome processes with your debug port
ps aux | grep -E "remote-debugging-port=9226" | grep -v grep
```

### 3. Launch Chrome ONLY If Needed

**Only launch a new instance if Step 2 confirmed no existing instance.**

**macOS:**
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9226 \
  --user-data-dir=/tmp/chrome-worktree-blue &
```

**Linux:**
```bash
google-chrome \
  --remote-debugging-port=9226 \
  --user-data-dir=/tmp/chrome-worktree-blue &
```

**Important flags:**
- `--remote-debugging-port`: Must match your `.mcp.json` config
- `--user-data-dir`: Use a unique temp directory per worktree to isolate sessions
- `&`: Run in background so terminal isn't blocked

### 4. Verify Chrome is Ready

Before using any Chrome DevTools MCP tools, verify the browser is accessible:

```bash
curl -s http://127.0.0.1:9226/json/version
```

You should see JSON output with Chrome version information.

## Using Chrome DevTools MCP

### Safe Workflow

1. **Check for existing pages:**
   ```
   mcp__chrome-devtools__list_pages
   ```

2. **Create a new page for your tests:**
   ```
   mcp__chrome-devtools__new_page with url="http://localhost:3010"
   ```
   (Use YOUR worktree's frontend port)

3. **Select your page before interacting:**
   ```
   mcp__chrome-devtools__select_page with pageIdx=0
   ```

4. **Take snapshots before actions:**
   ```
   mcp__chrome-devtools__take_snapshot
   ```

### Port Reference by Worktree

| Worktree | Navigate To | Chrome Debug Port |
|----------|-------------|-------------------|
| blue     | `http://localhost:3010` | 9226 |
| red      | `http://localhost:3020` | 9223 |
| white    | `http://localhost:3030` | 9224 |
| green    | `http://localhost:3040` | 9225 |

## Common Issues

### "Cannot connect to Chrome"

1. Verify Chrome is running with the correct debug port
2. Check no other process is using the port: `lsof -i :9226`
3. Restart Chrome with the correct flags

### "Actions affecting wrong app"

You may be connected to another agent's Chrome instance:
1. Close all Chrome windows
2. Launch a fresh instance with YOUR debug port
3. Verify with `curl http://127.0.0.1:{YOUR_PORT}/json/version`

### "Multiple Chrome windows open"

Each Chrome instance needs a unique `--user-data-dir`. Use:
```bash
--user-data-dir=/tmp/chrome-worktree-{YOUR_COLOR}
```

## Multi-Agent Coordination

When multiple agents are working in parallel:

1. **Each agent launches its own Chrome** with unique debug port
2. **Each agent uses its own frontend port** (3010, 3020, 3030, etc.)
3. **Never share Chrome windows** between agents
4. **Close Chrome when done** to free the debug port

## Quick Reference

**Blue Agent:**
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9226 \
  --user-data-dir=/tmp/chrome-worktree-blue
```
Navigate to: `http://localhost:3010`

**Red Agent:**
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9223 \
  --user-data-dir=/tmp/chrome-worktree-red
```
Navigate to: `http://localhost:3020`

**White Agent:**
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9224 \
  --user-data-dir=/tmp/chrome-worktree-white
```
Navigate to: `http://localhost:3030`

## Checklist Before UI Testing

- [ ] Verified my worktree's Chrome debug port in `.mcp.json`
- [ ] Checked if Chrome instance already exists on my port (reuse if so)
- [ ] Only launched new instance if none exists
- [ ] Used unique `--user-data-dir` for session isolation
- [ ] Verified Chrome is accessible with `curl` to debug port
- [ ] Navigating to MY worktree's frontend port (not another agent's)

---

## CLEANUP: When Testing is Complete

**CRITICAL**: When you finish UI testing, you **MUST** clean up Chrome instances to prevent resource exhaustion.

### 1. Ask Before Shutting Down

Before killing Chrome, ask the user or your coordinator:

> "UI testing is complete. Should I shut down the Chrome instance on port {YOUR_PORT}?
> (Keeping it running allows faster subsequent tests, but consumes system resources)"

**If they say yes** (or you're explicitly told testing is done): Proceed to cleanup.

**If they say no** (or want to keep it for more testing): Leave it running but note it in your response.

### 2. How to Clean Up Chrome

**Option A: Graceful shutdown via MCP (preferred)**

Close all pages first:
```
mcp__chrome-devtools__list_pages
mcp__chrome-devtools__close_page (for each page except the last)
```

**Option B: Kill the process directly**

Find and kill Chrome processes on your debug port:

```bash
# Find the PID of Chrome with your debug port
CHROME_PID=$(ps aux | grep -E "remote-debugging-port=9226" | grep -v grep | awk '{print $2}' | head -1)

# Kill it gracefully
if [ -n "$CHROME_PID" ]; then
  kill $CHROME_PID
  echo "Killed Chrome process $CHROME_PID"
else
  echo "No Chrome process found on port 9226"
fi
```

**Option C: Kill all Chrome instances for your worktree**

```bash
# Kill all Chrome processes using your worktree's user-data-dir
pkill -f "user-data-dir=/tmp/chrome-worktree-blue"
```

### 3. Verify Cleanup

After cleanup, verify Chrome is no longer running:

```bash
# Should return "Connection refused"
curl -s http://127.0.0.1:9226/json/version

# Should return nothing
ps aux | grep -E "remote-debugging-port=9226" | grep -v grep
```

### 4. Clean Up Temp Directory (Optional)

If you want a completely fresh state next time:

```bash
rm -rf /tmp/chrome-worktree-blue
```

---

## Complete Workflow Example

```bash
# 1. Check your port
MY_PORT=9226  # From .mcp.json

# 2. Check for existing instance
if curl -s http://127.0.0.1:$MY_PORT/json/version > /dev/null 2>&1; then
  echo "Chrome already running on port $MY_PORT - reusing"
else
  echo "Launching new Chrome instance..."
  /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --remote-debugging-port=$MY_PORT \
    --user-data-dir=/tmp/chrome-worktree-blue &
  sleep 2  # Wait for Chrome to start
fi

# 3. Do your UI testing...
# (use mcp__chrome-devtools__* tools)

# 4. When done - ASK user/coordinator if you should clean up

# 5. If cleanup approved:
CHROME_PID=$(ps aux | grep -E "remote-debugging-port=$MY_PORT" | grep -v grep | awk '{print $2}' | head -1)
[ -n "$CHROME_PID" ] && kill $CHROME_PID && echo "Chrome cleaned up"
```

---

## Red Flags

**Never:**
- Launch a new Chrome instance without checking if one exists
- Use a debug port that doesn't match your `.mcp.json`
- Navigate to another agent's frontend port
- Leave Chrome running indefinitely without asking
- Kill Chrome instances on OTHER agents' ports

**Always:**
- Check for existing instance before launching
- Reuse existing instances when available
- Ask before shutting down Chrome
- Clean up when explicitly told testing is complete
- Only manage Chrome on YOUR assigned port
