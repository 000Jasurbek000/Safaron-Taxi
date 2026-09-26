from datetime import datetime
from pathlib import Path
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session, joinedload

from app.config import get_settings
from app.database import get_db
from app.deps import get_approved_driver, get_current_user
from app.models import DriverDocument, DriverProfile, User, Vehicle
from app.schemas import HeartbeatIn, OkResponse, OnlineIn, UserOut
from app.services.phone import normalize_plate, validate_plate
from app.services.serializers import user_out

router = APIRouter(prefix="/drivers", tags=["drivers"])

ALLOWED_IMAGE = {"image/jpeg", "image/png", "image/webp", "image/jpg", "application/octet-stream"}


def _looks_like_image(data: bytes) -> bool:
    return data.startswith(b"\xff\xd8\xff") or data.startswith(b"\x89PNG\r\n\x1a\n") or (data.startswith(b"RIFF") and b"WEBP" in data[:16])


async def _save_upload(file: UploadFile, folder: str) -> str:
    settings = get_settings()
    data = await file.read()
    named_image = (file.filename or "").lower().endswith((".jpg", ".jpeg", ".png", ".webp"))
    if file.content_type not in ALLOWED_IMAGE and not named_image and not _looks_like_image(data):
        raise HTTPException(400, "Faqat JPG/PNG/WebP rasm yuklash mumkin.")
    max_bytes = settings.max_upload_mb * 1024 * 1024
    if len(data) > max_bytes:
        raise HTTPException(400, f"Fayl hajmi {settings.max_upload_mb} MB dan oshmasin.")
    if len(data) < 100:
        raise HTTPException(400, "Fayl bo‘sh yoki yaroqsiz.")
    ext = Path(file.filename or "img.jpg").suffix.lower() or ".jpg"
    if ext not in (".jpg", ".jpeg", ".png", ".webp"):
        ext = ".jpg"
    dest_dir = Path(settings.upload_dir) / folder
    dest_dir.mkdir(parents=True, exist_ok=True)
    name = f"{uuid.uuid4().hex}{ext}"
    path = dest_dir / name
    path.write_bytes(data)
    return f"{folder}/{name}"


@router.post("/apply", response_model=UserOut)
async def apply_driver(
    experience_years: int = Form(...),
    model_name: str = Form(...),
    plate: str = Form(...),
    seats: int = Form(...),
    color: str | None = Form(None),
    selfie: UploadFile | None = File(None),
    vehicle_photo: UploadFile = File(...),
    driver_license: UploadFile | None = File(None),
    vehicle_registration: UploadFile | None = File(None),
    insurance: UploadFile | None = File(None),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if experience_years < 0 or experience_years > 60:
        raise HTTPException(400, "Tajriba noto‘g‘ri.")
    model = model_name.strip()
    if len(model) < 2:
        raise HTTPException(400, "Mashina nomini kiriting.")
    if not validate_plate(plate):
        raise HTTPException(400, "Davlat raqami noto‘g‘ri. Namuna: 00 A 000 AA yoki 00 000 AAA.")
    plate_n = normalize_plate(plate)
    if seats < 1 or seats > 10:
        raise HTTPException(400, "Yo‘lovchi sig‘imi noto‘g‘ri (1–10).")

    existing_plate = db.query(Vehicle).filter(Vehicle.plate == plate_n).first()
    driver = db.query(DriverProfile).filter(DriverProfile.user_id == user.id).first()
    if existing_plate and (not driver or existing_plate.driver_id != driver.id):
        raise HTTPException(400, "Bu davlat raqami allaqachon ro‘yxatdan o‘tgan.")

    selfie_path = None
    if selfie is not None and (selfie.filename or "").strip():
        selfie_path = await _save_upload(selfie, "drivers")
    elif user.avatar_path:
        selfie_path = user.avatar_path
    car_path = await _save_upload(vehicle_photo, "vehicles")
    lic_path = await _save_upload(driver_license, "docs") if driver_license and driver_license.filename else None
    reg_path = await _save_upload(vehicle_registration, "docs") if vehicle_registration and vehicle_registration.filename else None
    ins_path = await _save_upload(insurance, "docs") if insurance and insurance.filename else None

    if driver is None:
        driver = DriverProfile(user_id=user.id)
        db.add(driver)
        db.flush()
    elif driver.status == "APPROVED":
        raise HTTPException(400, "Siz allaqachon tasdiqlangan haydovchisiz.")
    elif driver.status == "SUSPENDED":
        raise HTTPException(403, "Akkaunt to‘xtatilgan — qayta ariza yuborib bo‘lmaydi.")

    driver.status = "PENDING"
    driver.rejection_reason = None
    driver.experience_years = experience_years
    if selfie_path:
        driver.photo_path = selfie_path
    db.flush()

    vehicle = db.query(Vehicle).filter(Vehicle.driver_id == driver.id).first()
    if vehicle is None:
        vehicle = Vehicle(driver_id=driver.id, model_name=model, plate=plate_n, seats=seats, photo_path=car_path, color=color)
        db.add(vehicle)
    else:
        vehicle.model_name = model
        vehicle.plate = plate_n
        vehicle.seats = seats
        vehicle.photo_path = car_path
        vehicle.color = color

    db.query(DriverDocument).filter(DriverDocument.driver_id == driver.id).delete()
    for t, p in [
        ("selfie", selfie_path),
        ("vehicle_photo", car_path),
        ("license", lic_path),
        ("registration", reg_path),
    ]:
        if p:
            db.add(DriverDocument(driver_id=driver.id, doc_type=t, file_path=p))
    if ins_path:
        db.add(DriverDocument(driver_id=driver.id, doc_type="insurance", file_path=ins_path))

    if selfie is not None and (selfie.filename or "").strip() and selfie_path:
        user.avatar_path = selfie_path
    db.commit()
    user = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user.id).one()
    return user_out(user)


@router.post("/online", response_model=OkResponse)
def set_online(body: OnlineIn, driver: DriverProfile = Depends(get_approved_driver), db: Session = Depends(get_db)):
    driver.is_online = body.is_online
    driver.last_seen_at = datetime.utcnow()
    if body.latitude is not None:
        driver.latitude = body.latitude
    if body.longitude is not None:
        driver.longitude = body.longitude
    db.commit()
    msg = "Siz onlaysiz. Yangi yo‘lovchi so‘rovlari kelmoqda." if body.is_online else "Ishlash to‘xtatildi."
    return OkResponse(ok=True, message=msg)


@router.post("/heartbeat", response_model=OkResponse)
def heartbeat(body: HeartbeatIn, driver: DriverProfile = Depends(get_approved_driver), db: Session = Depends(get_db)):
    driver.last_seen_at = datetime.utcnow()
    if body.latitude is not None:
        driver.latitude = body.latitude
    if body.longitude is not None:
        driver.longitude = body.longitude
    if not driver.is_online:
        driver.is_online = True
    db.commit()
    return OkResponse(ok=True)


@router.get("/me/earnings")
def earnings(driver: DriverProfile = Depends(get_approved_driver), db: Session = Depends(get_db)):
    # Simplified aggregates from completed requests where selected
    from app.models import TripRequest
    from sqlalchemy import func

    today = datetime.utcnow().date()
    rows = (
        db.query(TripRequest)
        .filter(
            TripRequest.selected_driver_id == driver.id,
            TripRequest.status == "COMPLETED",
        )
        .all()
    )
    def day_sum(pred):
        return sum((r.agreed_price or r.offered_price) for r in rows if pred(r))

    return {
        "today": day_sum(lambda r: r.updated_at.date() == today),
        "week": day_sum(lambda r: (datetime.utcnow() - r.updated_at).days < 7),
        "month": day_sum(lambda r: (datetime.utcnow() - r.updated_at).days < 30),
        "total": driver.total_earnings,
        "trips_count": driver.trips_count,
        "rating_avg": driver.rating_avg,
    }
