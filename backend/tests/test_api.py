from datetime import date, datetime, timedelta, timezone

import pytest
from fastapi import HTTPException, Response
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import ValidationError

from app.api.dependencies import authorized_family, authorized_member, current_user
from app.main import app
from app.api.routes import (
    correct_dose,
    create_family,
    create_member,
    create_medicine,
    family_adherence,
    login,
    list_families,
    list_occurrences,
    record_dose,
    register,
)
from app.schemas.api import DoseEventCreate, FamilyCreate, FamilyMemberCreate, LoginRequest, MedicineCreate, UserCreate


def test_flutter_auth_http_contract():
    paths = app.openapi()["paths"]
    registration = paths["/api/v1/auth/register"]["post"]
    login_route = paths["/api/v1/auth/login"]["post"]
    assert registration["requestBody"]["content"]["application/json"]["schema"]["$ref"].endswith("/UserCreate")
    assert login_route["requestBody"]["content"]["application/json"]["schema"]["$ref"].endswith("/LoginRequest")
    assert registration["responses"]["201"]["content"]["application/json"]["schema"]["$ref"].endswith("/TokenOut")
    assert login_route["responses"]["200"]["content"]["application/json"]["schema"]["$ref"].endswith("/TokenOut")
    assert set(UserCreate.model_fields) == {"email", "password"}
    assert set(LoginRequest.model_fields) == {"email", "password"}


def make_user(db, email: str):
    token = register(UserCreate(email=email, password="valid-password-123"), db).access_token
    return token, current_user(HTTPAuthorizationCredentials(scheme="Bearer", credentials=token), db)


def test_auth_private_family_scope_and_dose_idempotency(db):
    token_a, user_a = make_user(db, "a@example.test")
    _, user_b = make_user(db, "b@example.test")
    assert user_a.password_hash.startswith("$argon2id$")
    login_result = login(LoginRequest(email="A@EXAMPLE.TEST", password="valid-password-123"), db)
    assert current_user(
        HTTPAuthorizationCredentials(scheme="Bearer", credentials=login_result.access_token), db
    ).id == user_a.id
    with pytest.raises(HTTPException) as bad_password:
        login(LoginRequest(email="a@example.test", password="wrong-password"), db)
    assert bad_password.value.status_code == 401
    family = create_family(FamilyCreate(name="North family"), db, user_a)
    assert list_families(db, user_b) == []
    with pytest.raises(HTTPException) as denied:
        authorized_family(db, user_b, family.id)
    assert denied.value.status_code == 404

    member = create_member(family.id, FamilyMemberCreate(name="Ava", relationship_label="Child"), db, user_a)
    with pytest.raises(HTTPException) as denied_member:
        authorized_member(db, user_b, member.id)
    assert denied_member.value.status_code == 404

    yesterday = datetime.now(timezone.utc).date() - timedelta(days=1)
    medicine = create_medicine(member.id, MedicineCreate.model_validate({
        "name": "Sample tablet", "dosage": "10 mg", "form": "Tablet", "dose_amount": "1",
        "food_instruction": "After food",
        "schedule": {"frequency": "Once daily", "start_date": yesterday.isoformat(), "end_date": yesterday.isoformat(), "dose_times": [{"hour": 8, "minute": 0}], "time_zone": "UTC"},
    }), db, user_a)
    rows = list_occurrences(member.id, yesterday, yesterday, db, user_a)
    assert rows[0].status == "overdue"
    created = record_dose(rows[0].id, DoseEventCreate(status="missed"), Response(), db, user_a)
    duplicate_response = Response()
    duplicate = record_dose(rows[0].id, DoseEventCreate(status="missed"), duplicate_response, db, user_a)
    assert duplicate_response.status_code == 200
    assert duplicate.id == created.id
    with pytest.raises(HTTPException) as duplicate_conflict:
        record_dose(rows[0].id, DoseEventCreate(status="taken"), Response(), db, user_a)
    assert duplicate_conflict.value.status_code == 409
    corrected = correct_dose(rows[0].id, DoseEventCreate(status="taken"), db, user_a)
    assert corrected.id == created.id
    assert corrected.status == "taken"

    summary = family_adherence(family.id, yesterday, yesterday, db, user_a)
    assert summary.counts.taken == 1
    assert summary.counts.adherence_percent == 100
    assert summary.medicines[0].medicine_id == medicine.id


def test_schedule_validation_and_future_doses_are_not_recordable(db):
    _, owner = make_user(db, "owner@example.test")
    family = create_family(FamilyCreate(name="Household"), db, owner)
    member = create_member(family.id, FamilyMemberCreate(name="Sam", relationship_label="Parent"), db, owner)
    today = date.today()
    with pytest.raises(ValidationError):
        MedicineCreate.model_validate({
            "name": "Bad plan", "dosage": "5 mg", "form": "Tablet", "dose_amount": "1",
            "schedule": {"frequency": "Twice daily", "start_date": today.isoformat(), "end_date": (today - timedelta(days=1)).isoformat(), "dose_times": [{"hour": 9, "minute": 0}], "time_zone": "UTC"},
        })

    future = today + timedelta(days=1)
    create_medicine(member.id, MedicineCreate.model_validate({
        "name": "Scheduled medicine", "dosage": "1 unit", "form": "Tablet", "dose_amount": "1",
        "schedule": {"frequency": "Once daily", "start_date": future.isoformat(), "dose_times": [{"hour": 9, "minute": 0}], "time_zone": "UTC"},
    }), db, owner)
    occurrence = list_occurrences(member.id, future, future, db, owner)[0]
    assert occurrence.status == "pending"
    with pytest.raises(HTTPException) as early:
        record_dose(occurrence.id, DoseEventCreate(status="taken"), Response(), db, owner)
    assert early.value.status_code == 409
