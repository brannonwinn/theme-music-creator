from typing import List, Optional

from pydantic import BaseModel

from schemas.enums import ChordComplexity, ChordProgressionPreset


class ChordSettings(BaseModel):
    enabled: bool = True
    harmonic_rhythm_quarters: float = 4.0
    progression_preset: ChordProgressionPreset = ChordProgressionPreset.cinematic_basic
    complexity: ChordComplexity = ChordComplexity.simple
    custom_roman_progression: Optional[List[str]] = None


class GenerateThemeStructureOptions(BaseModel):
    grid: float = 0.25
    chord_settings: ChordSettings = ChordSettings()
