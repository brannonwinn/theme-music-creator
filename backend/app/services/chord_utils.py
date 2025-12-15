from typing import List

from schemas.enums import ChordProgressionPreset


def get_roman_progression_for_preset(
    key_mode: str,
    preset: ChordProgressionPreset,
) -> List[str]:
    """Get Roman numeral chord progression for a given key mode and preset."""
    is_major = key_mode == "major"

    if preset == ChordProgressionPreset.cinematic_basic:
        return ["I", "vi", "IV", "V"] if is_major else ["i", "VI", "III", "VII"]
    if preset == ChordProgressionPreset.cinematic_suspense:
        return ["vi", "IV", "ii", "V"] if is_major else ["i", "VI", "iv", "V"]
    if preset == ChordProgressionPreset.descending:
        return ["I", "VII", "vi", "V"] if is_major else ["i", "VII", "VI", "V"]
    if preset == ChordProgressionPreset.pedal_tonic:
        return ["I", "I", "IV", "I"] if is_major else ["i", "i", "iv", "i"]
    if preset == ChordProgressionPreset.pop_four:
        return ["I", "V", "vi", "IV"] if is_major else ["i", "VII", "VI", "VII"]
    if preset == ChordProgressionPreset.minimal:
        return ["I", "V", "I", "V"] if is_major else ["i", "v", "i", "v"]

    # Default fallback
    return ["I", "vi", "IV", "V"] if is_major else ["i", "VI", "III", "VII"]
