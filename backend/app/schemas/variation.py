from typing import Optional

from pydantic import BaseModel, HttpUrl


class GenerateThemeVariationRequest(BaseModel):
    theme_id: str
    prompt: str
    length_seconds: int = 30
    seed: Optional[int] = None
    callback_url: Optional[HttpUrl] = None


class GenerateThemeVariationResponse(BaseModel):
    variation_id: str
    theme_id: str
    audio_url: HttpUrl
    length_seconds: int
    prompt: str
    seed: Optional[int]


class VariationResult(BaseModel):
    variation_id: str
    theme_id: str
    audio_url: str
    length_seconds: int
    prompt: str
    seed: Optional[int]
