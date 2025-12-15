from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Column, DateTime, String, func
from sqlalchemy.orm import relationship

from database.session import Base


class ApiClient(Base):
    """API Client model for managing client authentication and access."""

    __tablename__ = "api_clients"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    name = Column(String, nullable=False)
    api_key = Column(String, unique=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    themes = relationship("Theme", back_populates="client")
