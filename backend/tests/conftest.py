import sys
from pathlib import Path

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

BACKEND_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_ROOT))


@pytest.fixture
def db(tmp_path, monkeypatch):
    database_path = tmp_path / "api-test.sqlite3"
    monkeypatch.setenv("DATABASE_URL", f"sqlite+pysqlite:///{database_path}")
    monkeypatch.setenv("JWT_SECRET_KEY", "test-secret-key-that-is-at-least-32-characters-long")
    monkeypatch.setenv("JWT_ACCESS_TOKEN_MINUTES", "30")

    from app.db.base import Base
    from app.db.session import clear_engine_cache
    from app.models import entities  # noqa: F401

    clear_engine_cache()
    engine = create_engine(
        f"sqlite+pysqlite:///{database_path}",
        connect_args={"check_same_thread": False},
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, expire_on_commit=False)
    with factory() as session:
        yield session
    clear_engine_cache()
    engine.dispose()
