from datetime import date, datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.api.dependencies import authorized_family, authorized_member, current_user, database_session
from app.core.config import get_settings
from app.core.security import create_access_token, hash_password, verify_password
from app.models.entities import DoseEvent, Family, FamilyMember, FamilyMembership, Medicine, MedicationSchedule, ScheduledDoseOccurrence, User
from app.schemas.api import AdherenceOut, CountSummary, DoseEventCreate, DoseEventOut, FamilyCreate, FamilyMemberCreate, FamilyMemberOut, FamilyOut, LoginRequest, MedicineAdherenceOut, MedicineCreate, MedicineOut, MedicineUpdate, OccurrenceOut, TokenOut, UserCreate, UserOut
from app.services.occurrences import MAX_OCCURRENCE_WINDOW_DAYS, occurrence_response, occurrences_for_period, summarize_occurrences, utc_aware

router = APIRouter()


def _new_token(user: User) -> TokenOut:
    try:
        token, expires_in = create_access_token(user.id)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return TokenOut(access_token=token, expires_in=expires_in, user=UserOut.model_validate(user))


@router.post("/auth/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def register(payload: UserCreate, db: Session = Depends(database_session)):
    configured_secret = get_settings().jwt_secret_key
    if not configured_secret or len(configured_secret) < 32:
        raise HTTPException(status_code=503, detail="JWT_SECRET_KEY must be configured with at least 32 characters")
    user = User(id=str(uuid4()), email=payload.email, password_hash=hash_password(payload.password))
    db.add(user)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="An account with this email already exists") from exc
    db.refresh(user)
    return _new_token(user)


@router.post("/auth/login", response_model=TokenOut)
def login(payload: LoginRequest, db: Session = Depends(database_session)):
    # Keep the login body JSON-based; avoid logging credentials through form parsing.
    email = payload.email
    password = payload.password
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email or password is incorrect", headers={"WWW-Authenticate": "Bearer"})
    return _new_token(user)


@router.get("/auth/me", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return user


@router.get("/families", response_model=list[FamilyOut])
def list_families(db: Session = Depends(database_session), user: User = Depends(current_user)):
    return list(db.scalars(select(Family).join(FamilyMembership).where(FamilyMembership.user_id == user.id).order_by(Family.created_at)))


@router.post("/families", response_model=FamilyOut, status_code=status.HTTP_201_CREATED)
def create_family(payload: FamilyCreate, db: Session = Depends(database_session), user: User = Depends(current_user)):
    family = Family(id=str(uuid4()), name=payload.name)
    db.add(family)
    db.flush()
    db.add(FamilyMembership(id=str(uuid4()), family_id=family.id, user_id=user.id, role="owner"))
    db.commit()
    db.refresh(family)
    return family


@router.get("/families/{family_id}/members", response_model=list[FamilyMemberOut])
def list_members(family_id: str, db: Session = Depends(database_session), user: User = Depends(current_user)):
    authorized_family(db, user, family_id)
    return list(db.scalars(select(FamilyMember).where(FamilyMember.family_id == family_id).order_by(FamilyMember.created_at)))


@router.post("/families/{family_id}/members", response_model=FamilyMemberOut, status_code=status.HTTP_201_CREATED)
def create_member(family_id: str, payload: FamilyMemberCreate, db: Session = Depends(database_session), user: User = Depends(current_user)):
    authorized_family(db, user, family_id)
    member = FamilyMember(id=str(uuid4()), family_id=family_id, name=payload.name, relationship_label=payload.relationship_label)
    db.add(member)
    db.commit()
    db.refresh(member)
    return member


@router.get("/members/{member_id}/medicines", response_model=list[MedicineOut])
def list_medicines(member_id: str, db: Session = Depends(database_session), user: User = Depends(current_user)):
    authorized_member(db, user, member_id)
    return list(db.scalars(select(Medicine).where(Medicine.member_id == member_id, Medicine.deactivated_at.is_(None)).options(joinedload(Medicine.schedule)).order_by(Medicine.created_at)))


@router.post("/members/{member_id}/medicines", response_model=MedicineOut, status_code=status.HTTP_201_CREATED)
def create_medicine(member_id: str, payload: MedicineCreate, db: Session = Depends(database_session), user: User = Depends(current_user)):
    authorized_member(db, user, member_id)
    medicine = Medicine(id=str(uuid4()), member_id=member_id, name=payload.name, dosage=payload.dosage, form=payload.form, dose_amount=payload.dose_amount, food_instruction=payload.food_instruction, instructions=payload.instructions)
    schedule = MedicationSchedule(id=str(uuid4()), frequency=payload.schedule.frequency, start_date=payload.schedule.start_date, end_date=payload.schedule.end_date, dose_times=[item.model_dump() for item in payload.schedule.dose_times], time_zone=payload.schedule.time_zone)
    medicine.schedule = schedule
    db.add(medicine)
    db.commit()
    db.refresh(medicine)
    return medicine


@router.get("/medicines/{medicine_id}", response_model=MedicineOut)
def get_medicine(medicine_id: str, db: Session = Depends(database_session), user: User = Depends(current_user)):
    medicine = db.scalar(select(Medicine).where(Medicine.id == medicine_id, Medicine.deactivated_at.is_(None)).options(joinedload(Medicine.member), joinedload(Medicine.schedule)))
    if medicine is None:
        raise HTTPException(status_code=404, detail="Medicine plan not found")
    authorized_member(db, user, medicine.member_id)
    return medicine


@router.patch("/medicines/{medicine_id}", response_model=MedicineOut)
def update_medicine(medicine_id: str, payload: MedicineUpdate, db: Session = Depends(database_session), user: User = Depends(current_user)):
    medicine = db.scalar(select(Medicine).where(Medicine.id == medicine_id, Medicine.deactivated_at.is_(None)).options(joinedload(Medicine.schedule)))
    if medicine is None:
        raise HTTPException(status_code=404, detail="Medicine plan not found")
    authorized_member(db, user, medicine.member_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(medicine, field, value.strip() if isinstance(value, str) else value)
    db.commit()
    db.refresh(medicine)
    return medicine


@router.delete("/medicines/{medicine_id}", status_code=status.HTTP_204_NO_CONTENT)
def deactivate_medicine(medicine_id: str, db: Session = Depends(database_session), user: User = Depends(current_user)):
    medicine = db.scalar(select(Medicine).where(Medicine.id == medicine_id, Medicine.deactivated_at.is_(None)))
    if medicine is None:
        raise HTTPException(status_code=404, detail="Medicine plan not found")
    authorized_member(db, user, medicine.member_id)
    medicine.deactivated_at = datetime.now(timezone.utc)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


def _validated_range(from_date: date, through_date: date) -> None:
    if through_date < from_date:
        raise HTTPException(status_code=422, detail="through_date must be on or after from_date")
    if (through_date - from_date).days > MAX_OCCURRENCE_WINDOW_DAYS:
        raise HTTPException(status_code=422, detail=f"Date range cannot exceed {MAX_OCCURRENCE_WINDOW_DAYS} days")


@router.get("/members/{member_id}/occurrences", response_model=list[OccurrenceOut])
def list_occurrences(member_id: str, from_date: date = Query(), through_date: date = Query(), db: Session = Depends(database_session), user: User = Depends(current_user)):
    authorized_member(db, user, member_id)
    _validated_range(from_date, through_date)
    rows = occurrences_for_period(db, member_id, from_date, through_date)
    return [occurrence_response(occurrence, dose_status) for occurrence, dose_status in rows]


def _authorized_occurrence(db: Session, user: User, occurrence_id: str) -> ScheduledDoseOccurrence:
    occurrence = db.scalar(select(ScheduledDoseOccurrence).where(ScheduledDoseOccurrence.id == occurrence_id).options(joinedload(ScheduledDoseOccurrence.schedule).joinedload(MedicationSchedule.medicine)))
    if occurrence is None:
        raise HTTPException(status_code=404, detail="Scheduled dose not found")
    authorized_member(db, user, occurrence.schedule.medicine.member_id)
    if occurrence.schedule.medicine.deactivated_at is not None and utc_aware(occurrence.scheduled_at) > utc_aware(occurrence.schedule.medicine.deactivated_at):
        raise HTTPException(status_code=409, detail="This medicine plan was removed before the scheduled dose")
    if utc_aware(occurrence.scheduled_at) > datetime.now(timezone.utc):
        raise HTTPException(status_code=409, detail="Future doses cannot be recorded early")
    return occurrence


def _event_response(event: DoseEvent) -> DoseEventOut:
    return DoseEventOut(id=event.id, occurrence_id=event.occurrence_id, status=event.status, scheduled_at=utc_aware(event.occurrence.scheduled_at), recorded_at=utc_aware(event.recorded_at))


@router.post("/occurrences/{occurrence_id}/events", response_model=DoseEventOut, status_code=status.HTTP_201_CREATED)
def record_dose(occurrence_id: str, payload: DoseEventCreate, response: Response, db: Session = Depends(database_session), user: User = Depends(current_user)):
    occurrence = _authorized_occurrence(db, user, occurrence_id)
    if occurrence.event is not None:
        if occurrence.event.status == payload.status:
            response.status_code = status.HTTP_200_OK
            return _event_response(occurrence.event)
        raise HTTPException(status_code=409, detail="A dose event already exists; use PUT to correct it")
    event = DoseEvent(id=str(uuid4()), occurrence_id=occurrence.id, status=payload.status, recorded_at=datetime.now(timezone.utc))
    db.add(event)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="A dose event already exists for this occurrence") from exc
    db.refresh(event)
    db.refresh(occurrence)
    return _event_response(event)


@router.put("/occurrences/{occurrence_id}/events", response_model=DoseEventOut)
def correct_dose(occurrence_id: str, payload: DoseEventCreate, db: Session = Depends(database_session), user: User = Depends(current_user)):
    occurrence = _authorized_occurrence(db, user, occurrence_id)
    if occurrence.event is None:
        raise HTTPException(status_code=404, detail="No dose event exists to correct")
    occurrence.event.status = payload.status
    occurrence.event.recorded_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(occurrence.event)
    return _event_response(occurrence.event)


@router.get("/families/{family_id}/adherence", response_model=AdherenceOut)
def family_adherence(family_id: str, from_date: date = Query(), through_date: date = Query(), db: Session = Depends(database_session), user: User = Depends(current_user)):
    authorized_family(db, user, family_id)
    _validated_range(from_date, through_date)
    members = list(db.scalars(select(FamilyMember).where(FamilyMember.family_id == family_id)))
    all_rows = []
    by_medicine: dict[str, tuple[str, list]] = {}
    for member in members:
        rows = occurrences_for_period(db, member.id, from_date, through_date)
        all_rows.extend(rows)
        for occurrence, dose_status in rows:
            medicine = occurrence.schedule.medicine
            by_medicine.setdefault(medicine.id, (medicine.name, []))[1].append((occurrence, dose_status))
    return AdherenceOut(
        family_id=family_id,
        from_date=from_date,
        through_date=through_date,
        counts=summarize_occurrences(all_rows),
        medicines=[MedicineAdherenceOut(medicine_id=medicine_id, medicine_name=name, counts=summarize_occurrences(rows)) for medicine_id, (name, rows) in by_medicine.items()],
    )
