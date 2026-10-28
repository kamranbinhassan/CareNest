from dataclasses import dataclass
import os
from pathlib import Path

from dotenv import load_dotenv

BACKEND_DIR = Path(__file__).resolve().parents[2]
ENV_FILE = BACKEND_DIR / ".env"

# In local development, the project .env is authoritative. This prevents a
# stale DATABASE_URL exported by an old shell from silently selecting another
# database role. Deployments can set APP_ENV=production to use process-level
# environment variables instead; production should not ship a .env file.
APP_ENV = os.getenv("APP_ENV", "development").strip().lower()
load_dotenv(ENV_FILE, override=APP_ENV not in {"production", "prod"})


@dataclass(frozen=True)
class Settings:
    database_url: str | None
    jwt_secret_key: str | None
    jwt_access_token_minutes: int
    allowed_origins: tuple[str, ...]


def get_settings() -> Settings:
    origins = tuple(origin.strip() for origin in os.getenv("ALLOWED_ORIGINS", "").split(",") if origin.strip())
    try:
        lifetime = int(os.getenv("JWT_ACCESS_TOKEN_MINUTES", "30"))
    except ValueError as exc:
        raise RuntimeError("JWT_ACCESS_TOKEN_MINUTES must be an integer") from exc
    return Settings(
        database_url=os.getenv("DATABASE_URL") or None,
        jwt_secret_key=os.getenv("JWT_SECRET_KEY") or None,
        jwt_access_token_minutes=lifetime,
        allowed_origins=origins,
    )
