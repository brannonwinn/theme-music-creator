import os
from typing import Optional

import requests
from fastapi import HTTPException
from sqlalchemy.orm import Session

from database.models import (
    ApiClient,
    BaseRender as BaseRenderModel,
    Variation as VariationModel,
)
from schemas.variation import VariationResult
from services.ai_backend_service import AIBackendService
from services.storage_service import SupabaseStorageService


class VariationService:
    """Service for generating AI-powered theme variations."""

    def __init__(
        self,
        db: Session,
        storage: SupabaseStorageService,
        ai_backend: AIBackendService,
    ):
        self.db = db
        self.storage = storage
        self.ai_backend = ai_backend

    def generate_variation(
        self,
        client: ApiClient,
        theme_id: str,
        prompt: str,
        length_seconds: int,
        seed: Optional[int],
    ) -> VariationResult:
        """Generate an AI variation of a theme's base render."""
        br = (
            self.db.query(BaseRenderModel)
            .filter(BaseRenderModel.theme_id == theme_id)
            .order_by(BaseRenderModel.created_at.desc())
            .first()
        )
        if not br:
            raise HTTPException(
                status_code=404, detail="No base render found for theme_id"
            )

        base_theme_url = br.base_theme_url
        resp = requests.get(base_theme_url, timeout=60)
        try:
            resp.raise_for_status()
        except Exception as e:
            raise HTTPException(
                status_code=502, detail=f"Failed to download base_theme.wav: {e}"
            )

        out_bytes = self.ai_backend.generate_variation(
            resp.content,
            prompt=prompt,
            duration=length_seconds,
            seed=seed,
        )

        variation_id = os.urandom(8).hex()
        filename = f"{variation_id}_{length_seconds}s.wav"
        variation_url = self.storage.upload_variation_file(
            variation_id, filename, out_bytes
        )

        var = VariationModel(
            id=variation_id,
            theme_id=theme_id,
            client_id=client.id,
            base_render_id=br.id,
            prompt=prompt,
            length_seconds=length_seconds,
            seed=seed,
            variation_audio_url=variation_url,
            base_theme_url=base_theme_url,
        )
        self.db.add(var)
        self.db.commit()

        return VariationResult(
            variation_id=variation_id,
            theme_id=theme_id,
            audio_url=variation_url,
            length_seconds=length_seconds,
            prompt=prompt,
            seed=seed,
        )
