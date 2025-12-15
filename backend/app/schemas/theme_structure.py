from pydantic import BaseModel, HttpUrl


class GenerateThemeStructureResponse(BaseModel):
    theme_id: str
    melody_midi_url: HttpUrl
    chords_midi_url: HttpUrl
    combined_midi_url: HttpUrl


class ThemeStructureResult(BaseModel):
    theme_id: str
    theme_structure_id: str
    melody_midi_url: str
    chords_midi_url: str
    combined_midi_url: str
