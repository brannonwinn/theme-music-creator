from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import relationship

from database.session import Base


class Variation(Base):
    """Variation model storing AI-generated theme variations."""

    __tablename__ = "variations"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    theme_id = Column(String, ForeignKey("themes.id"), nullable=False)
    client_id = Column(String, ForeignKey("api_clients.id"), nullable=True)

    base_render_id = Column(String, ForeignKey("base_renders.id"), nullable=True)

    prompt = Column(Text, nullable=False)
    length_seconds = Column(Integer, nullable=False)
    seed = Column(Integer, nullable=True)

    variation_audio_url = Column(Text, nullable=False)
    base_theme_url = Column(Text, nullable=True)

    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    theme = relationship("Theme", back_populates="variations")
    client = relationship("ApiClient")
    base_render = relationship("BaseRender", back_populates="variations")
