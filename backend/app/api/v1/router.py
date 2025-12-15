from fastapi import APIRouter

from api.v1 import render, structure, variations


router = APIRouter()

router.include_router(structure.router, prefix="/themes", tags=["themes"])
router.include_router(render.router, prefix="/themes", tags=["themes"])
router.include_router(variations.router, prefix="/themes", tags=["themes"])
