from typing import Optional

from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session

from database.models import ApiClient
from database.session import db_session


class AuthorizationService:
    """Service for API key authorization."""

    def __init__(self, db: Session):
        self.db = db

    def authorize(self, api_key: Optional[str]) -> ApiClient:
        """Validate API key and return the associated client."""
        if not api_key:
            raise HTTPException(status_code=401, detail="Missing API key")
        client = (
            self.db.query(ApiClient)
            .filter(ApiClient.api_key == api_key)
            .first()
        )
        if not client:
            raise HTTPException(status_code=403, detail="Invalid API key")
        return client


def get_authorization_service(db: Session = Depends(db_session)) -> AuthorizationService:
    """Dependency to get an AuthorizationService instance."""
    return AuthorizationService(db)


def get_current_client(
    x_api_key: Optional[str] = Header(default=None, alias="X-API-Key"),
    auth: AuthorizationService = Depends(get_authorization_service),
) -> ApiClient:
    """FastAPI dependency to get the current authenticated API client."""
    return auth.authorize(x_api_key)
