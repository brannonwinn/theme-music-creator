#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "anthropic",
#     "python-dotenv",
#     "redis",
# ]
# ///

"""
Multi-Agent Observability Hook Script
Sends Claude Code hook events to the observability server.

Enhanced with:
- Redis caching for performance
- Project/worktree/git context detection
- Multi-project support
"""

import json
import sys
import os
import argparse
import urllib.request
import urllib.error
from datetime import datetime
from dotenv import load_dotenv
from utils.summarizer import generate_event_summary
from utils.model_extractor import get_model_from_transcript
from utils.redis_client import RedisClient
from utils.context_detector import (
    detect_project_context,
    detect_worktree_context,
    get_git_context_from_redis,
    parse_feature_branch,
    extract_tool_context
)

# Load environment variables from .env file
load_dotenv()

def send_event_to_server(event_data, server_url='http://localhost:6789/events'):
    """Send event data to the observability server."""
    try:
        # Prepare the request
        req = urllib.request.Request(
            server_url,
            data=json.dumps(event_data).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'Claude-Code-Hook/1.0'
            }
        )

        # Send the request
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                return True
            else:
                print(f"Server returned status: {response.status}", file=sys.stderr)
                return False

    except urllib.error.URLError as e:
        print(f"Failed to send event: {e}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return False

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Send Claude Code hook events to observability server')

    # Get defaults from environment variables
    default_source_app = os.environ.get('SOURCE_APP', 'cc-main')
    default_server_url = os.environ.get('OBSERVABILITY_API_URL', 'http://localhost:6789/events')

    parser.add_argument('--source-app', default=default_source_app, help='Source application name (default from SOURCE_APP env var)')
    parser.add_argument('--event-type', required=True, help='Hook event type (PreToolUse, PostToolUse, etc.)')
    parser.add_argument('--server-url', default=default_server_url, help='Server URL (default from OBSERVABILITY_SERVER_URL env var)')
    parser.add_argument('--add-chat', action='store_true', help='Include chat transcript if available')
    parser.add_argument('--summarize', action='store_true', help='Generate AI summary of the event')

    args = parser.parse_args()

    try:
        # Read hook data from stdin
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Failed to parse JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    # Extract model name from transcript (with caching)
    session_id = input_data.get('session_id', 'unknown')
    transcript_path = input_data.get('transcript_path', '')
    model_name = ''
    if transcript_path:
        model_name = get_model_from_transcript(session_id, transcript_path)

    # Initialize Redis client (graceful degradation if unavailable)
    redis_url = os.getenv('REDIS_URL', 'redis://localhost:6380/0')
    redis_client = RedisClient(redis_url)

    # Detect contexts
    cwd = input_data.get('cwd', os.getcwd())
    project_context = detect_project_context(cwd, redis_client)
    worktree_context = detect_worktree_context(cwd, redis_client)

    # Get git context from Redis cache (fast, no git commands!)
    git_context = get_git_context_from_redis(
        project_context['project_name'],
        worktree_context.get('worktree_name'),
        redis_client
    )

    # Parse branch metadata if git context available
    if git_context and git_context.get('branch'):
        branch_metadata = parse_feature_branch(git_context['branch'])
        git_context.update(branch_metadata)

    # Extract tool context if this is a tool hook
    tool_context = extract_tool_context(input_data)

    # Prepare enhanced event data for server
    event_data = {
        # EXISTING FIELDS
        'source_app': args.source_app,
        'session_id': session_id,
        'hook_event_type': args.event_type,
        'payload': input_data,
        'timestamp': int(datetime.now().timestamp() * 1000),
        'model_name': model_name,

        # NEW: PROJECT CONTEXT
        'project': project_context,

        # NEW: WORKTREE/AGENT CONTEXT
        'worktree': worktree_context,

        # NEW: GIT CONTEXT (from Redis cache)
        'git': git_context,

        # NEW: TOOL CONTEXT (if applicable)
        'tool_context': tool_context,

        # EXISTING: Working Directory
        'cwd': cwd
    }

    # Handle --add-chat option
    if args.add_chat and 'transcript_path' in input_data:
        transcript_path = input_data['transcript_path']
        if os.path.exists(transcript_path):
            # Read .jsonl file and convert to JSON array
            chat_data = []
            try:
                with open(transcript_path, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if line:
                            try:
                                chat_data.append(json.loads(line))
                            except json.JSONDecodeError:
                                pass  # Skip invalid lines

                # Add chat to event data
                event_data['chat'] = chat_data
            except Exception as e:
                print(f"Failed to read transcript: {e}", file=sys.stderr)

    # Generate summary if requested
    if args.summarize:
        summary = generate_event_summary(event_data)
        if summary:
            event_data['summary'] = summary
        # Continue even if summary generation fails

    # Send to server
    success = send_event_to_server(event_data, args.server_url)

    # Always exit with 0 to not block Claude Code operations
    sys.exit(0)

if __name__ == '__main__':
    main()
