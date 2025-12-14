# Coordinate Command

**Purpose**: Launch the coordinator agent to orchestrate a complete development workflow using git worktrees with multi-agent coordination and mandatory code review. Also supports UI testing mode.

**Usage**:
- Development: `/worktree:wt_coordinate "Task description"`
- UI Testing: `/worktree:wt_coordinate --ui-test "path/to/test_file.md"`

**What it does**:

**Development Mode** (default):
1. Detects worktree context (blue/red/white)
2. Gathers project context using prime logic
3. Launches coding agent to implement WITH comprehensive tests (coding agent creates review document)
4. Extracts review document path from coding agent
5. Launches review agent to validate
6. Handles iteration if changes needed
7. Notifies you when approved and ready to merge

**UI Testing Mode** (`--ui-test`):
1. Detects worktree context
2. Reads chrome_debug_port from worktree.config.yaml
3. Launches Chrome with remote debugging (if not already running)
4. Launches ui-testing-agent to execute tests
5. Generates test report in test_results/pending/
6. Notifies you of results

**Examples**:
```
# Development task
/worktree:wt_coordinate "Implement customer support workflow with priority routing and SLA tracking"

# UI testing task
/worktree:wt_coordinate --ui-test "backend/ai_docs/epics/testing/01_authentication/auth_login_flows.md"
```

---

You are now invoking the **Worktree Coordinator Agent** to handle the following task using git worktrees.

## Task to Coordinate

**Task**: {{input}}

## Your Workflow

### Phase 0: Detect Task Mode

**Parse the input to determine if this is a UI test or development task:**

```python
# Check for --ui-test flag
task_input = "{{input}}"

if task_input.startswith("--ui-test"):
    MODE = "ui-test"
    # Extract the test file path (everything after --ui-test)
    TEST_FILE_PATH = task_input.replace("--ui-test", "").strip().strip('"').strip("'")
else:
    MODE = "development"
    TASK_DESCRIPTION = task_input
```

**If MODE is "ui-test"**, skip to **Phase UI-1: UI Testing Workflow** below.

**If MODE is "development"**, continue with Phase 1 (standard development workflow).

---

### Phase 1: Context Detection and Setup

**1. Detect Worktree Context**

Use the detect_worktree.sh script to determine current environment:

```bash
source <(./.claude/commands/worktree/scripts/detect_worktree.sh)
```

This provides:
- `$WORKTREE_COLOR` - blue/red/white/main
- `$WORKTREE_PATH` - Absolute path to worktree
- `$WORKTREE_BRANCH` - Current git branch
- `$PROJECT_NAME` - From .claude/.env
- `$DATABASE_NAME` - ${PROJECT_NAME}_${color}
- `$AI_DOCS_DIR` - AI documentation directory (from config)
- `$REVIEW_BASE_DIR` - ${AI_DOCS_DIR}/reviews

**2. Gather Project Context**

Use the prime logic to discover documentation:

```bash
# Find all CLAUDE.md files (patterns and conventions)
Glob(pattern="**/CLAUDE.md")

# Find core documentation
Glob(pattern="ai_docs/context/core_docs/*.md")
```

Identify documents for the coding agent to read based on task type.

**3. Record Base Commit**

```bash
BASE_SHA=$(git rev-parse HEAD)
```

This establishes the baseline for code review.

---

### Phase 2: Launch Coding Agent

**Launch the worktree-coding-agent** to implement the feature:

```python
Task(
    subagent_type="worktree-coding-agent",
    prompt=f"""
You are implementing a feature in a git worktree environment.

WORKTREE CONTEXT:
- Color: {WORKTREE_COLOR}
- Path: {WORKTREE_PATH}
- Branch: {WORKTREE_BRANCH}
- Database: {DATABASE_NAME}

TASK:
{task_description}

CONTEXT DOCUMENTS TO READ:
{list_of_claude_md_files}
{list_of_core_docs}

FOR FRONTEND WORK - ALSO READ:
- backend/ai_docs/context/core_docs/design_system_catalog.md (component inventory - use existing components, add any new components to this catalog)

WORKFLOW:
1. Read all context documents (CLAUDE.md files, PRD, ADD)
2. Read existing examples in directories you'll modify
3. Implement the feature (backend and/or frontend)
4. Write comprehensive tests following backend/tests/CLAUDE.md
5. Run tests until ALL pass
6. Run quality checks (linting, type checking)
7. Create review document using requesting-code-review skill
8. Signal completion with review document path

CRITICAL CONSTRAINTS:
- Implementation is NOT complete until tests are written and passing
- Follow patterns from existing code in same directories
- Use AuthorizationService for RLS authorization (per backend/CLAUDE.md)
- Suggest documentation updates but DO NOT apply them yet (review agent validates first)

REVIEW DOCUMENT PATH:
Save to: ${REVIEW_BASE_DIR}/pending/review_{task_slug}_{timestamp}.md

Use the requesting-code-review skill for document structure.

Signal completion with the exact path to the review document.
""",
    description=f"Implement: {task_description}"
)
```

**Monitor for completion signal** containing review document path.

---

### Phase 3: Detect Frontend Changes and Launch Design Review

**After coding agent completes, detect if frontend changes were made:**

```bash
# Check for frontend file changes
FRONTEND_CHANGED=$(git diff --name-only $BASE_SHA..HEAD | grep -E "^(frontend/|app/.*\.(tsx|ts|jsx|js|css)$|components/)" || echo "")

if [ -n "$FRONTEND_CHANGED" ]; then
  echo "Frontend changes detected. Design review required."
  REQUIRES_DESIGN_REVIEW=true
else
  echo "No frontend changes detected. Skipping design review."
  REQUIRES_DESIGN_REVIEW=false
fi
```

**If frontend changes detected, launch design review:**

```bash
# Use the design review slash command
/design:review
```

**What `/design:review` does:**
1. Creates design review document in `${REVIEW_BASE_DIR}/pending/`
2. Launches `design-review-agent` with Chrome DevTools
3. Validates against `design_principles.md`, `style_guide.md`, and `design_system_catalog.md`
4. Verifies implementations use documented components from `design_system_catalog.md`
5. Flags any undocumented custom components (must be added to catalog)
6. Appends findings to design review document
7. Returns document path and quality score

**Wait for design review completion.**

**Extract design review results:**
- Quality Score: Excellent/Good/Needs Work/Critical Issues
- Critical Issues count
- High-Priority Issues count
- Design review document path

**If Critical or High-Priority issues found:**
- Set `DESIGN_ISSUES_FOUND=true`
- Record design review document path

**If no issues or only Minor/Nitpicks:**
- Set `DESIGN_ISSUES_FOUND=false`
- Move design review document to approved directory
- Proceed to code review

---

### Phase 4: Launch Code Review Agent

**Extract code review document path** from coding agent response.

**Launch the worktree-review-agent** to validate code quality:

```python
Task(
    subagent_type="worktree-review-agent",
    prompt=f"""
You are reviewing code in a git worktree environment.

WORKTREE CONTEXT:
- Color: {WORKTREE_COLOR}
- Path: {WORKTREE_PATH}
- Branch: {WORKTREE_BRANCH}

REVIEW DOCUMENT:
{review_document_path}

ORIGINAL TASK:
{task_description}

GIT RANGE:
Base SHA: {BASE_SHA}
Head SHA: {git rev-parse HEAD}

REVIEW WORKFLOW:
1. Read the review document
2. Examine code changes: git diff {BASE_SHA}..HEAD
3. Read implementation files
4. Validate against project patterns (CLAUDE.md files)
5. Validate documentation suggestions for accuracy
6. Categorize issues:
   - Critical (blocking - security, correctness, data integrity)
   - Important (should fix - quality, maintainability)
   - Minor (nice to have - style, optimization)
7. Append feedback to review document
8. Provide clear verdict: "Yes" (approved) or "With fixes" (changes required) or "No" (rejected)

REVIEW CHECKLIST:
- Architecture follows patterns from CLAUDE.md files?
- Multi-tenant authorization (AuthorizationService) used correctly?
- Code style matches existing files in same directory?
- Tests comprehensive and following backend/tests/CLAUDE.md?
- Error handling present?
- Type safety (Pydantic models)?
- No secrets in code?
- Documentation suggestions accurate and helpful?

OUTPUT:
Append your review to the review document under "## Review Agent Section"

Include:
- Summary
- Strengths
- Issues (categorized as Critical/Important/Minor)
- Documentation Review (validate each suggestion)
- Verdict: "Yes" / "With fixes" / "No"

Use specific file:line references.
""",
    description=f"Review: {task_description}"
)
```

---

### Phase 5: Handle Review Results

**Read both review documents** (design review if exists, code review) to extract verdicts.

**Evaluate overall status:**

**CASE 1: Both Approved (or design review not required + code review approved)**

1. Update all review documents to "Approved"
2. Move to approved directory:
   ```bash
   # Move code review
   mv ${REVIEW_BASE_DIR}/pending/review_{task_slug}_{timestamp}.md \
      ${REVIEW_BASE_DIR}/approved/review_{task_slug}_{timestamp}.md

   # Move design review (if exists)
   if [ "$REQUIRES_DESIGN_REVIEW" = "true" ]; then
     mv ${REVIEW_BASE_DIR}/pending/design_review_{branch}_{timestamp}.md \
        ${REVIEW_BASE_DIR}/approved/design_review_{branch}_{timestamp}.md
   fi
   ```
3. Notify human (go to Phase 6)

**CASE 2: Design Issues or Code Issues Found**

**Determine issue priority:**
- If design review has Critical/High-Priority issues: `DESIGN_FIXES_NEEDED=true`
- If code review verdict is "With fixes": `CODE_FIXES_NEEDED=true`

**Relaunch coding agent with combined feedback:**

```python
Task(
    subagent_type="worktree-coding-agent",
    prompt=f"""
You are addressing review feedback in iteration {iteration_count}.

REVIEW DOCUMENTS WITH FEEDBACK:
{"- Design Review: " + design_review_path if REQUIRES_DESIGN_REVIEW else ""}
- Code Review: {code_review_path}

ORIGINAL TASK:
{task_description}

WORKFLOW:
1. Read ALL review documents carefully
2. Read the receiving-code-review skill for principles
3. Prioritize fixes:
   a. DESIGN ISSUES (if any):
      - Critical design issues (blocking UX/accessibility)
      - High-priority design issues (visual consistency, responsiveness)
      - Undocumented components (must be added to design_system_catalog.md)
      - Reference design_principles.md, style_guide.md, and design_system_catalog.md for corrections
   b. CODE ISSUES (if any):
      - Critical issues (security, correctness, data integrity)
      - Important issues (quality, maintainability)
4. Apply fixes systematically
5. If design changes made, test in browser at preview URL
6. Update or add tests as needed
7. Re-run ALL quality checks (linting, type checking, tests)
8. Append your response to review documents under "## Coding Agent Response"
9. Signal ready for re-review

CRITICAL REQUIREMENTS:
- Design issues take priority (user-facing)
- All tests must pass before signaling ready
- Document what you fixed and why
- If you disagree with feedback, explain with technical reasoning
- Re-run quality checks after fixes
- Test frontend changes in live preview environment

Signal completion when ready for re-review.
""",
    description=f"Fix issues: {task_description}"
)
```

3. After coding agent completes, go back to Phase 3 (re-detect frontend changes, re-review)
4. Repeat until all reviews approved

**If iteration count > 3:**
- Alert human that complexity may require intervention
- Provide review document for manual inspection

---

### Phase 6: Notify Human

When review is approved:

```
✅ Task completed and approved!

Task: {task_description}
Worktree: {WORKTREE_COLOR}
Branch: {WORKTREE_BRANCH}

REVIEW DOCUMENTS:
- Code Review: {approved_code_review_path}
{"- Design Review: " + approved_design_review_path if REQUIRES_DESIGN_REVIEW else ""}

To view changes:
  cd {WORKTREE_PATH}
  git diff main..HEAD

To see commits:
  git log main..HEAD --oneline

To read reviews:
  cat {approved_code_review_path}
{"  cat " + approved_design_review_path if REQUIRES_DESIGN_REVIEW else ""}

{"Frontend changes validated against design principles and style guide." if REQUIRES_DESIGN_REVIEW else ""}
Backend/code quality approved by review agent.
All tests are passing.

Ready for your final review and merge decision.

Next steps:
1. Review the changes using commands above
2. If satisfied:
   - cd ../{PROJECT_NAME}  (switch to main)
   - git merge {WORKTREE_BRANCH}
   - git push origin main
3. If changes needed: Let me know what to adjust
4. Optionally keep worktree for next task or delete it
```

---

## Critical Requirements

1. **Must run from worktree directory** - Context detection relies on path
2. **Git state should be clean** - Or at least committed work
3. **Database must be set up** - Each worktree has own database
4. **All work in worktree** - Coding agents use Read/Write/Edit/Bash tools normally
5. **Review document is single source of truth** - Evolves through iterations
6. **Documentation validation required** - Review agent must approve doc updates before applying
7. **Tests are mandatory** - Implementation incomplete without passing tests

## Success Criteria

- ✅ Worktree context detected correctly
- ✅ Coding agent implements feature WITH tests
- ✅ All tests passing before review
- ✅ Frontend changes detected automatically
- ✅ Design review performed (if frontend changes) using design_principles.md, style_guide.md, and design_system_catalog.md
- ✅ Component usage validated against design_system_catalog.md
- ✅ Any new components documented in design_system_catalog.md
- ✅ Code review validates code and tests
- ✅ Documentation updates validated before applying
- ✅ All review documents saved to appropriate directory
- ✅ Human notified with clear commands
- ✅ All work traceable via git and review documents

## Error Handling

**If context detection fails:**
- Verify running from worktree directory (not main)
- Check .claude/.env has PROJECT_NAME defined
- Suggest using /worktree:wt_detect to debug

**If coding agent fails:**
- Save partial work
- Ask human if should retry with clarification

**If review agent fails:**
- Human can do manual review using review document
- Provide git commands for inspection

**If stuck in iteration loop (>3 rounds):**
- Alert human
- Provide review document path
- Suggest breaking into smaller tasks or manual intervention

Begin coordinating this task now.

---

# UI TESTING WORKFLOW

**This section applies when `--ui-test` flag is detected in Phase 0.**

---

### Phase UI-1: Context Detection for UI Testing

**1. Detect Worktree Context**

Use the detect_worktree.sh script to determine current environment:

```bash
source <(./.claude/commands/worktree/scripts/detect_worktree.sh)
```

This provides:
- `$WORKTREE_COLOR` - blue/red/white/main
- `$WORKTREE_PATH` - Absolute path to worktree

**2. Read Chrome Debug Port from worktree.config.yaml**

```bash
# Read the worktree config to get chrome_debug_port for this worktree color
Read(file_path=".claude/commands/worktree/worktree.config.yaml")

# Extract chrome_debug_port for the current worktree color
# Example: If WORKTREE_COLOR=blue, find the blue agent's chrome_debug_port (9222)
# If WORKTREE_COLOR=red, find the red agent's chrome_debug_port (9223)
# If WORKTREE_COLOR=white, find the white agent's chrome_debug_port (9224)
```

Parse the YAML to extract:
- `CHROME_DEBUG_PORT` - The port for this worktree's Chrome instance
- `CHROME_USER_DATA_DIR` - From testing.chrome_user_data_template, substituting {worktree_name}
- `TEST_RESULTS_DIR` - From testing.results_dir

**3. Read Testing Config**

```bash
# Read the testing config for profile information
Read(file_path="backend/ai_docs/epics/testing/hosthero.test.config.yaml")
```

Extract the frontend_url and backend_url for the environment.

---

### Phase UI-2: Ensure Chrome is Running

**CRITICAL: Read the Chrome DevTools Multi-Agent Skill First**

Before launching or managing Chrome instances, read the skill documentation:

```bash
Read(file_path=".claude/skills/chrome-devtools-multiagent/SKILL.md")
```

This skill teaches:
- How to check for existing Chrome instances (reuse, don't spawn duplicates)
- How to launch Chrome with `--isolated` flag for automatic cleanup
- How to clean up Chrome instances when testing is complete
- Port assignments per worktree to prevent agent conflicts

**1. Check if Chrome is already running on the debug port:**

```bash
# Check if Chrome DevTools is accessible
curl -s http://127.0.0.1:${CHROME_DEBUG_PORT}/json/version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Chrome already running on port ${CHROME_DEBUG_PORT} - reusing existing instance"
    CHROME_RUNNING=true
else
    echo "Chrome not running on port ${CHROME_DEBUG_PORT}"
    CHROME_RUNNING=false
fi
```

**2. If Chrome is not running, launch it (with --isolated for auto-cleanup):**

```bash
if [ "$CHROME_RUNNING" = "false" ]; then
    # Launch Chrome with remote debugging and --isolated for auto-cleanup
    # Note: The MCP config already has --isolated, but manual launch needs it too
    /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
        --remote-debugging-port=${CHROME_DEBUG_PORT} \
        --user-data-dir=/tmp/chrome-worktree-${WORKTREE_COLOR} \
        --no-first-run \
        --no-default-browser-check &

    # Wait for Chrome to start
    echo "Waiting for Chrome to start..."
    sleep 3

    # Verify Chrome started
    curl -s http://127.0.0.1:${CHROME_DEBUG_PORT}/json/version > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Chrome started successfully on port ${CHROME_DEBUG_PORT}"
    else
        echo "ERROR: Chrome failed to start. Please start Chrome manually with:"
        echo "/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=${CHROME_DEBUG_PORT} --user-data-dir=/tmp/chrome-worktree-${WORKTREE_COLOR}"
        # Exit or ask user for help
    fi
fi
```

---

### Phase UI-3: Launch UI Testing Agent

**Verify the test file exists:**

```bash
# Check that the test file exists
if [ ! -f "${TEST_FILE_PATH}" ]; then
    echo "ERROR: Test file not found: ${TEST_FILE_PATH}"
    # Exit with error
fi
```

**Launch the ui-testing-agent:**

```python
Task(
    subagent_type="ui-testing-agent",
    prompt=f"""
You are executing UI tests in a worktree environment with Chrome DevTools MCP.

TEST FILE: {TEST_FILE_PATH}

WORKTREE CONTEXT:
- Color: {WORKTREE_COLOR}
- Path: {WORKTREE_PATH}
- Chrome Debug Port: {CHROME_DEBUG_PORT}

ENVIRONMENT:
- Frontend URL: {FRONTEND_URL}
- Backend URL: {BACKEND_URL}

OUTPUT DIRECTORY: {TEST_RESULTS_DIR}

WORKFLOW:
1. Read the test configuration from backend/ai_docs/epics/testing/hosthero.test.config.yaml
2. Read the test file at {TEST_FILE_PATH}
3. Extract the recommended profile from the test file header
4. Load credentials and test data for that profile
5. Execute each test scenario using Chrome DevTools MCP tools
6. Take screenshots at checkpoints specified in the test file
7. Record pass/fail status for each step
8. Generate test report in {TEST_RESULTS_DIR}/pending/

IMPORTANT:
- Always take a snapshot before interacting with elements (for UIDs)
- Use wait_for when expecting dynamic content
- Take screenshots on failures
- Check console for JavaScript errors after each navigation
- Use the profile credentials from hosthero.test.config.yaml

Signal completion with the path to the generated test report.
""",
    description=f"UI Test: {TEST_FILE_PATH}"
)
```

**Wait for ui-testing-agent to complete and extract report path.**

---

### Phase UI-4: Report Results

**Read the test report to extract summary:**

```bash
Read(file_path="{test_report_path}")
```

**Notify the user:**

```
🧪 UI Test Complete!

Test File: {TEST_FILE_PATH}
Worktree: {WORKTREE_COLOR}
Chrome Port: {CHROME_DEBUG_PORT}

RESULTS:
- Total Scenarios: {scenario_count}
- Passed: {pass_count}
- Failed: {fail_count}
- Skipped: {skip_count}

OVERALL: {PASS|FAIL}

TEST REPORT: {test_report_path}

SCREENSHOTS: {TEST_RESULTS_DIR}/screenshots/run_{timestamp}/

{If failures found:}
ISSUES FOUND:
{List of failed test IDs with brief descriptions}

To view the full report:
  cat {test_report_path}

To view screenshots:
  ls {TEST_RESULTS_DIR}/screenshots/run_{timestamp}/

{If all passed:}
All tests passed! No issues found.

Next steps:
1. Review the test report for details
2. If issues found, create a development task to fix them:
   /worktree:wt_coordinate "Fix issues from UI test {TEST_FILE_PATH}"
3. Re-run tests after fixes
```

---

### Phase UI-5: Chrome Cleanup

**After reporting results, ask whether to clean up Chrome:**

```markdown
UI testing is complete. Should I shut down the Chrome instance on port {CHROME_DEBUG_PORT}?

Options:
1. **Yes** - Clean up now (recommended if no more testing planned)
2. **No** - Keep running for additional testing

(Keeping Chrome running allows faster subsequent tests, but consumes system resources)
```

**If user says yes (or explicitly told testing is complete):**

```bash
# Find and kill Chrome process on this worktree's port
CHROME_PID=$(ps aux | grep -E "remote-debugging-port=${CHROME_DEBUG_PORT}" | grep -v grep | awk '{print $2}' | head -1)

if [ -n "$CHROME_PID" ]; then
    kill $CHROME_PID
    echo "Chrome process $CHROME_PID terminated"

    # Optionally clean up temp profile
    rm -rf /tmp/chrome-worktree-${WORKTREE_COLOR}
    echo "Temp profile cleaned up"
else
    echo "No Chrome process found on port ${CHROME_DEBUG_PORT}"
fi
```

**If user says no:** Leave Chrome running and note it in the response.

---

## UI Testing Requirements

1. **Must run from worktree directory** - Context detection relies on path
2. **Chrome must be available** - Will be launched automatically if not running
3. **MCP must be configured** - .mcp.json must have chrome-devtools with correct port
4. **Test file must exist** - Path provided must be valid
5. **Frontend/backend should be running** - Tests need the app to be accessible

## UI Testing Success Criteria

- ✅ Worktree context detected correctly
- ✅ Chrome launched or verified running on correct port
- ✅ Test file found and parsed
- ✅ All test scenarios executed
- ✅ Screenshots taken at checkpoints
- ✅ Test report generated in test_results/pending/
- ✅ User notified with clear summary

## UI Testing Error Handling

**If Chrome fails to start:**
- Provide manual launch command
- Ask user to verify Chrome is installed

**If MCP connection fails:**
- Verify .mcp.json has correct port
- Restart Claude Code to reload MCP config

**If test file not found:**
- List available test files in testing directory
- Suggest checking the path

**If tests fail unexpectedly:**
- Save partial results
- Take screenshot of current state
- Report which scenario/step failed
