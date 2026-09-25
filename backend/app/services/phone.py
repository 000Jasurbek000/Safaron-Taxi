import re

PHONE_RE = re.compile(r"^\+998\d{9}$")
NAME_RE = re.compile(r"^[A-Za-zА-Яа-яЁёЎўҚқҒғҲҳʼ'’\- ]{2,60}$")
PLATE_RE = re.compile(
    r"^[0-9]{2}[A-Z]?[0-9]{3}[A-Z]{2,3}$|^[0-9]{2}[A-Z]{1}[0-9]{3}[A-Z]{2}$|^[0-9]{2}[A-Z]{3}[0-9]{3}$|^[A-Z0-9\-]{5,12}$",
    re.I,
)


def normalize_phone(raw: str) -> str | None:
    digits = re.sub(r"\D", "", raw or "")
    if digits.startswith("998") and len(digits) == 12:
        return f"+{digits}"
    if len(digits) == 9 and digits[0] in "3390":
        return f"+998{digits}"
    if digits.startswith("0") and len(digits) == 10:
        return f"+998{digits[1:]}"
    candidate = f"+{digits}" if not (raw or "").startswith("+") else f"+{digits}"
    if PHONE_RE.match(candidate):
        return candidate
    return None


def format_phone_display(phone: str) -> str:
    p = normalize_phone(phone) or phone
    if PHONE_RE.match(p):
        return f"+998 {p[4:6]} {p[6:9]} {p[9:11]} {p[11:13]}"
    return phone


def validate_name(value: str) -> str | None:
    cleaned = (value or "").strip()
    if len(cleaned) < 2:
        return None
    if any(ch.isdigit() for ch in cleaned):
        return None
    if not NAME_RE.match(cleaned):
        return None
    return cleaned


def normalize_plate(raw: str) -> str:
    return re.sub(r"\s+", "", (raw or "").upper())


def validate_plate(raw: str) -> bool:
    plate = normalize_plate(raw)
    return bool(plate) and bool(PLATE_RE.match(plate)) and 5 <= len(plate) <= 12
