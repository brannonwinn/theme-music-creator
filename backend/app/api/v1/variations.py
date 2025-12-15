from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy.orm import Session

from api.v1.callback import post_callback
from database.session import db_session
from schemas import GenerateThemeVariationRequest, GenerateThemeVariationResponse
from services import (
    AIBackendService,
    SupabaseStorageService,
    VariationService,
    get_ai_backend_service,
    get_current_client,
    get_storage_service,
)


router = APIRouter()


@router.post(
    "/variations",
    response_model=GenerateThemeVariationResponse,
    summary="Generate an AI variation audio file from a base theme and prompt",
)
async def generate_variation(
    req: GenerateThemeVariationRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(db_session),
    client=Depends(get_current_client),
    storage: SupabaseStorageService = Depends(get_storage_service),
    ai_backend: AIBackendService = Depends(get_ai_backend_service),
):
    """Generate an AI-powered variation of a theme.

    This endpoint takes a theme ID and generates a new audio variation
    using AI, based on the provided text prompt and parameters.
    """
    svc = VariationService(db=db, storage=storage, ai_backend=ai_backend)

    result = svc.generate_variation(
        client=client,
        theme_id=req.theme_id,
        prompt=req.prompt,
        length_seconds=req.length_seconds,
        seed=req.seed,
    )

    resp = GenerateThemeVariationResponse(
        variation_id=result.variation_id,
        theme_id=result.theme_id,
        audio_url=result.audio_url,
        length_seconds=result.length_seconds,
        prompt=result.prompt,
        seed=result.seed,
    )

    if req.callback_url:
        background_tasks.add_task(
            post_callback,
            req.callback_url,
            "theme.variation.generated",
            resp.model_dump(),
        )

    return resp
