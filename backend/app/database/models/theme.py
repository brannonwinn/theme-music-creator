from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Column, DateTime, ForeignKey, String, func
from sqlalchemy.orm import relationship

from database.session import Base


class Theme(Base):
    """Theme model representing a musical theme project."""

    __tablename__ = "themes"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    client_id = Column(String, ForeignKey("api_clients.id"), nullable=True)
    label = Column(String, nullable=True)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    client = relationship("ApiClient", back_populates="themes")
    structures = relationship("ThemeStructure", back_populates="theme")
    base_renders = relationship("BaseRender", back_populates="theme")
    variations = relationship("Variation", back_populates="theme")
