from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, UploadFile
from pydantic import HttpUrl
from sqlalchemy.orm import Session

from api.v1.callback import post_callback
from database.session import db_session
from schemas import GenerateThemeStructureOptions, GenerateThemeStructureResponse
from services import ThemeStructureService, SupabaseStorageService, get_current_client, get_storage_service


router = APIRouter()


@router.post(
    "/structure",
    response_model=GenerateThemeStructureResponse,
    summary="Generate melody + chords MIDI from a raw vocal recording",
)
async def generate_theme_structure(
    background_tasks: BackgroundTasks,
    vocal_audio: UploadFile = File(...),
    options_json: str = Form("{}"),
    callback_url: Optional[HttpUrl] = Form(None),
    db: Session = Depends(db_session),
    client=Depends(get_current_client),
    storage: SupabaseStorageService = Depends(get_storage_service),
):
    """Generate a theme structure from vocal audio.

    This endpoint accepts a vocal recording and converts it to MIDI,
    generating melody and chord tracks based on the provided options.
    """
    try:
        options = GenerateThemeStructureOptions.model_validate_json(options_json)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid options_json: {e}")

    svc = ThemeStructureService(db=db, storage=storage)
    vocal_bytes = await vocal_audio.read()

    result = svc.process_vocal_to_theme(
        client=client,
        vocal_bytes=vocal_bytes,
        options=options,
    )

    resp = GenerateThemeStructureResponse(
        theme_id=result.theme_id,
        melody_midi_url=result.melody_midi_url,
        chords_midi_url=result.chords_midi_url,
        combined_midi_url=result.combined_midi_url,
    )

    if callback_url:
        background_tasks.add_task(
            post_callback,
            callback_url,
            "theme.structure.completed",
            resp.model_dump(),
        )

    return resp
