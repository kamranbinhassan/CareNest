from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.models.entities import DoseEvent, FamilyMember, Medicine, MedicationSchedule, ScheduledDoseOccurrence
from app.schemas.api import CountSummary, OccurrenceOut

MAX_OCCURRENCE_WINDOW_DAYS = 180


def utc_aware(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def occurs_on(frequency: str, start: date, day: date) -> bool:
    if frequency == "As needed":
        return False
    if frequency == "Every other day":
        return (day - start).days % 2 == 0
    if frequency == "Weekly":
        return day.weekday() == start.weekday()
    return True


def scheduled_datetime(day: date, hour: int, minute: int, zone: ZoneInfo) -> datetime | None:
    wall_time = datetime.combine(day, time(hour=hour, minute=minute))
    local = wall_time.replace(tzinfo=zone, fold=0)
    utc_value = local.astimezone(timezone.utc)
    # Skip wall-clock times that do not exist during a forward DST change.
    if utc_value.astimezone(zone).replace(tzinfo=None) != wall_time:
        return None
    return utc_value


def _schedule_for_member(db: Session, member_id: str) -> list[MedicationSchedule]:
    return list(db.scalars(
        select(MedicationSchedule)
        .join(Medicine)
        .where(Medicine.member_id == member_id)
        .options(joinedload(MedicationSchedule.medicine).joinedload(Medicine.member))
    ).unique())


def ensure_occurrences(db: Session, member_id: str, from_date: date, through_date: date) -> list[ScheduledDoseOccurrence]:
    if through_date < from_date:
        raise ValueError("through_date must be on or after from_date")
    if (through_date - from_date).days > MAX_OCCURRENCE_WINDOW_DAYS:
        raise ValueError(f"Date range cannot exceed {MAX_OCCURRENCE_WINDOW_DAYS} days")
    for schedule in _schedule_for_member(db, member_id):
        medicine = schedule.medicine
        if from_date < schedule.start_date:
            first_day = schedule.start_date
        else:
            first_day = from_date
        last_day = through_date if schedule.end_date is None else min(through_date, schedule.end_date)
        if medicine.deactivated_at is not None:
            deactivated_local_date = utc_aware(medicine.deactivated_at).astimezone(ZoneInfo(schedule.time_zone)).date()
            last_day = min(last_day, deactivated_local_date)
        if schedule.end_date is not None:
            last_day = min(last_day, schedule.end_date)
        if last_day < first_day:
            continue
        zone = ZoneInfo(schedule.time_zone)
        day = first_day
        while day <= last_day:
            if occurs_on(schedule.frequency, schedule.start_date, day):
                for dose_time in schedule.dose_times:
                    scheduled_at = scheduled_datetime(day, int(dose_time["hour"]), int(dose_time["minute"]), zone)
                    if scheduled_at is None:
                        continue
                    exists = db.scalar(select(ScheduledDoseOccurrence.id).where(ScheduledDoseOccurrence.schedule_id == schedule.id, ScheduledDoseOccurrence.scheduled_at == scheduled_at))
                    if exists is None:
                        try:
                            with db.begin_nested():
                                db.add(ScheduledDoseOccurrence(schedule_id=schedule.id, scheduled_at=scheduled_at))
                                db.flush()
                        except IntegrityError:
                            # Another request generated this unique schedule/time first.
                            pass
            day += timedelta(days=1)
    db.flush()
    return list(db.scalars(
        select(ScheduledDoseOccurrence)
        .join(MedicationSchedule)
        .where(MedicationSchedule.medicine_id.in_(select(Medicine.id).where(Medicine.member_id == member_id)))
        .options(joinedload(ScheduledDoseOccurrence.event), joinedload(ScheduledDoseOccurrence.schedule).joinedload(MedicationSchedule.medicine).joinedload(Medicine.member))
        .order_by(ScheduledDoseOccurrence.scheduled_at)
    ).unique())


def occurrences_for_period(db: Session, member_id: str, from_date: date, through_date: date, now: datetime | None = None) -> list[tuple[ScheduledDoseOccurrence, str]]:
    now = utc_aware(now or datetime.now(timezone.utc))
    generated = ensure_occurrences(db, member_id, from_date, through_date)
    result = []
    for occurrence in generated:
        schedule = occurrence.schedule
        local_day = utc_aware(occurrence.scheduled_at).astimezone(ZoneInfo(schedule.time_zone)).date()
        if local_day < from_date or local_day > through_date:
            continue
        if occurrence.event is not None:
            status = occurrence.event.status
        elif utc_aware(occurrence.scheduled_at) > now:
            status = "pending"
        else:
            status = "overdue"
        result.append((occurrence, status))
    return result


def occurrence_response(occurrence: ScheduledDoseOccurrence, status: str) -> OccurrenceOut:
    medicine = occurrence.schedule.medicine
    member = medicine.member
    event = occurrence.event
    return OccurrenceOut(
        id=occurrence.id,
        schedule_id=occurrence.schedule_id,
        medicine_id=medicine.id,
        medicine_name=medicine.name,
        member_id=member.id,
        member_name=member.name,
        scheduled_at=utc_aware(occurrence.scheduled_at),
        status=status,
        event_id=event.id if event else None,
        recorded_at=utc_aware(event.recorded_at) if event else None,
    )


def summarize_occurrences(rows: list[tuple[ScheduledDoseOccurrence, str]]) -> CountSummary:
    counts = {key: 0 for key in ("taken", "missed", "overdue", "pending")}
    for _, status in rows:
        counts[status] += 1
    actioned = counts["taken"] + counts["missed"]
    return CountSummary(
        scheduled=len(rows),
        taken=counts["taken"],
        missed=counts["missed"],
        overdue=counts["overdue"],
        pending=counts["pending"],
        adherence_percent=round(counts["taken"] * 100 / actioned) if actioned else None,
    )
