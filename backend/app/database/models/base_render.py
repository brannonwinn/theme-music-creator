from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Column, DateTime, ForeignKey, JSON, String, Text, func
from sqlalchemy.orm import relationship

from database.session import Base


class BaseRender(Base):
    """Base Render model storing rendered theme audio with preset configurations."""

    __tablename__ = "base_renders"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    theme_id = Column(String, ForeignKey("themes.id"), nullable=False)
    client_id = Column(String, ForeignKey("api_clients.id"), nullable=True)

    theme_structure_id = Column(
        String, ForeignKey("theme_structures.id"), nullable=True
    )

    preset = Column(String, nullable=False)
    overrides_json = Column(JSON, nullable=False)
    effective_config_json = Column(JSON, nullable=False)

    base_theme_url = Column(Text, nullable=False)

    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    theme = relationship("Theme", back_populates="base_renders")
    client = relationship("ApiClient")
    theme_structure = relationship("ThemeStructure")
    variations = relationship("Variation", back_populates="base_render")
