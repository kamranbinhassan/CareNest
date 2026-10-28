from collections.abc import Generator

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.entities import Family, FamilyMembership, User

_bearer = HTTPBearer(auto_error=False)


def database_session() -> Generator[Session, None, None]:
    try:
        yield from get_db()
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


def current_user(credentials: HTTPAuthorizationCredentials | None = Depends(_bearer), db: Session = Depends(database_session)) -> User:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Bearer token required", headers={"WWW-Authenticate": "Bearer"})
    user_id = decode_access_token(credentials.credentials)
    user = db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise HTTPException(status_code=401, detail="Account no longer exists", headers={"WWW-Authenticate": "Bearer"})
    return user


def authorized_family(db: Session, user: User, family_id: str) -> Family:
    family = db.scalar(select(Family).join(FamilyMembership).where(Family.id == family_id, FamilyMembership.user_id == user.id))
    if family is None:
        # A 404 avoids confirming another account's private family identifier.
        raise HTTPException(status_code=404, detail="Family not found")
    return family


def authorized_member(db: Session, user: User, member_id: str):
    from app.models.entities import FamilyMember
    member = db.scalar(select(FamilyMember).join(FamilyMembership, FamilyMembership.family_id == FamilyMember.family_id).where(FamilyMember.id == member_id, FamilyMembership.user_id == user.id))
    if member is None:
        raise HTTPException(status_code=404, detail="Family member not found")
    return member
