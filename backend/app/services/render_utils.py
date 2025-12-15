from typing import Optional

from schemas.enums import (
    ChordVoicing,
    Instrument,
    ReverbLevel,
    StylePreset,
    VelocityStyle,
)
from schemas.render import RenderConfig, RenderOverrides


def preset_to_config(preset: StylePreset) -> RenderConfig:
    """Convert a style preset to a full render configuration."""
    if preset == StylePreset.lullaby:
        return RenderConfig(
            melody_instrument=Instrument.MUSIC_BOX,
            chords_instrument=Instrument.CELESTA,
            bass_instrument=None,
            transpose_semitones=12,
            reverb=ReverbLevel.medium,
            velocity_style=VelocityStyle.soft,
            chord_voicing=ChordVoicing.block,
        )
    if preset == StylePreset.cinematic:
        return RenderConfig(
            melody_instrument=Instrument.VIOLIN,
            chords_instrument=Instrument.STRING_ENSEMBLE_1,
            bass_instrument=Instrument.CELLO,
            transpose_semitones=0,
            reverb=ReverbLevel.medium,
            velocity_style=VelocityStyle.dynamic,
            chord_voicing=ChordVoicing.block,
        )
    if preset == StylePreset.ambient:
        return RenderConfig(
            melody_instrument=Instrument.PAD_WARM,
            chords_instrument=Instrument.PAD_SWEEP,
            bass_instrument=None,
            transpose_semitones=0,
            reverb=ReverbLevel.high,
            velocity_style=VelocityStyle.soft,
            chord_voicing=ChordVoicing.sparse,
        )
    if preset == StylePreset.dark_low:
        return RenderConfig(
            melody_instrument=Instrument.STRING_ENSEMBLE_2,
            chords_instrument=Instrument.STRING_ENSEMBLE_1,
            bass_instrument=Instrument.CONTRABASS,
            transpose_semitones=-12,
            reverb=ReverbLevel.high,
            velocity_style=VelocityStyle.dynamic,
            chord_voicing=ChordVoicing.broken_slow,
        )
    # Default: neutral
    return RenderConfig(
        melody_instrument=Instrument.ACOUSTIC_GRAND_PIANO,
        chords_instrument=Instrument.ACOUSTIC_GRAND_PIANO,
        bass_instrument=None,
        transpose_semitones=0,
        reverb=ReverbLevel.medium,
        velocity_style=VelocityStyle.even,
        chord_voicing=ChordVoicing.block,
    )


def apply_overrides(
    base: RenderConfig, overrides: Optional[RenderOverrides]
) -> RenderConfig:
    """Apply optional overrides to a base render configuration."""
    if not overrides:
        return base
    data = base.model_dump()
    for k, v in overrides.model_dump(exclude_unset=True).items():
        if v is not None:
            data[k] = v
    return RenderConfig(**data)
