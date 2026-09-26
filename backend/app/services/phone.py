import re

PHONE_RE = re.compile(r"^\+998\d{9}$")
NAME_RE = re.compile(r"^[A-Za-zА-Яа-яЁёЎўҚқҒғҲҳʼ'’\- ]{2,60}$")
PLATE_RE = re.compile(r"^(\d{2})([A-Z]?)(\d{3})([A-Z]{2,3})$", re.I)
VALID_PLATE_REGIONS = {
    "01", "10", "20", "25", "30", "35", "40", "45", "50", "55",
    "60", "65", "70", "75", "80", "85", "90", "95",
}


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


def snap_plate_region(code: str) -> str:
    digits = re.sub(r"\D", "", code or "")
    if len(digits) != 2:
        return digits
    if digits in VALID_PLATE_REGIONS:
        return digits
    try:
        n = int(digits)
    except ValueError:
        return digits
    best, best_diff = None, 99
    for v in VALID_PLATE_REGIONS:
        diff = abs(int(v) - n)
        if best is None or diff < best_diff or (diff == best_diff and int(v) < int(best)):
            best, best_diff = v, diff
    if best is not None and best_diff <= 5:
        return best
    return digits


def normalize_plate(raw: str) -> str:
    plate = re.sub(r"\s+", "", (raw or "").upper())
    m = PLATE_RE.match(plate)
    if not m:
        return plate
    region = snap_plate_region(m.group(1))
    return f"{region}{m.group(2).upper()}{m.group(3)}{m.group(4).upper()}"


def validate_plate(raw: str) -> bool:
    plate = normalize_plate(raw)
    m = PLATE_RE.match(plate)
    if not m:
        return False
    region, mid, _digits, end = m.group(1), m.group(2).upper(), m.group(3), m.group(4).upper()
    if region not in VALID_PLATE_REGIONS:
        return False
    if mid:
        return len(end) == 2
    return len(end) == 3
