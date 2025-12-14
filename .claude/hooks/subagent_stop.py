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
from datetime import datetime
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

    load_dotenv()
except ImportError:
    pass  # dotenv is optional


def get_subagent_completion_message(input_data):
    """
    Build context-aware subagent completion message with graceful fallback.

    Fallback chain:
    1. Agent + task: "Blue Guardian subagent working on health-endpoint complete"
    2. Agent + project: "Blue Guardian subagent complete on agent_observer"
    3. Project only: "Subagent complete on agent_observer"
    4. Generic: "Subagent complete"

    Args:
        input_data: Hook input data containing cwd and other context

    Returns:
        str: Context-aware subagent completion message
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

    # Build message with fallback
    agent_name = worktree_ctx.get('agent_name')  # "Blue Guardian"
    project_name = project_ctx.get('project_name')  # "agent_observer"

    # Level 1: Full context (agent + task)
    if agent_name and task_slug:
        return f"{agent_name} subagent working on {task_slug} complete"

    # Level 2: Agent + project
    if agent_name and project_name:
        return f"{agent_name} subagent complete on {project_name}"

    # Level 3: Project only
    if project_name:
        return f"Subagent complete on {project_name}"

    # Level 4: Fallback (current behavior)
    return "Subagent complete"


def announce_subagent_completion(input_data):
    """
    Announce subagent completion using the centralized TTS service.

    Uses context-aware message generation with graceful fallback:
    - Detects agent color, project name, and current task
    - Falls back gracefully if Redis/git context unavailable
    - No engineer name for subagent completions (more concise)
    """
    try:
        # Import centralized TTS service
        from utils.tts_service import announce

        # Get context-aware completion message
        completion_message = get_subagent_completion_message(input_data)

        # Announce using centralized service (handles fallback automatically)
        announce(completion_message)

    except Exception:
        # Fail silently for any errors
        pass


def main():
    try:
        # Parse command line arguments
        parser = argparse.ArgumentParser()
        parser.add_argument(
            "--chat", action="store_true", help="Copy transcript to chat.json"
        )
        parser.add_argument(
            "--notify", action="store_true", help="Announce subagent completion via TTS"
        )
        args = parser.parse_args()

        # Read JSON input from stdin
        input_data = json.load(sys.stdin)

        # Extract required fields
        session_id = input_data.get("session_id", "")
        stop_hook_active = input_data.get("stop_hook_active", False)

        # Ensure session log directory exists
        log_dir = ensure_session_log_dir(session_id)
        log_path = log_dir / "subagent_stop.json"

        # Read existing log data or initialize empty list
        if log_path.exists():
            with open(log_path, "r") as f:
                try:
                    log_data = json.load(f)
                except (json.JSONDecodeError, ValueError):
                    log_data = []
        else:
            log_data = []

        # Append new data
        log_data.append(input_data)

        # Write back to file with formatting
        with open(log_path, "w") as f:
            json.dump(log_data, f, indent=2)

        # Handle --chat switch (same as stop.py)
        if args.chat and "transcript_path" in input_data:
            transcript_path = input_data["transcript_path"]
            if os.path.exists(transcript_path):
                # Read .jsonl file and convert to JSON array
                chat_data = []
                try:
                    with open(transcript_path, "r") as f:
                        for line in f:
                            line = line.strip()
                            if line:
                                try:
                                    chat_data.append(json.loads(line))
                                except json.JSONDecodeError:
                                    pass  # Skip invalid lines

                    # Write to logs/chat.json
                    chat_file = os.path.join(log_dir, "chat.json")
                    with open(chat_file, "w") as f:
                        json.dump(chat_data, f, indent=2)
                except Exception:
                    pass  # Fail silently

        if args.notify:
            # Announce subagent completion via TTS
            announce_subagent_completion(input_data)

        sys.exit(0)

    except json.JSONDecodeError:
        # Handle JSON decode errors gracefully
        sys.exit(0)
    except Exception:
        # Handle any other errors gracefully
        sys.exit(0)


if __name__ == "__main__":
    main()
