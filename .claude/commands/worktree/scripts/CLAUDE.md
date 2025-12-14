## Common Patterns for Portability

### Fallback Pattern with Warnings

When using centralized configuration functions, always add warnings when falling back to defaults:

```bash
# Get project name with fallback
PROJECT_NAME=$(get_project_name)
if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "null" ]; then
    print_warning "PROJECT_NAME not found in config, using default: agent_observer"
    PROJECT_NAME="agent_observer"
fi
```

This pattern:
- Tries centralized function first
- Checks for both empty and "null" returns
- Warns user when config is missing
- Provides sensible default as last resort

### Dynamic Display Values

When displaying configuration-derived values to users, use variables instead of hardcoded numbers:

```bash
# For port calculations
local base_backend_default=6789
local base_frontend_default=3000
local port_offset_default=10

echo "Backend:  ${base_backend_default} + (offset * ${port_offset_default})"
echo "Frontend: ${base_frontend_default} + (offset * ${port_offset_default})"
```

This makes it easy to update formulas in one place when defaults change.

### Port-Aware Backend Health Checks

When scripts need to verify a backend is running on a worktree-specific port:

```bash
# Detect worktree and get port
local worktree_color=$(detect_agent_color)
local backend_port=$(get_service_port "$worktree_color" "backend")

# Check if backend is accessible
local openapi_url="http://localhost:${backend_port}/openapi.json"
if curl -s --max-time 5 "$openapi_url" > /dev/null 2>&1; then
    print_success "Backend is running"
    # Proceed with backend-dependent operations
else
    print_error "Backend is not running on port $backend_port"
    echo "Please start the backend first:"
    echo "  cd $PROJECT_ROOT/$BACKEND_DIR"
    echo "  uv run ./start.sh"
    exit 1
fi
```

This pattern:
- Uses `detect_agent_color()` to auto-detect worktree
- Uses `get_service_port()` for consistent port calculation
- Validates backend availability before dependent operations
- Provides clear instructions when backend is not available
- Uses 5-second timeout to avoid hanging

**Timeout guidelines:**
- Backend/API: 5 seconds (may need to cold start)
- Frontend dev server: 3 seconds (usually quick)
- Database: 2 seconds (should respond instantly)

**Reasoning:** This pattern emerged from implementing the --codegen flag and represents a reusable approach for any script that needs to interact with a worktree's backend service. It ensures consistency across scripts and provides good user feedback.
