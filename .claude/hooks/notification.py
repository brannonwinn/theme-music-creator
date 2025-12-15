#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "python-dotenv",
#     "redis",
# ]
# ///

import argparse
import json
import os
import sys
import subprocess
import random
from pathlib import Path
from utils.constants import ensure_session_log_dir
from utils.context_detector import (
    detect_worktree_context,
    detect_project_context,
    get_git_context_from_redis,
    parse_feature_branch
)
from utils.redis_client import RedisClient

try:
    from dotenv import load_dotenv
    # Load .env from .claude directory (developer-specific settings)
    claude_dir = Path(__file__).parent.parent
    load_dotenv(claude_dir / ".env")
except ImportError:
    pass  # dotenv is optional


def get_notification_message(input_data):
    """
    Build context-aware notification message with graceful fallback.

    Fallback chain:
    1. Agent + task: "Your Blue Guardian working on health-endpoint needs your input"
    2. Agent + project: "Your Blue Guardian on agent_observer needs your input"
    3. Project only: "Your agent on agent_observer needs your input"
    4. Generic: "Your agent needs your input"

    Args:
        input_data: Hook input data containing cwd and other context

    Returns:
        str: Context-aware notification message
    """
    cwd = input_data.get('cwd', os.getcwd())

    # Try to initialize Redis (graceful degradation)
    redis_url = os.getenv('REDIS_URL', 'redis://localhost:6380/0')
    redis_client = RedisClient(redis_url)

    # Detect contexts (work without Redis)
    worktree_ctx = detect_worktree_context(cwd, redis_client)
    project_ctx = detect_project_context(cwd, redis_client)

    # Try to get git context (returns None if Redis unavailable)
    git_ctx = None
    task_slug = None
    if redis_client.is_available():
        git_ctx = get_git_context_from_redis(
            project_ctx['project_name'],
            worktree_ctx.get('worktree_name'),
            redis_client
        )
        if git_ctx and git_ctx.get('branch'):
            branch_meta = parse_feature_branch(git_ctx['branch'])
            if branch_meta.get('feature_metadata'):
                task_slug = branch_meta['feature_metadata'].get('task_slug')

    # Get engineer name (50% chance)
    engineer_name = os.getenv('ENGINEER_NAME', '').strip()
    use_name = engineer_name and random.random() < 0.5

    # Build message with fallback
    agent_name = worktree_ctx.get('agent_name')  # "Blue Guardian"
    project_name = project_ctx.get('project_name')  # "agent_observer"

    # Level 1: Full context (agent + task)
    if agent_name and task_slug:
        prefix = f"{engineer_name}, your" if use_name else "Your"
        return f"{prefix} {agent_name} working on {task_slug} needs your input"

    # Level 2: Agent + project
    if agent_name and project_name:
        prefix = f"{engineer_name}, your" if use_name else "Your"
        return f"{prefix} {agent_name} on {project_name} needs your input"

    # Level 3: Project only
    if project_name:
        prefix = f"{engineer_name}, your" if use_name else "Your"
        return f"{prefix} agent on {project_name} needs your input"

    # Level 4: Fallback (current behavior)
    if use_name:
        return f"{engineer_name}, your agent needs your input"
    return "Your agent needs your input"


def announce_notification(input_data):
    """
    Announce that the agent needs user input using the centralized TTS service.

    Uses context-aware message generation with graceful fallback:
    - Detects agent color, project name, and current task
    - Falls back gracefully if Redis/git context unavailable
    - 50% chance to include engineer name for personalization

    Tries enabled TTS services in priority order with automatic fallback:
    1. ElevenLabs (if ENABLE_ELEVENLABS_TTS=true)
    2. OpenAI (if ENABLE_OPENAI_TTS=true)
    3. pyttsx3 (if ENABLE_PYTTSX3_TTS=true)

    If a service fails (out of credits, error, etc.), automatically falls back to next enabled service.
    """
    try:
        # Import centralized TTS service
        from utils.tts_service import announce

        # Build context-aware notification message
        notification_message = get_notification_message(input_data)

        # Announce using centralized service (handles fallback automatically)
        announce(notification_message)

    except Exception:
        # Fail silently for any errors
        pass


def main():
    try:
        # Parse command line arguments
        parser = argparse.ArgumentParser()
        parser.add_argument('--notify', action='store_true', help='Enable TTS notifications')
        args = parser.parse_args()

        # Read JSON input from stdin
        input_data = json.loads(sys.stdin.read())

        # Extract session_id
        session_id = input_data.get('session_id', 'unknown')

        # Ensure session log directory exists
        log_dir = ensure_session_log_dir(session_id)
        log_file = log_dir / 'notification.json'

        # Read existing log data or initialize empty list
        if log_file.exists():
            with open(log_file, 'r') as f:
                try:
                    log_data = json.load(f)
                except (json.JSONDecodeError, ValueError):
                    log_data = []
        else:
            log_data = []

        # Append new data
        log_data.append(input_data)

        # Write back to file with formatting
        with open(log_file, 'w') as f:
            json.dump(log_data, f, indent=2)

        # Announce notification via TTS only if --notify flag is set
        # Skip TTS for the generic "Claude is waiting for your input" message
        if args.notify and input_data.get('message') != 'Claude is waiting for your input':
            announce_notification(input_data)

        sys.exit(0)

    except json.JSONDecodeError:
        # Handle JSON decode errors gracefully
        sys.exit(0)
    except Exception:
        # Handle any other errors gracefully
        sys.exit(0)

if __name__ == '__main__':
    main()
