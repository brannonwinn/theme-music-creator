#!/usr/bin/env python3
"""
Update Redis cache with current git context.

This script is called by git hooks (post-commit, post-checkout, post-merge, post-rebase)
to keep the Redis cache up-to-date with the current git state.

Fast execution (<50ms) and non-blocking.
"""

import subprocess
import json
import os
import sys
from pathlib import Path
import time

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from redis_client import RedisClient
from context_detector import detect_project_context, detect_worktree_context


def get_git_status(cwd: str) -> dict:
    """
    Run git commands and return current status.

    Args:
        cwd: Current working directory

    Returns:
        Dict with git data: branch, modified_files, recent_commits
    """
    git_data = {
        'branch': None,
        'modified_files': [],
        'recent_commits': [],
        'last_updated': time.time()
    }

    try:
        # Get current branch
        result = subprocess.run(
            ['git', 'branch', '--show-current'],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0:
            git_data['branch'] = result.stdout.strip()

        # Get modified files (both staged and unstaged)
        result = subprocess.run(
            ['git', 'status', '--porcelain'],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0:
            lines = [line.strip() for line in result.stdout.split('\n') if line.strip()]
            git_data['modified_files'] = lines
            git_data['modified_files_count'] = len(lines)

        # Get recent commits (last 5)
        result = subprocess.run(
            ['git', 'log', '--oneline', '-n', '5'],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0:
            git_data['recent_commits'] = [
                line.strip() for line in result.stdout.split('\n') if line.strip()
            ]

    except subprocess.TimeoutExpired:
        print("Git command timeout", file=sys.stderr)
    except FileNotFoundError:
        print("Git command not found - is git installed?", file=sys.stderr)
    except Exception as e:
        print(f"Git command error: {e}", file=sys.stderr)

    return git_data


def main():
    """Update git cache in Redis."""
    cwd = os.getcwd()

    # Load .env if available (for REDIS_URL)
    try:
        from dotenv import load_dotenv
        load_dotenv()
    except ImportError:
        pass

    # Initialize Redis
    redis_url = os.getenv('REDIS_URL', 'redis://localhost:6380/0')
    redis_client = RedisClient(redis_url)

    if not redis_client.is_available():
        # Don't fail if Redis is unavailable - hooks will detect on next run
        print("Redis unavailable, skipping cache update (non-critical)", file=sys.stderr)
        return 0

    # Detect contexts
    try:
        project_context = detect_project_context(cwd)
        worktree_context = detect_worktree_context(cwd)
    except Exception as e:
        print(f"Context detection error: {e}", file=sys.stderr)
        return 1

    # Get git status
    git_data = get_git_status(cwd)

    # Update Redis cache
    try:
        success = redis_client.set_git(
            project_context['project_name'],
            git_data,
            worktree_context.get('worktree_name'),
            ttl=30  # 30 second TTL (will be updated by next git operation)
        )

        if success:
            agent_info = ""
            if worktree_context.get('agent_color'):
                agent_info = f" [{worktree_context['agent_color']}]"
            print(f"✓ Updated git cache for {project_context['project_name']}{agent_info}")
            return 0
        else:
            print("✗ Failed to update git cache", file=sys.stderr)
            return 1

    except Exception as e:
        print(f"Redis update error: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
