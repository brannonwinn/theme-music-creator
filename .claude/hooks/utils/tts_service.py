"""
Centralized TTS service with configurable providers and automatic fallback.

This module provides a unified interface for text-to-speech across all hooks.
Configuration via .env file flags: ENABLE_ELEVENLABS_TTS, ENABLE_OPENAI_TTS, ENABLE_PYTTSX3_TTS

Priority order: ElevenLabs > OpenAI > pyttsx3
If a service fails (out of credits, error, etc.), automatically falls back to next enabled service.
"""

import os
import subprocess
from pathlib import Path


def is_enabled(env_var):
    """Check if a TTS service is enabled via environment variable."""
    value = os.getenv(env_var, 'false').lower()
    return value in ('true', '1', 'yes', 'on')


def announce(message, timeout=10):
    """
    Announce a message using the best available TTS service.

    Tries enabled TTS services in priority order with automatic fallback:
    1. ElevenLabs (if ENABLE_ELEVENLABS_TTS=true)
    2. OpenAI (if ENABLE_OPENAI_TTS=true)
    3. pyttsx3 (if ENABLE_PYTTSX3_TTS=true)

    Args:
        message (str): The text message to speak
        timeout (int): Timeout in seconds for TTS script execution (default: 10)

    Returns:
        bool: True if announcement was successful, False otherwise
    """
    try:
        # Get TTS scripts directory
        hooks_dir = Path(__file__).parent.parent
        tts_dir = hooks_dir / "utils" / "tts"

        # Define TTS services in priority order
        tts_services = [
            {
                'name': 'ElevenLabs',
                'enabled': is_enabled('ENABLE_ELEVENLABS_TTS'),
                'has_key': bool(os.getenv('ELEVENLABS_API_KEY')),
                'script': tts_dir / "elevenlabs_tts.py"
            },
            {
                'name': 'OpenAI',
                'enabled': is_enabled('ENABLE_OPENAI_TTS'),
                'has_key': bool(os.getenv('OPENAI_API_KEY')),
                'script': tts_dir / "openai_tts.py"
            },
            {
                'name': 'pyttsx3',
                'enabled': is_enabled('ENABLE_PYTTSX3_TTS'),
                'has_key': True,  # pyttsx3 doesn't need an API key
                'script': tts_dir / "pyttsx3_tts.py"
            }
        ]

        # Try each enabled service in order
        for service in tts_services:
            # Skip if not enabled or missing API key or script doesn't exist
            if not service['enabled'] or not service['has_key'] or not service['script'].exists():
                continue

            try:
                result = subprocess.run([
                    "uv", "run", str(service['script']), message
                ],
                env=os.environ.copy(),
                capture_output=True,
                timeout=timeout
                )

                # If successful, we're done
                if result.returncode == 0:
                    return True

                # If failed, continue to next service (automatic fallback)

            except (subprocess.TimeoutExpired, subprocess.SubprocessError):
                # Continue to next service
                pass

        return False

    except Exception:
        # Fail silently for any other errors
        return False
