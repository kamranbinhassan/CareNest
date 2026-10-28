from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.db.base import Base
from app.models.entities import Family, FamilyMember, Medicine, MedicationSchedule
from app.services.occurrences import occurs_on, occurrences_for_period, scheduled_datetime, summarize_occurrences


def test_adherence_counts_exclude_pending_and_overdue():
    summary = summarize_occurrences([
        (None, "taken"), (None, "missed"), (None, "overdue"), (None, "pending"),
    ])
    assert summary.scheduled == 4
    assert summary.taken == 1
    assert summary.missed == 1
    assert summary.overdue == 1
    assert summary.pending == 1
    assert summary.adherence_percent == 50


def test_no_actioned_occurrences_has_no_percentage():
    summary = summarize_occurrences([(None, "pending"), (None, "overdue")])
    assert summary.adherence_percent is None


def test_frequency_and_nonexistent_dst_time():
    start = date(2026, 1, 5)  # Monday
    assert occurs_on("Weekly", start, date(2026, 1, 12))
    assert not occurs_on("Weekly", start, date(2026, 1, 13))
    assert occurs_on("Every other day", start, date(2026, 1, 7))
    assert not occurs_on("As needed", start, date(2026, 1, 5))
    # 02:30 does not exist during New York's spring-forward transition.
    assert scheduled_datetime(date(2026, 3, 8), 2, 30, ZoneInfo("America/New_York")) is None


def test_occurrences_are_persisted_once_and_future_doses_stay_pending():
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        family = Family(name="Demo")
        member = FamilyMember(family=family, name="Alex", relationship_label="Self")
        medicine = Medicine(member=member, name="Sample", dosage="1 tablet", form="Tablet", dose_amount="1")
        medicine.schedule = MedicationSchedule(
            frequency="Once daily", start_date=date(2026, 5, 2), end_date=None,
            dose_times=[{"hour": 15, "minute": 0}], time_zone="UTC",
        )
        db.add(family)
        db.commit()
        first = occurrences_for_period(db, member.id, date(2026, 5, 2), date(2026, 5, 2), datetime(2026, 5, 2, 12, tzinfo=timezone.utc))
        second = occurrences_for_period(db, member.id, date(2026, 5, 2), date(2026, 5, 2), datetime(2026, 5, 2, 12, tzinfo=timezone.utc))
        assert len(first) == 1
        assert len(second) == 1
        assert first[0][0].id == second[0][0].id
        assert first[0][1] == "pending"
    engine.dispose()
