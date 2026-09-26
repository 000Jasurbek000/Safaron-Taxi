from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from app.config import get_settings
from app.database import get_db
from app.deps import get_current_user
from app.models import OtpCode, User
from app.schemas import OkResponse, PhoneLookupOut, SendOtpIn, SendOtpOut, SignInIn, TokenResponse, UserOut, VerifyOtpIn
from app.security import create_access_token
from app.services.phone import normalize_phone, validate_name
from app.services.rewards import attach_referral, ensure_code
from app.services.serializers import user_out

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/otp/send", response_model=SendOtpOut)
def send_otp(body: SendOtpIn, db: Session = Depends(get_db)):
    phone = normalize_phone(body.phone)
    if not phone:
        raise HTTPException(400, "Telefon raqami noto‘g‘ri.")
    user_exists = db.query(User).filter(User.phone == phone).first() is not None
    settings = get_settings()
    code = settings.otp_dev_code
    db.query(OtpCode).filter(OtpCode.phone == phone, OtpCode.used.is_(False)).update({"used": True})
    db.add(OtpCode(phone=phone, code=code, expires_at=datetime.utcnow() + timedelta(minutes=5)))
    db.commit()
    # Dev: SMS provider yo‘q — kod response message da (faqat development).
    msg = f"SMS kod yuborildi. (dev: {code})"
    if user_exists:
        msg = f"Kirish kodi yuborildi. (dev: {code})"
    return SendOtpOut(ok=True, message=msg, user_exists=user_exists)


@router.post("/otp/verify", response_model=TokenResponse)
def verify_otp(body: VerifyOtpIn, db: Session = Depends(get_db)):
    phone = normalize_phone(body.phone)
    if not phone:
        raise HTTPException(400, "Telefon raqami noto‘g‘ri.")
    otp = (
        db.query(OtpCode)
        .filter(OtpCode.phone == phone, OtpCode.used.is_(False))
        .order_by(OtpCode.id.desc())
        .first()
    )
    if not otp or otp.code != body.code.strip():
        raise HTTPException(400, "SMS kod noto‘g‘ri.")
    if otp.expires_at < datetime.utcnow():
        raise HTTPException(400, "SMS kod muddati tugagan.")
    otp.used = True

    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.phone == phone).first()
    if user is None:
        first = validate_name(body.first_name or "")
        last = validate_name(body.last_name or "")
        if not first or not last:
            raise HTTPException(400, "Ro‘yxatdan o‘tish uchun ism va familiya to‘g‘ri kiritilishi shart.")
        user = User(phone=phone, first_name=first, last_name=last)
        db.add(user)
        db.flush()
    user.last_seen_at = datetime.utcnow()
    db.commit()
    db.refresh(user)
    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user.id).one()
    token = create_access_token(str(user.id), claims={"typ": "user"})
    return TokenResponse(access_token=token, user=user_out(user))


@router.post("/sign-in", response_model=TokenResponse)
def sign_in(body: SignInIn, db: Session = Depends(get_db)):
    """SMSsiz kirish / ro‘yxatdan o‘tish — telefon + ism + familiya."""
    phone = normalize_phone(body.phone)
    if not phone:
        raise HTTPException(400, "Telefon raqami noto‘g‘ri.")
    first = validate_name(body.first_name or "")
    last = validate_name(body.last_name or "")
    if not first or not last:
        raise HTTPException(400, "Ism va familiya to‘g‘ri kiritilishi shart.")

    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.phone == phone).first()
    if user is None:
        user = User(phone=phone, first_name=first, last_name=last)
        db.add(user)
        db.flush()
        ensure_code(db, user)
        attach_referral(db, user, body.referral_code)
    else:
        # Telefon unique: mavjud user — ism/familiyani ustiga yozilmaydi.
        if (body.referral_code or "").strip():
            attach_referral(db, user, body.referral_code)
    user.last_seen_at = datetime.utcnow()
    db.commit()
    db.refresh(user)
    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user.id).one()
    token = create_access_token(str(user.id), claims={"typ": "user"})
    return TokenResponse(access_token=token, user=user_out(user))


@router.get("/lookup", response_model=PhoneLookupOut)
def lookup_phone(phone: str, db: Session = Depends(get_db)):
    """Mavjud telefon — eski profilni qaytaradi (token talab qilmaydi)."""
    p = normalize_phone(phone)
    if not p:
        raise HTTPException(400, "Telefon raqami noto‘g‘ri.")
    user = db.query(User).filter(User.phone == p, User.deleted_at.is_(None)).first()
    if user is None:
        return PhoneLookupOut(exists=False)
    return PhoneLookupOut(
        exists=True,
        first_name=user.first_name or "",
        last_name=user.last_name or "",
        full_name=user.full_name or "",
        phone_display=user.phone or p,
        active_role=user.active_role or "passenger",
    )


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user.id).one()
    return user_out(user)
