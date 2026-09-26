from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.models import AdminUser, DriverProfile, User
from app.security import safe_decode

bearer = HTTPBearer(auto_error=False)


def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    if creds is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Avtorizatsiya talab qilinadi.")
    payload = safe_decode(creds.credentials)
    if not payload or payload.get("typ") not in (None, "user"):
        if payload and payload.get("typ") == "admin":
            raise HTTPException(status_code=403, detail="Bu amalni bajarish huquqingiz yo‘q.")
        raise HTTPException(status_code=401, detail="Sessiya muddati tugagan. Qayta kiring.")
    user_id = payload.get("sub")
    user = db.get(User, int(user_id))
    if not user or not user.is_active or user.is_blocked:
        raise HTTPException(status_code=401, detail="Akkaunt topilmadi yoki bloklangan.")
    return user


def get_optional_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User | None:
    if creds is None:
        return None
    payload = safe_decode(creds.credentials)
    if not payload:
        return None
    if payload.get("typ") == "admin":
        return None
    user = db.get(User, int(payload["sub"]))
    if not user or not user.is_active or user.is_blocked:
        return None
    return user


def get_driver_profile(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DriverProfile:
    """Haydovchi profili — PENDING ham ruxsat (admin e’lonni ko‘rsin)."""
    driver = (
        db.query(DriverProfile)
        .options(joinedload(DriverProfile.vehicle), joinedload(DriverProfile.user))
        .filter(DriverProfile.user_id == user.id)
        .first()
    )
    if not driver:
        raise HTTPException(status_code=403, detail="Haydovchi profili topilmadi.")
    if driver.status == "SUSPENDED":
        raise HTTPException(status_code=403, detail="Haydovchi akkauntingiz to‘xtatilgan.")
    return driver


def get_approved_driver(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DriverProfile:
    driver = get_driver_profile(user, db)
    if driver.status != "APPROVED":
        raise HTTPException(status_code=403, detail="Haydovchi sifatida tasdiqlanmagansiz.")
    return driver


def get_current_admin(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> AdminUser:
    if creds is None:
        raise HTTPException(status_code=401, detail="Admin avtorizatsiyasi talab qilinadi.")
    payload = safe_decode(creds.credentials)
    if not payload or payload.get("typ") != "admin":
        raise HTTPException(status_code=403, detail="Bu amalni bajarish huquqingiz yo‘q.")
    admin = db.get(AdminUser, int(payload["sub"]))
    if not admin or not admin.is_active:
        raise HTTPException(status_code=401, detail="Admin topilmadi.")
    return admin


def require_super_admin(admin: AdminUser = Depends(get_current_admin)) -> AdminUser:
    if admin.role != "SUPER_ADMIN":
        raise HTTPException(status_code=403, detail="Faqat Super Admin.")
    return admin
