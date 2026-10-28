"""Initial relational schema for account-backed care data.

Revision ID: 0001_initial_schema
Revises:
"""
from alembic import op

from app.db.base import Base
from app.models import entities  # noqa: F401

revision = "0001_initial_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # create_all creates missing objects and leaves existing tables/data intact.
    Base.metadata.create_all(bind=op.get_bind(), checkfirst=True)


def downgrade() -> None:
    raise RuntimeError("Automatic downgrade is disabled because dropping these tables would destroy account data. Back up and plan a manual migration.")
