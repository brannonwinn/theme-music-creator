import os
import tempfile
from typing import Optional

import pretty_midi
import requests
from fastapi import HTTPException
from midi2audio import FluidSynth
from sqlalchemy.orm import Session

from database.models import ApiClient, BaseRender as BaseRenderModel, ThemeStructure
from schemas.enums import StylePreset
from schemas.render import BaseRenderResult, RenderOverrides
from services.midi_utils import gm_program_for
from services.render_utils import apply_overrides, preset_to_config
from services.storage_service import SupabaseStorageService


SOUNDFONT_PATH = os.getenv("SOUNDFONT_PATH", "soundfonts/FluidR3_GM.sf2")


class BaseRenderService:
    """Service for rendering MIDI themes to audio."""

    def __init__(self, db: Session, storage: SupabaseStorageService):
        self.db = db
        self.storage = storage
        self.fs = FluidSynth(SOUNDFONT_PATH)

    def render_base_theme(
        self,
        client: ApiClient,
        theme_id: str,
        preset: StylePreset,
        overrides: Optional[RenderOverrides],
    ) -> BaseRenderResult:
        """Render a theme's MIDI to audio using the specified preset and overrides."""
        ts = (
            self.db.query(ThemeStructure)
            .filter(ThemeStructure.theme_id == theme_id)
            .order_by(ThemeStructure.created_at.desc())
            .first()
        )
        if not ts:
            raise HTTPException(
                status_code=404, detail="No theme structure found for theme_id"
            )

        combined_url = ts.combined_midi_url
        resp = requests.get(combined_url, timeout=60)
        try:
            resp.raise_for_status()
        except Exception as e:
            raise HTTPException(
                status_code=502, detail=f"Failed to download combined MIDI: {e}"
            )

        base_config = preset_to_config(preset)
        final_config = apply_overrides(base_config, overrides)

        with tempfile.TemporaryDirectory() as tmpdir:
            midi_path = os.path.join(tmpdir, "theme_with_chords.mid")
            with open(midi_path, "wb") as f:
                f.write(resp.content)

            pm = pretty_midi.PrettyMIDI(midi_path)
            if not pm.instruments:
                raise HTTPException(status_code=500, detail="MIDI has no instruments")

            melody_inst = pm.instruments[0]
            melody_inst.program = gm_program_for(
                final_config.melody_instrument, default=0
            )
            for n in melody_inst.notes:
                n.pitch = max(0, min(127, n.pitch + final_config.transpose_semitones))

            if len(pm.instruments) > 1:
                chords_inst = pm.instruments[1]
                chords_inst.program = gm_program_for(
                    final_config.chords_instrument, default=0
                )
                for n in chords_inst.notes:
                    n.pitch = max(
                        0, min(127, n.pitch + final_config.transpose_semitones)
                    )

            adjusted_midi_path = os.path.join(tmpdir, "theme_with_chords_render.mid")
            pm.write(adjusted_midi_path)

            wav_path = os.path.join(tmpdir, "base_theme.wav")
            self.fs.midi_to_audio(adjusted_midi_path, wav_path)
            with open(wav_path, "rb") as f:
                wav_bytes = f.read()

        base_theme_url = self.storage.upload_theme_file(
            theme_id, "base_theme.wav", wav_bytes
        )

        br = BaseRenderModel(
            theme_id=theme_id,
            client_id=client.id,
            theme_structure_id=ts.id,
            preset=preset.value,
            overrides_json=overrides.model_dump() if overrides else {},
            effective_config_json=final_config.model_dump(),
            base_theme_url=base_theme_url,
        )
        self.db.add(br)
        self.db.commit()
        self.db.refresh(br)

        return BaseRenderResult(
            base_render_id=br.id,
            theme_id=theme_id,
            base_theme_url=base_theme_url,
            preset=preset,
            effective_config=final_config,
        )
