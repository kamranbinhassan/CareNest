from datetime import date, datetime, time, timezone
from uuid import uuid4

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Index, JSON, String, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


def new_id() -> str:
    return str(uuid4())


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(512), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    memberships: Mapped[list["FamilyMembership"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class Family(Base):
    __tablename__ = "families"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    memberships: Mapped[list["FamilyMembership"]] = relationship(back_populates="family", cascade="all, delete-orphan")
    members: Mapped[list["FamilyMember"]] = relationship(back_populates="family", cascade="all, delete-orphan")


class FamilyMembership(Base):
    __tablename__ = "family_memberships"
    __table_args__ = (UniqueConstraint("family_id", "user_id", name="uq_family_membership"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    family_id: Mapped[str] = mapped_column(ForeignKey("families.id", ondelete="CASCADE"), index=True, nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    role: Mapped[str] = mapped_column(String(20), default="owner", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    family: Mapped[Family] = relationship(back_populates="memberships")
    user: Mapped[User] = relationship(back_populates="memberships")


class FamilyMember(Base):
    __tablename__ = "family_members"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    family_id: Mapped[str] = mapped_column(ForeignKey("families.id", ondelete="CASCADE"), index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    relationship_label: Mapped[str] = mapped_column(String(40), default="Family member", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    family: Mapped[Family] = relationship(back_populates="members")
    medicines: Mapped[list["Medicine"]] = relationship(back_populates="member", cascade="all, delete-orphan")


class Medicine(Base):
    __tablename__ = "medicines"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    member_id: Mapped[str] = mapped_column(ForeignKey("family_members.id", ondelete="CASCADE"), index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    dosage: Mapped[str] = mapped_column(String(80), nullable=False)
    form: Mapped[str] = mapped_column(String(40), nullable=False)
    dose_amount: Mapped[str] = mapped_column(String(40), nullable=False)
    food_instruction: Mapped[str] = mapped_column(String(80), default="No food instruction", nullable=False)
    instructions: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    deactivated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    member: Mapped[FamilyMember] = relationship(back_populates="medicines")
    schedule: Mapped["MedicationSchedule"] = relationship(back_populates="medicine", cascade="all, delete-orphan", uselist=False)


class MedicationSchedule(Base):
    __tablename__ = "medication_schedules"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    medicine_id: Mapped[str] = mapped_column(ForeignKey("medicines.id", ondelete="CASCADE"), unique=True, index=True, nullable=False)
    frequency: Mapped[str] = mapped_column(String(40), nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    dose_times: Mapped[list[dict]] = mapped_column(JSON, nullable=False)
    time_zone: Mapped[str] = mapped_column(String(80), default="UTC", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    medicine: Mapped[Medicine] = relationship(back_populates="schedule")
    occurrences: Mapped[list["ScheduledDoseOccurrence"]] = relationship(back_populates="schedule", cascade="all, delete-orphan")


class ScheduledDoseOccurrence(Base):
    __tablename__ = "scheduled_dose_occurrences"
    __table_args__ = (UniqueConstraint("schedule_id", "scheduled_at", name="uq_schedule_occurrence"), Index("ix_occurrence_scheduled_at", "scheduled_at"))
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    schedule_id: Mapped[str] = mapped_column(ForeignKey("medication_schedules.id", ondelete="CASCADE"), index=True, nullable=False)
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    schedule: Mapped[MedicationSchedule] = relationship(back_populates="occurrences")
    event: Mapped["DoseEvent | None"] = relationship(back_populates="occurrence", cascade="all, delete-orphan", uselist=False)


class DoseEvent(Base):
    __tablename__ = "dose_events"
    __table_args__ = (UniqueConstraint("occurrence_id", name="uq_event_occurrence"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    occurrence_id: Mapped[str] = mapped_column(ForeignKey("scheduled_dose_occurrences.id", ondelete="CASCADE"), index=True, nullable=False)
    status: Mapped[str] = mapped_column(String(10), nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    occurrence: Mapped[ScheduledDoseOccurrence] = relationship(back_populates="event")
