"""Static bearer-token authentication for all non-health endpoints."""

import os

from fastapi import Header, HTTPException


async def require_auth(authorization: str | None = Header(default=None)) -> None:
    """FastAPI dependency that validates the Bearer token.

    The header is declared optional so a missing token yields a 401 (not FastAPI's
    default 422 for a required-but-absent header).

    :raises HTTPException 401: if the token is missing or wrong.
    """
    secret = os.environ.get("API_SECRET")
    if not secret:
        return  # auth disabled in dev if env var not set
    if authorization != f"Bearer {secret}":
        raise HTTPException(401, "Unauthorized")
