## Portability Patterns for Worktree Scripts

When writing or maintaining worktree scripts, follow these patterns to ensure portability across different project configurations:

### 1. Agent Detection

**Don't:** Hardcode agent names
```bash
# Bad - only works for blue/red/white
if [[ "$path" == *"_blue"* ]]; then
    echo "blue"
fi
```

**Do:** Use dynamic agent lists from config
```bash
# Good - works with any agent names
local agents=$(list_agents)
for agent in $agents; do
    if [[ "$path" == *"_${agent}"* ]]; then
        echo "$agent"
        return 0
    fi
done
```

### 2. Project Name Resolution

**Don't:** Hardcode project name
```bash
# Bad
PROJECT_NAME="agent_observer"
```

**Do:** Use get_project_name() with fallback warning
```bash
# Good
PROJECT_NAME=$(get_project_name)
if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "null" ]; then
    print_warning "PROJECT_NAME not found in config, using default: agent_observer"
    PROJECT_NAME="agent_observer"
fi
```

### 3. Container Name Detection

**Don't:** Hardcode container names
```bash
# Bad
docker exec supabase-shared-db psql ...
```

**Do:** Use detect_supabase_container()
```bash
# Good
DB_CONTAINER=$(detect_supabase_container)
if [ -z "$DB_CONTAINER" ]; then
    print_error "Supabase container not found"
    exit 1
fi
docker exec "$DB_CONTAINER" psql ...
```

### 4. Display Text for Shared Services

**Don't:** Display hardcoded container names/ports
```bash
# Bad
echo "✅ Redis (supabase-shared-redis:6380)"
```

**Do:** Use generic messaging
```bash
# Good
echo "✅ Redis (shared service)"
```

**Reasoning:** Container names, ports, and configurations may vary. Generic messaging works everywhere while hardcoded values break portability.
