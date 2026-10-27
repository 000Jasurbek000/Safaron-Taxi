from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from app.config import get_settings
from app.database import get_db
from app.deps import get_current_user
from app.models import OtpCode, User
from app.schemas import OkResponse, PhoneLookupOut, SendOtpIn, SendOtpOut, SignInIn, TokenResponse, UserOut, VerifyOtpIn
from app.security import create_access_token, hash_password, verify_password
from app.services.phone import normalize_phone, validate_name
from app.services.rewards import attach_referral, ensure_code, flag_on
from app.services.serializers import user_out

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/otp/send", response_model=SendOtpOut)
def send_otp(body: SendOtpIn, db: Session = Depends(get_db)):
    if not flag_on(db, "sms_otp"):
        raise HTTPException(400, "SMS orqali kirish hozircha o‘chirilgan.")
    phone = normalize_phone(body.phone)
    if not phone:
        raise HTTPException(400, "Telefon raqami noto‘g‘ri.")
    user_exists = db.query(User).filter(User.phone == phone, User.deleted_at.is_(None)).first() is not None
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
    if not flag_on(db, "sms_otp"):
        raise HTTPException(400, "SMS orqali kirish hozircha o‘chirilgan.")
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
        ensure_code(db, user)
        attach_referral(db, user, body.referral_code)
    elif user.deleted_at is not None:
        # O'chirilgan hisob bilan qayta kirish — qayta faollashtiramiz,
        # aks holda admin panelda "ko'rinmas" foydalanuvchi bo'lib qoladi.
        user.deleted_at = None
        user.is_active = True
        user.is_blocked = False
    user.last_seen_at = datetime.utcnow()
    db.commit()
    db.refresh(user)
    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user.id).one()
    token = create_access_token(str(user.id), claims={"typ": "user"})
    return TokenResponse(access_token=token, user=user_out(user))


@router.post("/sign-in", response_model=TokenResponse)
def sign_in(body: SignInIn, db: Session = Depends(get_db)):
    """SMSsiz kirish / ro‘yxatdan o‘tish — telefon + parol (+ yangi raqam
    uchun ism-familiya). Avval bu yerda parol umuman tekshirilmasdan,
    shunchaki mavjud telefon raqamiga token berilardi — buni bilgan
    har kim o'zganing hisobiga kirib ola olardi. Endi: raqam mavjud
    bo'lsa parol mos kelishi shart; mavjud bo'lmasa, shu parol bilan
    yangi hisob ochiladi."""
    phone = normalize_phone(body.phone)
    if not phone:
        raise HTTPException(400, "Telefon raqami noto‘g‘ri.")
    password = body.password or ""
    if not password:
        raise HTTPException(400, "Parol kiritilishi shart.")

    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.phone == phone).first()
    if user is None:
        first = validate_name(body.first_name or "")
        last = validate_name(body.last_name or "")
        if not first or not last:
            raise HTTPException(400, "Yangi raqam uchun ism va familiya to‘g‘ri kiritilishi shart.")
        user = User(phone=phone, first_name=first, last_name=last, password_hash=hash_password(password))
        db.add(user)
        db.flush()
        ensure_code(db, user)
        attach_referral(db, user, body.referral_code)
    else:
        if user.password_hash is None:
            # Parolsiz yaratilgan eski hisob — birinchi kirishda shu
            # parol o'rnatiladi (keyingi kirishlarda shu bilan tekshiriladi).
            user.password_hash = hash_password(password)
        elif not verify_password(password, user.password_hash):
            raise HTTPException(401, "Parol noto‘g‘ri.")
        if user.deleted_at is not None:
            # O'chirilgan hisob bilan qayta kirish — qayta faollashtiramiz,
            # aks holda admin panelda "ko'rinmas" foydalanuvchi bo'lib qoladi.
            user.deleted_at = None
            user.is_active = True
            user.is_blocked = False
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
    """Bu raqam ro'yxatdan o'tganmi — UI shunga qarab parol maydonini
    (mavjud bo'lsa) yoki ism/familiya+parol maydonlarini (mavjud
    bo'lmasa) ko'rsatadi. Qasddan hisob egasi haqida boshqa hech narsa
    qaytarmaydi (token talab qilmaydi)."""
    p = normalize_phone(phone)
    if not p:
        raise HTTPException(400, "Telefon raqami noto‘g‘ri.")
    exists = db.query(User).filter(User.phone == p, User.deleted_at.is_(None)).first() is not None
    return PhoneLookupOut(exists=exists)


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user.id).one()
    return user_out(user)
