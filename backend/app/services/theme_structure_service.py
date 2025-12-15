import os
import tempfile
from typing import Optional

import pretty_midi
from basic_pitch.inference import predict_and_save
from fastapi import HTTPException
from music21 import converter, roman, stream
from sqlalchemy.orm import Session

from database.models import ApiClient, Theme, ThemeStructure
from schemas.chord import ChordSettings, GenerateThemeStructureOptions
from schemas.enums import ChordComplexity
from schemas.theme_structure import ThemeStructureResult
from services.chord_utils import get_roman_progression_for_preset
from services.midi_utils import quantize_notes
from services.storage_service import SupabaseStorageService


class ThemeStructureService:
    """Service for processing vocal input into MIDI theme structures."""

    def __init__(self, db: Session, storage: SupabaseStorageService):
        self.db = db
        self.storage = storage

    def process_vocal_to_theme(
        self,
        client: ApiClient,
        vocal_bytes: bytes,
        options: GenerateThemeStructureOptions,
        label: Optional[str] = None,
    ) -> ThemeStructureResult:
        """Process vocal audio into a theme with melody and chord MIDI files."""
        theme = Theme(client_id=client.id, label=label)
        self.db.add(theme)
        self.db.commit()
        self.db.refresh(theme)

        with tempfile.TemporaryDirectory() as tmpdir:
            audio_path = os.path.join(tmpdir, "vocal_theme.wav")
            with open(audio_path, "wb") as f:
                f.write(vocal_bytes)

            bp_out_dir = os.path.join(tmpdir, "bp_output")
            os.makedirs(bp_out_dir, exist_ok=True)

            predict_and_save(
                [audio_path],
                bp_out_dir,
                save_midi=True,
                save_model_outputs=False,
                sonify_midi=False,
            )

            midi_files = [f for f in os.listdir(bp_out_dir) if f.endswith(".mid")]
            if not midi_files:
                raise HTTPException(
                    status_code=500, detail="No MIDI produced by Basic Pitch."
                )
            raw_midi_path = os.path.join(bp_out_dir, midi_files[0])

            melody_pm = pretty_midi.PrettyMIDI(raw_midi_path)
            if not melody_pm.instruments:
                raise HTTPException(
                    status_code=500, detail="Empty MIDI from Basic Pitch."
                )
            melody_inst = melody_pm.instruments[0]
            quantize_notes(melody_inst, grid=options.grid)

            clean_melody_pm = pretty_midi.PrettyMIDI()
            clean_melody_pm.instruments.append(melody_inst)
            melody_clean_path = os.path.join(tmpdir, "melody_clean.mid")
            clean_melody_pm.write(melody_clean_path)

            melody_score = converter.parse(melody_clean_path)
            melody_part = melody_score.parts[0]
            key_guess = melody_part.analyze("key")
            chord_settings: ChordSettings = options.chord_settings

            chords_path = os.path.join(tmpdir, "chords.mid")

            if not chord_settings.enabled:
                empty_part = stream.Part()
                empty_part.write("midi", fp=chords_path)
            else:
                if chord_settings.custom_roman_progression:
                    roman_symbols = chord_settings.custom_roman_progression
                else:
                    roman_symbols = get_roman_progression_for_preset(
                        key_guess.mode,
                        chord_settings.progression_preset,
                    )

                length_q = melody_part.duration.quarterLength
                hr = chord_settings.harmonic_rhythm_quarters or 4.0
                num_chords = int(length_q // hr) + 1

                chord_stream = stream.Part()
                chord_stream.append(key_guess)

                for i in range(num_chords):
                    sym = roman_symbols[i % len(roman_symbols)]
                    rn = roman.RomanNumeral(sym, key_guess)

                    if chord_settings.complexity == ChordComplexity.extended:
                        pass  # Future: add extensions

                    c = rn.toChord()
                    c.duration.quarterLength = hr
                    chord_stream.append(c)

                chord_stream.write("midi", fp=chords_path)

            chords_pm = pretty_midi.PrettyMIDI(chords_path)
            combined_pm = pretty_midi.PrettyMIDI()
            combined_pm.instruments.append(clean_melody_pm.instruments[0])
            if chords_pm.instruments:
                combined_pm.instruments.append(chords_pm.instruments[0])

            combined_path = os.path.join(tmpdir, "theme_with_chords.mid")
            combined_pm.write(combined_path)

            vocal_url = self.storage.upload_theme_file(
                theme.id, "vocal_theme.wav", vocal_bytes
            )
            with open(melody_clean_path, "rb") as f:
                melody_bytes = f.read()
            with open(chords_path, "rb") as f:
                chords_bytes = f.read()
            with open(combined_path, "rb") as f:
                combined_bytes = f.read()

            melody_url = self.storage.upload_theme_file(
                theme.id, "melody_clean.mid", melody_bytes
            )
            chords_url = self.storage.upload_theme_file(
                theme.id, "chords.mid", chords_bytes
            )
            combined_url = self.storage.upload_theme_file(
                theme.id, "theme_with_chords.mid", combined_bytes
            )

        ts = ThemeStructure(
            theme_id=theme.id,
            client_id=client.id,
            input_audio_url=vocal_url,
            options_json=options.model_dump(),
            chord_settings_json=options.chord_settings.model_dump(),
            melody_midi_url=melody_url,
            chords_midi_url=chords_url,
            combined_midi_url=combined_url,
        )
        self.db.add(ts)
        self.db.commit()
        self.db.refresh(ts)

        return ThemeStructureResult(
            theme_id=theme.id,
            theme_structure_id=ts.id,
            melody_midi_url=melody_url,
            chords_midi_url=chords_url,
            combined_midi_url=combined_url,
        )
