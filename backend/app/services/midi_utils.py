from typing import Dict

import pretty_midi

from schemas.enums import Instrument


GM_PROGRAMS: Dict[Instrument, int] = {
    Instrument.ACOUSTIC_GRAND_PIANO: 0,
    Instrument.BRIGHT_ACOUSTIC_PIANO: 1,
    Instrument.ELECTRIC_GRAND_PIANO: 2,
    Instrument.HONKY_TONK_PIANO: 3,
    Instrument.MUSIC_BOX: 10,
    Instrument.CELESTA: 8,
    Instrument.VIOLIN: 40,
    Instrument.CELLO: 42,
    Instrument.CONTRABASS: 43,
    Instrument.STRING_ENSEMBLE_1: 48,
    Instrument.STRING_ENSEMBLE_2: 49,
    Instrument.CHOIR_AAHS: 52,
    Instrument.CHOIR_OOHS: 53,
    Instrument.PAD_WARM: 89,
    Instrument.PAD_SWEEP: 95,
}


def gm_program_for(inst: Instrument, default: int = 0) -> int:
    """Get the General MIDI program number for an instrument."""
    return GM_PROGRAMS.get(inst, default)


def quantize_notes(instrument: pretty_midi.Instrument, grid: float = 0.25) -> None:
    """Quantize note timings to a grid."""
    for note in instrument.notes:
        note.start = round(note.start / grid) * grid
        note.end = round(note.end / grid) * grid
        if note.end <= note.start:
            note.end = note.start + grid
