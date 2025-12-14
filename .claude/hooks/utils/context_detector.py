"""
Context detection for multi-project, multi-agent observability.

Automatically detects:
- Project context (name, root, git repo)
- Worktree context (agent color, name, path)
- Git context (branch, modified files, commits)

Uses Redis caching for performance.
"""

from pathlib import Path
import os
import subprocess
import re
import time
from typing import Dict, Any, Optional

try:
    from .redis_client import RedisClient
except ImportError:
    # Handle relative import when run as script
    from redis_client import RedisClient


def detect_project_context(cwd: str, redis_client: Optional[RedisClient] = None) -> Dict[str, Any]:
    """
    Detect project context from environment and filesystem.

    Priority:
    1. Check Redis cache (if available)
    2. PROJECT_NAME env var (required)
    3. Fall back to directory name
    4. Try to detect git repo name

    Args:
        cwd: Current working directory
        redis_client: Optional Redis client for caching

    Returns:
        {
            'project_name': str,
            'project_root': str,
            'git_repo_name': str | None,
            'last_updated': float
        }
    """
    # Get project name (required)
    project_name = os.getenv('PROJECT_NAME')

    # Check cache first
    if redis_client and project_name:
        cached = redis_client.get_context(f"project:{project_name}:context")
        if cached:
            return cached

    # Detect from environment and filesystem
    if not project_name:
        # Fall back to directory name
        project_name = Path(cwd).name

    context = {
        'project_name': project_name,
        'project_root': os.getenv('CLAUDE_PROJECT_DIR', cwd),
        'git_repo_name': os.getenv('GIT_REPO_NAME'),
        'last_updated': time.time()
    }

    # Try to get git repo name from remote
    if not context['git_repo_name']:
        try:
            result = subprocess.run(
                ['git', 'remote', 'get-url', 'origin'],
                cwd=cwd,
                capture_output=True,
                text=True,
                timeout=2
            )
            if result.returncode == 0:
                # Extract repo name from URL
                # Examples:
                #   git@github.com:user/repo.git -> repo
                #   https://github.com/user/repo.git -> repo
                url = result.stdout.strip()
                context['git_repo_name'] = url.split('/')[-1].replace('.git', '')
        except Exception:
            pass

    # Cache for 1 hour
    if redis_client and project_name:
        redis_client.set_context(f"project:{project_name}:context", context, ttl=3600)

    return context


def detect_worktree_context(cwd: str, redis_client: Optional[RedisClient] = None) -> Dict[str, Any]:
    """
    Detect worktree context from path and environment.

    Auto-detection patterns:
    - /path/to/agents/agent_blue -> blue
    - /path/to/agents/agent_red -> red
    - /path/to/worktrees/blue -> blue

    Environment override (highest priority):
    - WORKTREE_NAME=blue
    - AGENT_COLOR=blue
    - AGENT_NAME=Blue Guardian

    Args:
        cwd: Current working directory
        redis_client: Optional Redis client for caching

    Returns:
        {
            'is_worktree': bool,
            'worktree_name': str | None,
            'agent_color': str | None,
            'agent_name': str | None,
            'worktree_path': str | None,
            'agent_type': 'worktree-agent' | 'main',
            'detection_method': 'cwd_path' | 'env_var' | 'none',
            'last_updated': float
        }
    """
    cwd_path = Path(cwd)
    parts = cwd_path.parts

    # Check cache first
    project_name = os.getenv('PROJECT_NAME', Path(cwd).name)
    env_agent_color = os.getenv('AGENT_COLOR')

    if redis_client and project_name and env_agent_color:
        cached = redis_client.get_context(f"project:{project_name}:worktree:{env_agent_color}:context")
        if cached:
            return cached

    # Initialize context
    context = {
        'is_worktree': False,
        'worktree_name': None,
        'agent_color': None,
        'agent_name': None,
        'worktree_path': None,
        'agent_type': 'main',
        'detection_method': 'none',
        'last_updated': time.time()
    }

    # Auto-detect from path
    # Pattern 1: agents/agent_{color}
    # Pattern 2: worktrees/{color}
    for i, part in enumerate(parts):
        if part in ('agents', 'worktrees') and i + 1 < len(parts):
            dir_name = parts[i + 1]

            # Pattern: agent_{color}
            if dir_name.startswith('agent_'):
                color = dir_name.replace('agent_', '')
                context.update({
                    'is_worktree': True,
                    'worktree_name': dir_name,
                    'agent_color': color,
                    'worktree_path': str(cwd_path),
                    'agent_type': 'worktree-agent',
                    'detection_method': 'cwd_path'
                })
                break
            # Pattern: worktrees/{color}
            elif part == 'worktrees':
                color = dir_name
                context.update({
                    'is_worktree': True,
                    'worktree_name': dir_name,
                    'agent_color': color,
                    'worktree_path': str(cwd_path),
                    'agent_type': 'worktree-agent',
                    'detection_method': 'cwd_path'
                })
                break

    # Override with environment variables (highest priority)
    env_worktree_name = os.getenv('WORKTREE_NAME')
    env_agent_name = os.getenv('AGENT_NAME')

    if env_worktree_name or env_agent_color:
        context.update({
            'is_worktree': True,
            'worktree_name': env_worktree_name or context['worktree_name'],
            'agent_color': env_agent_color or context['agent_color'],
            'agent_name': env_agent_name,
            'agent_type': 'worktree-agent',
            'detection_method': 'env_var'
        })

    # Generate default agent name if not set
    if context['agent_color'] and not context['agent_name']:
        color_names = {
            'blue': 'Blue Guardian',
            'red': 'Red Sentinel',
            'white': 'White Oracle',
            'green': 'Green Protector',
            'yellow': 'Yellow Warden',
            'purple': 'Purple Sage'
        }
        context['agent_name'] = color_names.get(
            context['agent_color'],
            f"{context['agent_color'].title()} Agent"
        )

    # Cache for 1 hour
    if redis_client and project_name and context['agent_color']:
        redis_client.set_context(
            f"project:{project_name}:worktree:{context['agent_color']}:context",
            context,
            ttl=3600
        )

    return context


def get_git_context_from_redis(
    project_name: str,
    worktree_name: Optional[str],
    redis_client: Optional[RedisClient]
) -> Optional[Dict[str, Any]]:
    """
    Get cached git context from Redis.

    Fast path: Read from cache instead of running git commands.
    Cache is updated by git hooks (post-commit, post-checkout, etc.)

    Args:
        project_name: Project identifier
        worktree_name: Worktree name (optional)
        redis_client: Redis client

    Returns:
        Dict with git data or None if cache miss or Redis unavailable
    """
    if not redis_client:
        return None

    return redis_client.get_git(project_name, worktree_name)


def parse_feature_branch(branch_name: str) -> Dict[str, Any]:
    """
    Parse feature branch metadata from branch name.

    Supported patterns:
    - feat/{color}-{task-slug}
      Example: feat/blue-health-endpoint -> {color: 'blue', task_slug: 'health-endpoint'}

    - feat/{task-slug}
      Example: feat/add-caching -> {task_slug: 'add-caching'}

    Args:
        branch_name: Git branch name

    Returns:
        {
            'current_branch': str,
            'is_feature_branch': bool,
            'feature_metadata': dict | None
        }
    """
    is_feature = branch_name.startswith('feat/')

    metadata = {
        'current_branch': branch_name,
        'is_feature_branch': is_feature,
        'feature_metadata': None
    }

    if is_feature:
        # Remove 'feat/' prefix
        feature_part = branch_name[5:]

        # Try pattern: {color}-{task-slug}
        match = re.match(r'^([a-z]+)-(.+)$', feature_part)
        if match:
            color = match.group(1)
            task_slug = match.group(2)

            # Only set color if it's a valid color
            valid_colors = {'blue', 'red', 'white', 'green', 'yellow', 'purple', 'orange', 'pink'}
            if color in valid_colors:
                metadata['feature_metadata'] = {
                    'color': color,
                    'task_slug': task_slug
                }
            else:
                # Not a color-prefixed branch, just task slug
                metadata['feature_metadata'] = {
                    'task_slug': feature_part
                }
        else:
            # Simple feature branch without color
            metadata['feature_metadata'] = {
                'task_slug': feature_part
            }

    return metadata


def extract_tool_context(hook_payload: dict) -> Optional[Dict[str, Any]]:
    """
    Extract and classify tool usage context from hook payload.

    Extracts:
    - Tool name and category
    - Target file and type
    - Operation type
    - Bash command info

    Args:
        hook_payload: Raw hook payload from Claude Code

    Returns:
        Dict with tool context or None if not a tool hook
    """
    tool_name = hook_payload.get('tool_name')
    tool_input = hook_payload.get('tool_input', {})

    if not tool_name:
        return None

    # Classify tool by category
    tool_categories = {
        'Read': 'file_operation',
        'Write': 'file_operation',
        'Edit': 'file_operation',
        'Bash': 'code_execution',
        'Glob': 'search',
        'Grep': 'search',
        'WebSearch': 'research',
        'WebFetch': 'research',
        'Task': 'orchestration',
        'NotebookEdit': 'file_operation'
    }

    tool_context = {
        'tool_name': tool_name,
        'tool_category': tool_categories.get(tool_name, 'other')
    }

    # Extract file-related metadata
    file_path = tool_input.get('file_path')
    if file_path:
        path_obj = Path(file_path)

        tool_context.update({
            'target_file': file_path,
            'file_type': path_obj.suffix.lstrip('.') if path_obj.suffix else None,
            'is_test_file': '/tests/' in file_path or '/test_' in file_path or file_path.startswith('test_'),
            'file_directory': str(path_obj.parent)
        })

    # Determine operation type
    operation_types = {
        'Read': 'read',
        'Write': 'write',
        'Edit': 'edit',
        'Bash': 'execute',
        'Glob': 'search',
        'Grep': 'search',
        'NotebookEdit': 'edit'
    }

    tool_context['operation_type'] = operation_types.get(tool_name, 'other')

    # Extract Bash command info
    if tool_name == 'Bash':
        command = tool_input.get('command', '')
        tool_context['bash_command'] = command.split()[0] if command else None
        tool_context['is_test_command'] = any(
            test_cmd in command
            for test_cmd in ['pytest', 'npm test', 'yarn test', 'jest', 'vitest']
        )

    return tool_context
