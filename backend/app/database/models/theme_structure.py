from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Column, DateTime, ForeignKey, JSON, String, Text, func
from sqlalchemy.orm import relationship

from database.session import Base


class ThemeStructure(Base):
    """Theme Structure model storing MIDI and audio structure data."""

    __tablename__ = "theme_structures"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    theme_id = Column(String, ForeignKey("themes.id"), nullable=False)
    client_id = Column(String, ForeignKey("api_clients.id"), nullable=True)

    input_audio_url = Column(Text, nullable=False)

    options_json = Column(JSON, nullable=False)
    chord_settings_json = Column(JSON, nullable=False)

    melody_midi_url = Column(Text, nullable=False)
    chords_midi_url = Column(Text, nullable=False)
    combined_midi_url = Column(Text, nullable=False)

    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    theme = relationship("Theme", back_populates="structures")
    client = relationship("ApiClient")
