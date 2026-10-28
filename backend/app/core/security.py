from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError, VerificationError
from fastapi import HTTPException, status

from app.core.config import get_settings

ALGORITHM = "HS256"
# Argon2id defaults: at least 19 MiB with two iterations; predictable on small hosts.
_password_hasher = PasswordHasher(time_cost=2, memory_cost=19456, parallelism=1)


def hash_password(password: str) -> str:
    return _password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _password_hasher.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError):
        return False


def create_access_token(user_id: str) -> tuple[str, int]:
    settings = get_settings()
    if not settings.jwt_secret_key or len(settings.jwt_secret_key) < 32:
        raise RuntimeError("JWT_SECRET_KEY must be configured with at least 32 characters")
    if settings.jwt_access_token_minutes < 1:
        raise RuntimeError("JWT_ACCESS_TOKEN_MINUTES must be greater than zero")
    expires_in = settings.jwt_access_token_minutes * 60
    now = datetime.now(timezone.utc)
    token = jwt.encode({"sub": user_id, "iat": now, "exp": now + timedelta(seconds=expires_in)}, settings.jwt_secret_key, algorithm=ALGORITHM)
    return token, expires_in


def decode_access_token(token: str) -> str:
    settings = get_settings()
    if not settings.jwt_secret_key or len(settings.jwt_secret_key) < 32:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Authentication is not configured")
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[ALGORITHM], options={"require": ["exp", "sub"]})
        return str(payload["sub"])
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(status_code=401, detail="Access token expired", headers={"WWW-Authenticate": "Bearer"}) from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(status_code=401, detail="Invalid access token", headers={"WWW-Authenticate": "Bearer"}) from exc
