from sqlalchemy.orm import Session

from app.models import AdminUser
from app.security import hash_password, verify_password
from app.services.phone import normalize_phone

MIN_PASSWORD_LEN = 8
MAX_PASSWORD_LEN = 72
_WEAK = frozenset({"password", "admin123", "12345678", "qwerty123", "password1"})


def admin_public(admin: AdminUser) -> dict:
    return {
        "id": admin.id,
        "phone": admin.phone,
        "email": admin.email,
        "full_name": admin.full_name,
        "role": admin.role,
        "is_active": admin.is_active,
        "created_at": admin.created_at,
    }


def validate_admin_password(password: str) -> None:
    if not isinstance(password, str) or not password:
        raise ValueError("Parol kiritilishi shart.")
    if len(password) < MIN_PASSWORD_LEN:
        raise ValueError(f"Parol kamida {MIN_PASSWORD_LEN} belgidan iborat bo‘lishi kerak.")
    if len(password.encode("utf-8")) > MAX_PASSWORD_LEN:
        raise ValueError("Parol juda uzun.")
    if not any(c.isalpha() for c in password) or not any(c.isdigit() for c in password):
        raise ValueError("Parolda kamida bitta harf va bitta raqam bo‘lishi kerak.")
    if password.lower() in _WEAK:
        raise ValueError("Bu parol juda oddiy. Kuchliroq parol tanlang.")


def set_admin_password(admin: AdminUser, new_password: str) -> None:
    """Hash qilib password_hash ni yangilaydi. Commit qilmaydi."""
    validate_admin_password(new_password)
    admin.password_hash = hash_password(new_password)


def create_admin(
    db: Session,
    *,
    phone: str,
    password: str,
    full_name: str = "Super Admin",
    role: str = "SUPER_ADMIN",
    email: str | None = None,
) -> AdminUser:
    """Yangi admin yaratadi. Mavjud adminni o‘zgartirmaydi."""
    normalized = normalize_phone(phone) or (phone or "").strip()
    if not normalized:
        raise ValueError("Admin telefoni noto‘g‘ri.")
    existing = db.query(AdminUser).filter(AdminUser.phone == normalized).first()
    if existing:
        raise ValueError("Bu telefon bilan admin allaqachon mavjud.")
    validate_admin_password(password)
    safe_role = role if role in ("SUPER_ADMIN", "ADMIN") else "ADMIN"
    admin = AdminUser(
        phone=normalized,
        password_hash=hash_password(password),
        full_name=(full_name or "Admin").strip() or "Admin",
        role=safe_role,
        email=(email or "").strip() or None,
        is_active=True,
    )
    db.add(admin)
    db.flush()
    return admin


def ensure_seed_admin(db: Session, phone: str, password: str) -> AdminUser:
    """Faqat yo‘q bo‘lsa yaratadi. Mavjud adminning id/phone/role/full_name/hash ga tegmaydi."""
    normalized = normalize_phone(phone) or (phone or "").strip()
    admin = db.query(AdminUser).filter(AdminUser.phone == normalized).first()
    if admin:
        return admin
    return create_admin(
        db,
        phone=normalized,
        password=password,
        full_name="Super Admin",
        role="SUPER_ADMIN",
    )


def authenticate_admin(db: Session, phone: str, password: str) -> AdminUser | None:
    normalized = normalize_phone(phone) or (phone or "").strip()
    admin = db.query(AdminUser).filter(AdminUser.phone == normalized).first()
    if not admin or not verify_password(password, admin.password_hash):
        return None
    return admin


def change_admin_password(
    admin: AdminUser,
    current_password: str,
    new_password: str,
    confirm_password: str,
) -> None:
    if not current_password or not verify_password(current_password, admin.password_hash):
        raise ValueError("Joriy parol noto‘g‘ri.")
    if new_password != confirm_password:
        raise ValueError("Yangi parol va tasdiq mos kelmadi.")
    if current_password == new_password:
        raise ValueError("Yangi parol joriy paroldan farq qilishi kerak.")
    set_admin_password(admin, new_password)


def update_admin_profile(
    db: Session,
    admin: AdminUser,
    *,
    full_name: str | None = None,
    email: str | None = None,
    phone: str | None = None,
) -> AdminUser:
    """Faqat o‘zining to‘liq ismi, email va telefonini yangilaydi. role/id o‘zgarmaydi."""
    if full_name is not None:
        name = full_name.strip()
        if len(name) < 2:
            raise ValueError("Ism kamida 2 belgidan iborat bo‘lishi kerak.")
        if len(name) > 120:
            raise ValueError("Ism juda uzun.")
        admin.full_name = name

    if email is not None:
        cleaned = email.strip()
        if cleaned == "":
            admin.email = None
        else:
            if "@" not in cleaned or "." not in cleaned.split("@")[-1] or len(cleaned) > 120:
                raise ValueError("Email manzili noto‘g‘ri.")
            taken = (
                db.query(AdminUser)
                .filter(AdminUser.email == cleaned, AdminUser.id != admin.id)
                .first()
            )
            if taken:
                raise ValueError("Bu email band.")
            admin.email = cleaned

    if phone is not None:
        normalized = normalize_phone(phone) or phone.strip()
        if not normalized:
            raise ValueError("Telefon raqami noto‘g‘ri.")
        taken = (
            db.query(AdminUser)
            .filter(AdminUser.phone == normalized, AdminUser.id != admin.id)
            .first()
        )
        if taken:
            raise ValueError("Bu telefon band.")
        admin.phone = normalized

    return admin
