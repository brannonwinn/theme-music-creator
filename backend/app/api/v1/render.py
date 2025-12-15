from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy.orm import Session

from api.v1.callback import post_callback
from database.session import db_session
from schemas import RenderBaseThemeRequest, RenderBaseThemeResponse, RenderOverrides
from services import BaseRenderService, SupabaseStorageService, get_current_client, get_storage_service


router = APIRouter()


@router.post(
    "/base/render",
    response_model=RenderBaseThemeResponse,
    summary="Render base_theme.wav from theme MIDI with presets + overrides",
)
async def render_base_theme(
    req: RenderBaseThemeRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(db_session),
    client=Depends(get_current_client),
    storage: SupabaseStorageService = Depends(get_storage_service),
):
    """Render a theme's MIDI to audio.

    This endpoint takes a theme ID and renders its combined MIDI file
    to a WAV audio file using the specified style preset and optional
    instrument/effect overrides.
    """
    svc = BaseRenderService(db=db, storage=storage)

    result = svc.render_base_theme(
        client=client,
        theme_id=req.theme_id,
        preset=req.preset,
        overrides=req.overrides,
    )

    applied_overrides = RenderOverrides(
        melody_instrument=result.effective_config.melody_instrument,
        chords_instrument=result.effective_config.chords_instrument,
        bass_instrument=result.effective_config.bass_instrument,
        transpose_semitones=result.effective_config.transpose_semitones,
        tempo_bpm=result.effective_config.tempo_bpm,
        reverb=result.effective_config.reverb,
        velocity_style=result.effective_config.velocity_style,
        chord_voicing=result.effective_config.chord_voicing,
    )

    resp = RenderBaseThemeResponse(
        theme_id=result.theme_id,
        base_theme_url=result.base_theme_url,
        preset=result.preset,
        applied_overrides=applied_overrides,
    )

    if req.callback_url:
        background_tasks.add_task(
            post_callback,
            req.callback_url,
            "theme.base.rendered",
            resp.model_dump(),
        )

    return resp
