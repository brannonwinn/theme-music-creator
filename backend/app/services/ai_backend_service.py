import os
from typing import Optional

import requests
from fastapi import HTTPException


AI_ENDPOINT_URL = os.getenv("AI_ENDPOINT_URL", "")
AI_API_KEY = os.getenv("AI_API_KEY", "")


class AIBackendService:
    """Service for communicating with the AI music generation backend."""

    def __init__(
        self,
        endpoint_url: str = AI_ENDPOINT_URL,
        api_key: str = AI_API_KEY,
    ):
        self.endpoint_url = endpoint_url
        self.api_key = api_key

    def generate_variation(
        self,
        input_audio_bytes: bytes,
        prompt: str,
        duration: int,
        seed: Optional[int] = None,
    ) -> bytes:
        """Generate a variation of the input audio using the AI backend."""
        if not self.endpoint_url or not self.api_key:
            raise HTTPException(status_code=500, detail="AI backend not configured")

        headers = {"Authorization": f"Bearer {self.api_key}"}
        files = {"input_audio": ("base_theme.wav", input_audio_bytes, "audio/wav")}
        data = {"prompt": prompt, "duration": duration}
        if seed is not None:
            data["seed"] = seed

        resp = requests.post(
            self.endpoint_url,
            headers=headers,
            data=data,
            files=files,
            timeout=300,
        )
        try:
            resp.raise_for_status()
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"AI backend error: {e}")

        return resp.content


def get_ai_backend_service() -> AIBackendService:
    """Factory function to get an AIBackendService instance."""
    return AIBackendService()
