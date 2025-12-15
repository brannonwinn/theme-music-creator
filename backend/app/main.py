from fastapi import FastAPI

from api.router import router as process_router
from api.v1.router import router as v1_router
from database.session import Base, engine

# Import models to register them with Base before creating tables
from database.models import ApiClient, BaseRender, Theme, ThemeStructure, Variation  # noqa: F401

# Create all database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Thematic Music Pipeline API")

# Event processing routes (existing)
app.include_router(process_router)

# Theme music API v1 routes
app.include_router(v1_router, prefix="/api/v1")
