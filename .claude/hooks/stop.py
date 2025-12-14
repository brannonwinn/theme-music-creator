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
import random
import subprocess
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


def get_completion_messages():
    """Return list of friendly completion messages."""
    return [
        "Work complete!",
        "All done!",
        "Task finished!",
        "Job complete!",
        "Ready for next task!",
    ]


def get_llm_completion_message():
    """
    Generate completion message using available LLM services.
    Priority order: OpenAI > Anthropic > fallback to random message

    Returns:
        str: Generated or fallback completion message
    """
    # Get current script directory and construct utils/llm path
    script_dir = Path(__file__).parent
    llm_dir = script_dir / "utils" / "llm"

    # Try Anthropic second
    if os.getenv("ANTHROPIC_API_KEY"):
        anth_script = llm_dir / "anth.py"
        if anth_script.exists():
            try:
                result = subprocess.run(
                    ["uv", "run", str(anth_script), "--completion"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                if result.returncode == 0 and result.stdout.strip():
                    return result.stdout.strip()
            except (subprocess.TimeoutExpired, subprocess.SubprocessError):
                pass

    # Try OpenAI first (highest priority)
    if os.getenv("OPENAI_API_KEY"):
        oai_script = llm_dir / "oai.py"
        if oai_script.exists():
            try:
                result = subprocess.run(
                    ["uv", "run", str(oai_script), "--completion"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                if result.returncode == 0 and result.stdout.strip():
                    return result.stdout.strip()
            except (subprocess.TimeoutExpired, subprocess.SubprocessError):
                pass

    # Fallback to random predefined message
    messages = get_completion_messages()
    return random.choice(messages)


def get_completion_message_with_context(input_data):
    """
    Build context-aware completion message with graceful fallback.

    Fallback chain:
    1. Agent + task: "Your Blue Guardian working on health-endpoint has finished and is ready for the next task"
    2. Agent + project: "Your Blue Guardian on agent_observer has finished and is ready for the next task"
    3. Project only: "Your agent on agent_observer has finished and is ready for the next task"
    4. Generic: LLM-generated or "Work complete!"

    Args:
        input_data: Hook input data containing cwd and other context

    Returns:
        str: Context-aware completion message
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
        return f"{prefix} {agent_name} working on {task_slug} has finished and is ready for the next task"

    # Level 2: Agent + project
    if agent_name and project_name:
        prefix = f"{engineer_name}, your" if use_name else "Your"
        return f"{prefix} {agent_name} on {project_name} has finished and is ready for the next task"

    # Level 3: Project only
    if project_name:
        prefix = f"{engineer_name}, your" if use_name else "Your"
        return f"{prefix} agent on {project_name} has finished and is ready for the next task"

    # Level 4: Fallback to LLM-generated or generic message
    return get_llm_completion_message()


def announce_completion(input_data):
    """
    Announce completion using the centralized TTS service.

    Uses context-aware message generation with graceful fallback:
    - Detects agent color, project name, and current task
    - Falls back gracefully if Redis/git context unavailable
    - 50% chance to include engineer name for personalization
    - Falls back to LLM-generated or generic message if no context
    """
    try:
        # Import centralized TTS service
        from utils.tts_service import announce

        # Get context-aware completion message
        completion_message = get_completion_message_with_context(input_data)

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
            "--notify", action="store_true", help="Announce completion via TTS"
        )
        args = parser.parse_args()

        # Read JSON input from stdin
        input_data = json.load(sys.stdin)

        # Extract required fields
        session_id = input_data.get("session_id", "")
        stop_hook_active = input_data.get("stop_hook_active", False)

        # Ensure session log directory exists
        log_dir = ensure_session_log_dir(session_id)
        log_path = log_dir / "stop.json"

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

        # Handle --chat switch
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
            # Announce completion via TTS
            announce_completion(input_data)

        sys.exit(0)

    except json.JSONDecodeError:
        # Handle JSON decode errors gracefully
        sys.exit(0)
    except Exception:
        # Handle any other errors gracefully
        sys.exit(0)


if __name__ == "__main__":
    main()
