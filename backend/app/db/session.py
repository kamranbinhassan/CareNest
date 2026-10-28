from functools import lru_cache

from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import get_settings


@lru_cache(maxsize=4)
def _session_factory(database_url: str) -> sessionmaker[Session]:
    engine_options = {"pool_pre_ping": True, "future": True}
    if database_url.startswith("sqlite"):
        engine_options["connect_args"] = {"check_same_thread": False}
        if ":memory:" in database_url:
            engine_options["poolclass"] = StaticPool
    engine = create_engine(database_url, **engine_options)
    return sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db():
    settings = get_settings()
    if not settings.database_url:
        raise RuntimeError("DATABASE_URL is not configured")
    factory = _session_factory(settings.database_url)
    with factory() as session:
        yield session


def check_database() -> bool:
    settings = get_settings()
    if not settings.database_url:
        return False
    from sqlalchemy import text
    factory = _session_factory(settings.database_url)
    with factory() as session:
        session.execute(text("SELECT 1"))
    return True


def clear_engine_cache() -> None:
    _session_factory.cache_clear()
