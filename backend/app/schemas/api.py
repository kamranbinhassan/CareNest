from datetime import date, datetime
import re
from typing import Literal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class UserCreate(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=10, max_length=128)

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", normalized):
            raise ValueError("Enter a valid email address")
        return normalized


class LoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        return value.strip().lower()


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    email: str


class TokenOut(BaseModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int
    user: UserOut


class FamilyCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)

    @field_validator("name")
    @classmethod
    def trim_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Family name is required")
        return value


class FamilyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    created_at: datetime


class FamilyMemberCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    relationship_label: str = Field(default="Family member", min_length=1, max_length=40)

    @field_validator("name", "relationship_label")
    @classmethod
    def trim_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("This field is required")
        return value


class FamilyMemberOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    family_id: str
    name: str
    relationship_label: str
    created_at: datetime


class DoseTimeIn(BaseModel):
    hour: int = Field(ge=0, le=23)
    minute: int = Field(ge=0, le=59)


class ScheduleIn(BaseModel):
    frequency: Literal["Once daily", "Twice daily", "Three times daily", "Four times daily", "Every other day", "Weekly", "As needed"]
    start_date: date
    end_date: date | None = None
    dose_times: list[DoseTimeIn] = Field(default_factory=list, max_length=4)
    time_zone: str = Field(default="UTC", min_length=1, max_length=80)

    @model_validator(mode="after")
    def validate_schedule(self):
        if self.end_date and self.end_date < self.start_date:
            raise ValueError("End date cannot be before the start date")
        keys = [(item.hour, item.minute) for item in self.dose_times]
        if len(keys) != len(set(keys)):
            raise ValueError("Dose times must be unique")
        if self.frequency == "As needed" and self.dose_times:
            raise ValueError("As-needed plans cannot contain scheduled dose times")
        if self.frequency != "As needed" and not self.dose_times:
            raise ValueError("A fixed schedule requires at least one dose time")
        try:
            ZoneInfo(self.time_zone)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("Unknown IANA time zone") from exc
        return self


class MedicineCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    dosage: str = Field(min_length=1, max_length=80)
    form: str = Field(min_length=1, max_length=40)
    dose_amount: str = Field(min_length=1, max_length=40)
    food_instruction: str = Field(default="No food instruction", max_length=80)
    instructions: str = Field(default="", max_length=500)
    schedule: ScheduleIn

    @field_validator("name", "dosage", "form", "dose_amount", "food_instruction")
    @classmethod
    def trim_required(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("This field is required")
        return value


class ScheduleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    frequency: str
    start_date: date
    end_date: date | None
    dose_times: list[dict]
    time_zone: str


class MedicineOut(BaseModel):
    id: str
    member_id: str
    name: str
    dosage: str
    form: str
    dose_amount: str
    food_instruction: str
    instructions: str
    created_at: datetime
    schedule: ScheduleOut


class MedicineUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    dosage: str | None = Field(default=None, min_length=1, max_length=80)
    form: str | None = Field(default=None, min_length=1, max_length=40)
    dose_amount: str | None = Field(default=None, min_length=1, max_length=40)
    food_instruction: str | None = Field(default=None, max_length=80)
    instructions: str | None = Field(default=None, max_length=500)


class OccurrenceOut(BaseModel):
    id: str
    schedule_id: str
    medicine_id: str
    medicine_name: str
    member_id: str
    member_name: str
    scheduled_at: datetime
    status: Literal["taken", "missed", "overdue", "pending"]
    event_id: str | None = None
    recorded_at: datetime | None = None


class DoseEventCreate(BaseModel):
    status: Literal["taken", "missed"]


class DoseEventOut(BaseModel):
    id: str
    occurrence_id: str
    status: Literal["taken", "missed"]
    scheduled_at: datetime
    recorded_at: datetime


class CountSummary(BaseModel):
    scheduled: int
    taken: int
    missed: int
    overdue: int
    pending: int
    adherence_percent: int | None


class MedicineAdherenceOut(BaseModel):
    medicine_id: str
    medicine_name: str
    counts: CountSummary


class AdherenceOut(BaseModel):
    family_id: str
    from_date: date
    through_date: date
    counts: CountSummary
    medicines: list[MedicineAdherenceOut]
