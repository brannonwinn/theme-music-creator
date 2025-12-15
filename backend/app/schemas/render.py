from typing import Optional

from pydantic import BaseModel, HttpUrl

from schemas.enums import (
    ChordVoicing,
    Instrument,
    ReverbLevel,
    StylePreset,
    VelocityStyle,
)


class RenderOverrides(BaseModel):
    melody_instrument: Optional[Instrument] = None
    chords_instrument: Optional[Instrument] = None
    bass_instrument: Optional[Instrument] = None
    transpose_semitones: Optional[int] = None
    tempo_bpm: Optional[int] = None
    reverb: Optional[ReverbLevel] = None
    velocity_style: Optional[VelocityStyle] = None
    chord_voicing: Optional[ChordVoicing] = None


class RenderConfig(BaseModel):
    melody_instrument: Instrument
    chords_instrument: Instrument
    bass_instrument: Optional[Instrument] = None
    transpose_semitones: int = 0
    tempo_bpm: Optional[int] = None
    reverb: ReverbLevel = ReverbLevel.medium
    velocity_style: VelocityStyle = VelocityStyle.dynamic
    chord_voicing: ChordVoicing = ChordVoicing.block


class RenderBaseThemeRequest(BaseModel):
    theme_id: str
    preset: StylePreset = StylePreset.neutral
    overrides: Optional[RenderOverrides] = None
    callback_url: Optional[HttpUrl] = None


class RenderBaseThemeResponse(BaseModel):
    theme_id: str
    base_theme_url: HttpUrl
    preset: StylePreset
    applied_overrides: RenderOverrides


class BaseRenderResult(BaseModel):
    base_render_id: str
    theme_id: str
    base_theme_url: str
    preset: StylePreset
    effective_config: RenderConfig
