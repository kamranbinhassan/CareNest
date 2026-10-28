import importlib
from pathlib import Path

import pytest
from sqlalchemy.engine import make_url

from app.core import config


@pytest.mark.skipif(
    not (Path(__file__).resolve().parents[1] / ".env").exists(),
    reason="local .env precedence is only testable in a configured checkout",
)
def test_local_dotenv_overrides_stale_exported_database_url(monkeypatch):
    monkeypatch.setenv("APP_ENV", "development")
    monkeypatch.setenv(
        "DATABASE_URL",
        "postgresql+psycopg://medication_app:dummy-not-secret@127.0.0.1:5432/medicine_adherence",
    )
    local_config = importlib.reload(config)
    effective = make_url(local_config.get_settings().database_url)
    assert effective.username == "medicine_app"
    assert effective.database == "medicine_adherence"
    assert effective.host == "127.0.0.1"
    assert effective.port == 5432
