#!/bin/bash

# generate_mcp_json.sh - Generate .mcp.json with agent-specific Chrome debug port
#
# This script generates a worktree-specific .mcp.json file that configures the
# Chrome DevTools MCP server with the correct debug port from worktree.config.yaml.
#
# This enables multiple Claude agents to work in parallel, each with their own
# Chrome browser instance on a unique debug port, preventing cross-contamination.
#
# Usage:
#   ./generate_mcp_json.sh <agent_color> <worktree_path>
#
# Examples:
#   ./generate_mcp_json.sh blue ~/projects/host_hero_blue
#   ./generate_mcp_json.sh red ~/projects/host_hero_red

set -e

# Source common configuration and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Validate arguments
if [ $# -ne 2 ]; then
    print_error "Usage: $0 <agent_color> <worktree_path>"
    echo ""
    echo "Examples:"
    echo "  $0 blue ~/projects/host_hero_blue"
    echo "  $0 red ~/projects/host_hero_red"
    exit 1
fi

AGENT_COLOR="$1"
WORKTREE_PATH="$2"

# Validate agent color
validate_color "$AGENT_COLOR"

# Validate worktree path
if [ ! -d "$WORKTREE_PATH" ]; then
    print_error "Worktree path does not exist: $WORKTREE_PATH"
    exit 1
fi

# Get Chrome debug port from config
CHROME_DEBUG_PORT=$(get_worktree_config "$AGENT_COLOR" "chrome_debug_port")

# Fallback to calculated port if not in config
if [ -z "$CHROME_DEBUG_PORT" ] || [ "$CHROME_DEBUG_PORT" = "null" ]; then
    # Calculate based on agent order (blue=9222, red=9223, white=9224, etc.)
    case "$AGENT_COLOR" in
        blue) CHROME_DEBUG_PORT=9222 ;;
        red) CHROME_DEBUG_PORT=9223 ;;
        white) CHROME_DEBUG_PORT=9224 ;;
        green) CHROME_DEBUG_PORT=9225 ;;
        *) CHROME_DEBUG_PORT=9222 ;;
    esac
    print_warning "chrome_debug_port not found in config for $AGENT_COLOR, using default: $CHROME_DEBUG_PORT"
fi

# Get agent display name
AGENT_NAME=$(get_agent_name "$AGENT_COLOR")
AGENT_COLOR_CODE=$(get_agent_color "$AGENT_COLOR")

# ============================================================================
# MAIN FUNCTION
# ============================================================================

main() {
    echo ""
    print_header "Generating .mcp.json for ${AGENT_COLOR} Worktree"
    echo ""
    echo -e "${AGENT_COLOR_CODE}Worktree: ${WORKTREE_PATH}${NC}"
    echo -e "${AGENT_COLOR_CODE}Agent: ${AGENT_NAME}${NC}"
    echo -e "${AGENT_COLOR_CODE}Chrome Debug Port: ${CHROME_DEBUG_PORT}${NC}"
    echo ""

    # Generate .mcp.json
    local target_file="$WORKTREE_PATH/.mcp.json"

    cat > "$target_file" << EOF
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": [
        "-y",
        "@uprise/context7-mcp"
      ],
      "env": {
        "CONTEXT7_API_KEY": "\${CONTEXT7_API_KEY}"
      }
    },
    "firecrawl": {
      "command": "npx",
      "args": [
        "-y",
        "@mendable/firecrawl-mcp"
      ],
      "env": {
        "FIRECRAWL_API_KEY": "\${FIRECRAWL_API_KEY}"
      }
    },
    "shadcn": {
      "command": "npx",
      "args": [
        "shadcn@latest",
        "mcp"
      ]
    },
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "-y",
        "chrome-devtools-mcp@latest",
        "--browserUrl=http://127.0.0.1:${CHROME_DEBUG_PORT}",
        "--isolated"
      ]
    },
    "ElevenLabs": {
      "command": "uvx",
      "args": [
        "elevenlabs-mcp"
      ],
      "env": {
        "ELEVENLABS_API_KEY": "\${ELEVENLABS_API_KEY}"
      }
    },
    "ide": {
      "command": "npx",
      "args": [
        "-y",
        "@uprise/ide-mcp"
      ]
    }
  }
}
EOF

    if [ -f "$target_file" ]; then
        print_success "Generated .mcp.json at $target_file"
        echo ""
        echo -e "${AGENT_COLOR_CODE}Chrome DevTools configured for port ${CHROME_DEBUG_PORT}${NC}"
        echo ""
        echo "To use Chrome DevTools with this worktree, launch Chrome with:"
        echo ""
        echo -e "  ${YELLOW}/Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome --remote-debugging-port=${CHROME_DEBUG_PORT}${NC}"
        echo ""
        echo "Each worktree requires its own Chrome instance with a unique debug port."
    else
        print_error "Failed to generate .mcp.json"
        exit 1
    fi
}

# ============================================================================
# RUN
# ============================================================================

main
