from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.deps import get_current_user
from app.models import OtpCode, User
from app.schemas import ChangePhoneIn, LanguageIn, ProfileUpdateIn, RoleIn, UserOut
from app.services.phone import normalize_phone, validate_name
from app.services.serializers import user_out

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
def get_me(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user.id).one()
    return user_out(user)


@router.patch("/me", response_model=UserOut)
def update_me(body: ProfileUpdateIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if body.first_name is not None:
        name = validate_name(body.first_name)
        if not name:
            raise HTTPException(400, "Ism kiritilishi shart va to‘g‘ri bo‘lishi kerak.")
        user.first_name = name
    if body.last_name is not None:
        name = validate_name(body.last_name)
        if not name:
            raise HTTPException(400, "Familiya kiritilishi shart va to‘g‘ri bo‘lishi kerak.")
        user.last_name = name
    if body.experience_years is not None:
        if not user.driver_profile:
            raise HTTPException(400, "Tajriba faqat haydovchi profilida saqlanadi.")
        user.driver_profile.experience_years = body.experience_years
    db.commit()
    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user.id).one()
    return user_out(user)


@router.post("/me/role", response_model=UserOut)
def set_role(body: RoleIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    role = body.role.strip().lower()
    if role not in ("passenger", "driver"):
        raise HTTPException(400, "Rol noto‘g‘ri.")
    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user.id).one()
    if role == "driver":
        d = user.driver_profile
        if not d or d.status != "APPROVED":
            raise HTTPException(403, "Haydovchi rejimiga o‘tish uchun admin tasdiqi kerak.")
        if d.status == "SUSPENDED":
            raise HTTPException(403, "Haydovchi akkauntingiz to‘xtatilgan.")
    user.active_role = role
    db.commit()
    db.refresh(user)
    return user_out(user)


@router.post("/me/phone", response_model=UserOut)
def change_phone(body: ChangePhoneIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    new_phone = normalize_phone(body.phone)
    if not new_phone:
        raise HTTPException(400, "Telefon raqami noto‘g‘ri.")
    otp = (
        db.query(OtpCode)
        .filter(OtpCode.phone == new_phone, OtpCode.used.is_(False))
        .order_by(OtpCode.id.desc())
        .first()
    )
    if not otp or otp.code != body.code.strip():
        raise HTTPException(400, "SMS kod noto‘g‘ri.")
    if otp.expires_at < datetime.utcnow():
        raise HTTPException(400, "SMS kod muddati tugagan.")
    taken = db.query(User).filter(User.phone == new_phone, User.id != user.id).first()
    if taken:
        raise HTTPException(400, "Bu raqam boshqa akkauntga bog‘langan.")
    otp.used = True
    user.phone = new_phone
    db.commit()
    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user.id).one()
    return user_out(user)


@router.post("/me/language", response_model=UserOut)
def set_language(body: LanguageIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    lang = body.language.strip().lower()
    if lang not in ("uz", "ru", "en"):
        raise HTTPException(400, "Til qo‘llab-quvvatlanmaydi.")
    user.language = lang
    db.commit()
    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user.id).one()
    return user_out(user)
