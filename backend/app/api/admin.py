import csv
import io
import json
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.deps import get_current_admin
from app.models import (
    AdminLog,
    AdminUser,
    BonusTransaction,
    DriverDocument,
    DriverProfile,
    FraudEvent,
    Location,
    LocationAlias,
    Notification,
    Referral,
    SystemSetting,
    Trip,
    TripRequest,
    User,
    Vehicle,
    WithdrawalRequest,
)
from app.schemas import (
    AdminLoginIn,
    AdminOut,
    AdminPasswordChangeIn,
    AdminProfileUpdateIn,
    AdminTokenOut,
    LocationCreateIn,
    NotifyBroadcastIn,
    OkResponse,
    StatusUpdateIn,
)
from app.security import create_access_token
from app.services.admin_auth import (
    admin_public,
    authenticate_admin,
    change_admin_password,
    update_admin_profile,
)
from app.services.notify import notify

router = APIRouter(prefix="/admin", tags=["admin"])


def _log(db: Session, admin: AdminUser, action: str, object_type: str | None = None, object_id: int | None = None, before=None, after=None):
    db.add(
        AdminLog(
            admin_id=admin.id,
            action=action,
            object_type=object_type,
            object_id=object_id,
            before_json=json.dumps(before, ensure_ascii=False, default=str) if before is not None else None,
            after_json=json.dumps(after, ensure_ascii=False, default=str) if after is not None else None,
        )
    )


@router.post("/auth/login", response_model=AdminTokenOut)
def admin_login(body: AdminLoginIn, db: Session = Depends(get_db)):
    admin = authenticate_admin(db, body.phone, body.password)
    if not admin:
        raise HTTPException(401, "Login yoki parol noto‘g‘ri.")
    if not admin.is_active:
        raise HTTPException(403, "Admin akkaunti o‘chirilgan.")
    token = create_access_token(str(admin.id), claims={"typ": "admin", "role": admin.role})
    return AdminTokenOut(access_token=token, admin=AdminOut(**admin_public(admin)))


@router.get("/auth/me", response_model=AdminOut)
def admin_me(admin: AdminUser = Depends(get_current_admin)):
    return AdminOut(**admin_public(admin))


@router.patch("/auth/me", response_model=AdminOut)
def admin_update_me(
    body: AdminProfileUpdateIn,
    admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    before = {"full_name": admin.full_name, "email": admin.email, "phone": admin.phone}
    update_admin_profile(
        db,
        admin,
        full_name=body.full_name,
        email=body.email,
        phone=body.phone,
    )
    _log(db, admin, "admin_profile_update", "admin", admin.id, before, admin_public(admin))
    db.commit()
    db.refresh(admin)
    return AdminOut(**admin_public(admin))


@router.post("/auth/password", response_model=OkResponse)
def admin_change_password(
    body: AdminPasswordChangeIn,
    admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    change_admin_password(admin, body.current_password, body.new_password, body.confirm_password)
    _log(db, admin, "admin_password_change", "admin", admin.id, None, {"changed": True})
    db.commit()
    return OkResponse(ok=True, message="Parol yangilandi.")


@router.get("/dashboard")
def dashboard(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    today = datetime.utcnow().date()
    # oxirgi 7 kun statistikasi (chart)
    chart_days = []
    for i in range(6, -1, -1):
        day = today.fromordinal(today.toordinal() - i)
        chart_days.append(
            {
                "date": day.isoformat(),
                "label": day.strftime("%d.%m"),
                "users": db.query(User).filter(func.date(User.created_at) == day).count(),
                "trips": db.query(Trip).filter(func.date(Trip.created_at) == day).count(),
                "requests": db.query(TripRequest).filter(func.date(TripRequest.created_at) == day).count(),
                "completed": db.query(TripRequest).filter(
                    func.date(TripRequest.updated_at) == day,
                    TripRequest.status == "COMPLETED",
                ).count(),
            }
        )

    status_breakdown = {
        s: db.query(TripRequest).filter(TripRequest.status == s).count()
        for s in ["SEARCHING", "DRIVER_ACCEPTED", "CONFIRMED", "IN_PROGRESS", "COMPLETED", "CANCELLED", "EXPIRED"]
    }

    return {
        "users_total": db.query(User).count(),
        "users_active": db.query(User).filter(User.is_active.is_(True), User.is_blocked.is_(False)).count(),
        "drivers_total": db.query(DriverProfile).filter(DriverProfile.status == "APPROVED").count(),
        "drivers_online": db.query(DriverProfile).filter(DriverProfile.is_online.is_(True), DriverProfile.status == "APPROVED").count(),
        "driver_pending": db.query(DriverProfile).filter(DriverProfile.status == "PENDING").count(),
        "trips_today": db.query(Trip).filter(func.date(Trip.created_at) == today).count(),
        "trips_active": db.query(Trip).filter(Trip.status.in_(["OPEN", "FULL", "IN_PROGRESS"])).count(),
        "trips_completed": db.query(Trip).filter(Trip.status == "COMPLETED").count(),
        "trips_cancelled": db.query(Trip).filter(Trip.status == "CANCELLED").count(),
        "requests_today": db.query(TripRequest).filter(func.date(TripRequest.created_at) == today).count(),
        "requests_searching": db.query(TripRequest).filter(TripRequest.status.in_(["SEARCHING", "DRIVER_ACCEPTED"])).count(),
        "locations_pending": db.query(Location).filter(Location.is_approved.is_(False)).count(),
        "chart_days": chart_days,
        "request_status_breakdown": status_breakdown,
        "revenue_total": db.query(func.coalesce(func.sum(DriverProfile.total_earnings), 0)).scalar() or 0,
        "passengers_total": db.query(User).filter(User.deleted_at.is_(None), User.active_role != "driver").count(),
        "bonus_paid": db.query(func.coalesce(func.sum(BonusTransaction.amount), 0)).filter(BonusTransaction.status == "APPROVED", BonusTransaction.amount > 0).scalar() or 0,
        "pending_bonus": db.query(BonusTransaction).filter(BonusTransaction.status == "PENDING").count(),
        "pending_withdrawal": db.query(WithdrawalRequest).filter(WithdrawalRequest.status == "PENDING").count(),
        "fraud_open": db.query(FraudEvent).filter(FraudEvent.status == "OPEN").count(),
        "recent_requests": _recent_requests(db),
        "recent_users": [
            {"id": u.id, "name": u.full_name, "phone": u.phone, "role": u.active_role, "time": u.created_at.strftime("%H:%M") if u.created_at else ""}
            for u in db.query(User).filter(User.deleted_at.is_(None)).order_by(User.id.desc()).limit(6).all()
        ],
        "top_referrers": _top_referrers(db),
        "withdrawals": [
            {"id": w.id, "user_id": w.user_id, "amount": w.amount, "status": w.status, "telegram": w.telegram_username}
            for w in db.query(WithdrawalRequest).order_by(WithdrawalRequest.id.desc()).limit(6).all()
        ],
        "recent_trips": [
            {
                "id": t.id,
                "route": f"{t.from_text or '—'} → {t.to_text or '—'}",
                "price": t.price,
                "status": t.status,
                "time": t.created_at.strftime("%H:%M") if t.created_at else "",
            }
            for t in db.query(Trip).order_by(Trip.id.desc()).limit(6).all()
        ],
    }


def _recent_requests(db: Session):
    rows = db.query(TripRequest).order_by(TripRequest.id.desc()).limit(6).all()
    ids = {r.passenger_id for r in rows}
    names = {u.id: u.full_name for u in db.query(User).filter(User.id.in_(ids or {0})).all()}
    return [
        {
            "id": r.id,
            "passenger": names.get(r.passenger_id, "—"),
            "route": f"{r.from_text or '—'} → {r.to_text or '—'}",
            "price": r.agreed_price or r.offered_price or 0,
            "status": r.status,
            "time": r.created_at.strftime("%H:%M") if r.created_at else "",
        }
        for r in rows
    ]


def _top_referrers(db: Session):
    rows = (
        db.query(Referral.referrer_id, Referral.code, func.count(Referral.id))
        .filter(Referral.deleted_at.is_(None))
        .group_by(Referral.referrer_id, Referral.code)
        .order_by(func.count(Referral.id).desc())
        .limit(5)
        .all()
    )
    ids = {r[0] for r in rows}
    names = {u.id: u.full_name for u in db.query(User).filter(User.id.in_(ids or {0})).all()}
    return [{"name": names.get(uid, "—"), "code": code, "count": cnt} for uid, code, cnt in rows]


def _doc_url(path: str | None) -> str | None:
    if not path:
        return None
    return f"/uploads/{path.lstrip('/')}"


@router.get("/drivers/{driver_id}")
def driver_detail(driver_id: int, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    d = (
        db.query(DriverProfile)
        .options(joinedload(DriverProfile.user), joinedload(DriverProfile.vehicle), joinedload(DriverProfile.documents))
        .filter(DriverProfile.id == driver_id)
        .first()
    )
    if not d:
        raise HTTPException(404, "Haydovchi topilmadi.")
    docs = []
    for x in d.documents:
        if x.doc_type not in ("selfie", "vehicle_photo"):
            continue
        docs.append(
            {
                "id": x.id,
                "type": x.doc_type,
                "path": x.file_path,
                "url": _doc_url(x.file_path),
                "label": {
                    "selfie": "Profil rasmi",
                    "vehicle_photo": "Mashina rasmi",
                    "license": "Haydovchilik guvohnomasi",
                    "registration": "Texpasport",
                    "insurance": "Sug‘urta",
                }.get(x.doc_type, x.doc_type),
                "created_at": x.created_at,
            }
        )
    recent_trips = (
        db.query(Trip).filter(Trip.driver_id == d.id).order_by(Trip.id.desc()).limit(10).all()
    )
    recent_reqs = (
        db.query(TripRequest)
        .filter(TripRequest.selected_driver_id == d.id)
        .order_by(TripRequest.id.desc())
        .limit(10)
        .all()
    )
    return {
        "id": d.id,
        "user_id": d.user_id,
        "full_name": d.user.full_name,
        "first_name": d.user.first_name,
        "last_name": d.user.last_name,
        "phone": d.user.phone,
        "language": d.user.language,
        "status": d.status,
        "is_online": d.is_online,
        "last_seen_at": d.last_seen_at,
        "experience_years": d.experience_years,
        "rating_avg": d.rating_avg,
        "rating_count": d.rating_count,
        "trips_count": d.trips_count,
        "total_earnings": d.total_earnings,
        "rejection_reason": d.rejection_reason,
        "suspend_reason": d.suspend_reason,
        "approved_at": d.approved_at,
        "created_at": d.created_at,
        "photo": d.photo_path,
        "photo_url": _doc_url(d.photo_path) or _doc_url(d.user.avatar_path),
        "vehicle": None
        if not d.vehicle
        else {
            "model": d.vehicle.model_name,
            "plate": d.vehicle.plate,
            "seats": d.vehicle.seats,
            "color": d.vehicle.color,
            "photo": d.vehicle.photo_path,
            "photo_url": _doc_url(d.vehicle.photo_path),
        },
        "documents": docs,
        "recent_trips": [
            {
                "id": t.id,
                "from_text": t.from_text,
                "to_text": t.to_text,
                "scheduled_at": t.scheduled_at,
                "price": t.price,
                "status": t.status,
                "seats_available": t.seats_available,
                "seats_total": t.seats_total,
            }
            for t in recent_trips
        ],
        "recent_requests": [
            {
                "id": r.id,
                "from_text": r.from_text,
                "to_text": r.to_text,
                "status": r.status,
                "offered_price": r.offered_price,
                "agreed_price": r.agreed_price,
                "created_at": r.created_at,
            }
            for r in recent_reqs
        ],
    }


@router.get("/users/{user_id}")
def user_detail(user_id: int, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    u = db.query(User).options(joinedload(User.driver_profile)).filter(User.id == user_id).first()
    if not u:
        raise HTTPException(404, "Foydalanuvchi topilmadi.")
    reqs = db.query(TripRequest).filter(TripRequest.passenger_id == u.id).order_by(TripRequest.id.desc()).limit(15).all()
    return {
        "id": u.id,
        "full_name": u.full_name,
        "first_name": u.first_name,
        "last_name": u.last_name,
        "phone": u.phone,
        "active_role": u.active_role,
        "language": u.language,
        "is_blocked": u.is_blocked,
        "is_active": u.is_active,
        "rating_avg": u.rating_avg,
        "rating_count": u.rating_count,
        "avatar_url": _doc_url(u.avatar_path),
        "created_at": u.created_at,
        "last_seen_at": u.last_seen_at,
        "driver_status": u.driver_profile.status if u.driver_profile else None,
        "driver_id": u.driver_profile.id if u.driver_profile else None,
        "requests": [
            {
                "id": r.id,
                "from_text": r.from_text,
                "to_text": r.to_text,
                "status": r.status,
                "offered_price": r.offered_price,
                "agreed_price": r.agreed_price,
                "scheduled_at": r.scheduled_at,
                "created_at": r.created_at,
            }
            for r in reqs
        ],
        "trips": [
            {
                "id": t.id,
                "from_text": t.from_text,
                "to_text": t.to_text,
                "price": t.price,
                "status": t.status,
                "scheduled_at": t.scheduled_at,
                "seats_available": t.seats_available,
                "seats_total": t.seats_total,
            }
            for t in (
                db.query(Trip)
                .filter(Trip.driver_id == u.driver_profile.id)
                .order_by(Trip.id.desc())
                .limit(15)
                .all()
                if u.driver_profile
                else []
            )
        ],
    }


@router.get("/requests/{request_id}")
def request_detail(request_id: int, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    from app.models import DriverResponse

    r = db.query(TripRequest).options(joinedload(TripRequest.responses)).filter(TripRequest.id == request_id).first()
    if not r:
        raise HTTPException(404, "So‘rov topilmadi.")
    passenger = db.get(User, r.passenger_id)
    responses = []
    for resp in r.responses:
        d = db.query(DriverProfile).options(joinedload(DriverProfile.user), joinedload(DriverProfile.vehicle)).filter(DriverProfile.id == resp.driver_id).first()
        responses.append(
            {
                "id": resp.id,
                "driver_id": resp.driver_id,
                "status": resp.status,
                "offered_price": resp.offered_price,
                "message": resp.message,
                "created_at": resp.created_at,
                "driver_name": d.user.full_name if d else "",
                "driver_phone": d.user.phone if d else "",
                "car": d.vehicle.model_name if d and d.vehicle else "",
                "plate": d.vehicle.plate if d and d.vehicle else "",
            }
        )
    return {
        "id": r.id,
        "passenger_id": r.passenger_id,
        "passenger_name": passenger.full_name if passenger else "",
        "passenger_phone": passenger.phone if passenger else "",
        "from_text": r.from_text,
        "to_text": r.to_text,
        "exact_place": r.exact_place,
        "scheduled_at": r.scheduled_at,
        "passengers_count": r.passengers_count,
        "has_luggage": r.has_luggage,
        "note": r.note,
        "offered_price": r.offered_price,
        "agreed_price": r.agreed_price,
        "status": r.status,
        "selected_driver_id": r.selected_driver_id,
        "cancelled_by": r.cancelled_by,
        "cancel_reason": r.cancel_reason,
        "cancelled_at": r.cancelled_at,
        "expires_at": r.expires_at,
        "created_at": r.created_at,
        "updated_at": r.updated_at,
        "responses": responses,
    }


@router.get("/trips/{trip_id}")
def trip_detail(trip_id: int, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    from app.models import TripBooking

    t = db.get(Trip, trip_id)
    if not t:
        raise HTTPException(404, "Safar topilmadi.")
    d = db.query(DriverProfile).options(joinedload(DriverProfile.user), joinedload(DriverProfile.vehicle)).filter(DriverProfile.id == t.driver_id).first()
    bookings = db.query(TripBooking).filter(TripBooking.trip_id == t.id).all()
    booking_rows = []
    for b in bookings:
        p = db.get(User, b.passenger_id)
        booking_rows.append(
            {
                "id": b.id,
                "passenger_id": b.passenger_id,
                "passenger_name": p.full_name if p else "",
                "passenger_phone": p.phone if p else "",
                "seats": b.seats,
                "status": b.status,
                "cancelled_by": b.cancelled_by,
                "cancel_reason": b.cancel_reason,
                "created_at": b.created_at,
            }
        )
    return {
        "id": t.id,
        "driver_id": t.driver_id,
        "driver_name": d.user.full_name if d else "",
        "driver_phone": d.user.phone if d else "",
        "car": d.vehicle.model_name if d and d.vehicle else "",
        "plate": d.vehicle.plate if d and d.vehicle else "",
        "from_text": t.from_text,
        "to_text": t.to_text,
        "from_note": t.from_note,
        "to_note": t.to_note,
        "scheduled_at": t.scheduled_at,
        "seats_total": t.seats_total,
        "seats_available": t.seats_available,
        "price": t.price,
        "note": t.note,
        "status": t.status,
        "created_at": t.created_at,
        "bookings": booking_rows,
    }


@router.get("/users")
def users(
    q: str | None = None,
    role: str | None = None,
    status: str | None = None,
    page: int = 1,
    limit: int = 20,
    admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    query = db.query(User).options(joinedload(User.driver_profile))
    if q:
        like = f"%{q}%"
        query = query.filter((User.first_name.ilike(like)) | (User.last_name.ilike(like)) | (User.phone.ilike(like)))
    if role == "driver":
        query = query.filter(User.active_role == "driver")
    elif role in ("passenger", "user"):
        query = query.filter(User.active_role != "driver")
    if status == "blocked":
        query = query.filter(User.is_blocked.is_(True))
    elif status == "active":
        query = query.filter(User.is_blocked.is_(False), User.is_active.is_(True))
    total = query.count()
    rows = query.order_by(User.id.desc()).offset((page - 1) * limit).limit(limit).all()
    items = []
    for u in rows:
        items.append(
            {
                "id": u.id,
                "full_name": u.full_name,
                "phone": u.phone,
                "active_role": u.active_role,
                "is_blocked": u.is_blocked,
                "is_active": u.is_active,
                "driver_status": u.driver_profile.status if u.driver_profile else None,
                "referral_code": u.referral_code,
                "avatar_url": _doc_url(u.avatar_path),
                "rating_avg": u.rating_avg if u.rating_avg is not None else 5.0,
                "created_at": u.created_at,
                "last_seen_at": u.last_seen_at,
            }
        )
    return {"total": total, "page": page, "items": items}


@router.post("/users/{user_id}/block", response_model=OkResponse)
def block_user(user_id: int, body: StatusUpdateIn, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(404, "Foydalanuvchi topilmadi.")
    before = {"is_blocked": user.is_blocked}
    user.is_blocked = body.status.upper() == "BLOCK"
    _log(db, admin, "user_block" if user.is_blocked else "user_unblock", "user", user.id, before, {"is_blocked": user.is_blocked, "reason": body.reason})
    db.commit()
    return OkResponse(ok=True)


@router.get("/drivers")
def drivers(status: str | None = None, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    q = db.query(DriverProfile).options(joinedload(DriverProfile.user), joinedload(DriverProfile.vehicle), joinedload(DriverProfile.documents))
    if status:
        q = q.filter(DriverProfile.status == status.upper())
    rows = q.order_by(DriverProfile.id.desc()).limit(200).all()
    return [
        {
            "id": d.id,
            "user_id": d.user_id,
            "full_name": d.user.full_name,
            "phone": d.user.phone,
            "status": d.status,
            "is_online": d.is_online,
            "experience_years": d.experience_years,
            "rating_avg": d.rating_avg,
            "trips_count": d.trips_count,
            "rejection_reason": d.rejection_reason,
            "docs_count": len(d.documents),
            "vehicle": None
            if not d.vehicle
            else {"model": d.vehicle.model_name, "plate": d.vehicle.plate, "seats": d.vehicle.seats, "photo": d.vehicle.photo_path, "photo_url": _doc_url(d.vehicle.photo_path)},
            "photo": d.photo_path,
            "photo_url": _doc_url(d.photo_path),
            "documents": [
                {"type": x.doc_type, "path": x.file_path, "url": _doc_url(x.file_path)}
                for x in d.documents
                if x.doc_type in ("selfie", "vehicle_photo")
            ],
            "created_at": d.created_at,
        }
        for d in rows
    ]


@router.post("/drivers/{driver_id}/approve", response_model=OkResponse)
def approve_driver(driver_id: int, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    d = db.query(DriverProfile).options(joinedload(DriverProfile.user)).filter(DriverProfile.id == driver_id).first()
    if not d:
        raise HTTPException(404, "Haydovchi topilmadi.")
    before = {"status": d.status}
    d.status = "APPROVED"
    d.approved_at = datetime.utcnow()
    d.rejection_reason = None
    notify(db, user_id=d.user_id, title="Tabriklaymiz!", body="Siz haydovchi sifatida tasdiqlandingiz.", type="driver_approved", related_type="driver", related_id=d.id)
    _log(db, admin, "driver_approve", "driver", d.id, before, {"status": "APPROVED"})
    db.commit()
    return OkResponse(ok=True, message="Tasdiqlandi.")


@router.post("/drivers/{driver_id}/reject", response_model=OkResponse)
def reject_driver(driver_id: int, body: StatusUpdateIn, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    if not body.reason or len(body.reason.strip()) < 3:
        raise HTTPException(400, "Rad etish sababi majburiy.")
    d = db.query(DriverProfile).options(joinedload(DriverProfile.user)).filter(DriverProfile.id == driver_id).first()
    if not d:
        raise HTTPException(404, "Haydovchi topilmadi.")
    before = {"status": d.status}
    d.status = "REJECTED"
    d.rejection_reason = body.reason.strip()
    notify(db, user_id=d.user_id, title="Ariza rad etildi", body=d.rejection_reason, type="driver_rejected", related_type="driver", related_id=d.id)
    _log(db, admin, "driver_reject", "driver", d.id, before, {"status": "REJECTED", "reason": d.rejection_reason})
    db.commit()
    return OkResponse(ok=True)


@router.post("/drivers/{driver_id}/suspend", response_model=OkResponse)
def suspend_driver(driver_id: int, body: StatusUpdateIn, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    d = db.get(DriverProfile, driver_id)
    if not d:
        raise HTTPException(404, "Haydovchi topilmadi.")
    d.status = "SUSPENDED"
    d.suspend_reason = body.reason
    d.is_online = False
    notify(db, user_id=d.user_id, title="Akkaunt to‘xtatildi", body=body.reason or "Admin tomonidan to‘xtatildi.", type="driver_suspended")
    _log(db, admin, "driver_suspend", "driver", d.id, None, {"status": "SUSPENDED", "reason": body.reason})
    db.commit()
    return OkResponse(ok=True)


@router.get("/locations")
def locations(pending: bool = False, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    q = db.query(Location).options(joinedload(Location.aliases))
    if pending:
        q = q.filter(Location.is_approved.is_(False))
    rows = q.order_by(Location.id.desc()).limit(300).all()
    return [
        {
            "id": l.id,
            "name": l.name,
            "type": l.type,
            "description": l.description,
            "latitude": l.latitude,
            "longitude": l.longitude,
            "is_approved": l.is_approved,
            "is_active": l.is_active,
            "aliases": [a.alias for a in l.aliases],
            "created_by": l.created_by,
        }
        for l in rows
    ]


@router.post("/locations", response_model=OkResponse)
def create_location(body: LocationCreateIn, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    loc = Location(name=body.name.strip(), type=body.type, description=body.description, latitude=body.latitude, longitude=body.longitude, is_approved=True, is_active=True)
    db.add(loc)
    db.flush()
    for a in body.aliases:
        if a.strip():
            db.add(LocationAlias(location_id=loc.id, alias=a.strip()))
    _log(db, admin, "location_create", "location", loc.id, None, {"name": loc.name})
    db.commit()
    return OkResponse(ok=True, message="Joy qo‘shildi.")


@router.post("/locations/{location_id}/approve", response_model=OkResponse)
def approve_location(location_id: int, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    loc = db.get(Location, location_id)
    if not loc:
        raise HTTPException(404, "Joy topilmadi.")
    loc.is_approved = True
    loc.is_active = True
    if loc.created_by:
        notify(db, user_id=loc.created_by, title="Joy tasdiqlandi", body=f"“{loc.name}” endi barcha foydalanuvchilarga ochiq.", type="location")
    _log(db, admin, "location_approve", "location", loc.id)
    db.commit()
    return OkResponse(ok=True)


@router.post("/locations/{location_id}/reject", response_model=OkResponse)
def reject_location(location_id: int, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    loc = db.get(Location, location_id)
    if not loc:
        raise HTTPException(404, "Joy topilmadi.")
    loc.is_approved = False
    loc.is_active = False
    _log(db, admin, "location_reject", "location", loc.id)
    db.commit()
    return OkResponse(ok=True)


@router.get("/trips")
def admin_trips(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    published = db.query(Trip).order_by(Trip.id.desc()).limit(200).all()
    dids = {t.driver_id for t in published}
    drivers = {
        d.id: d
        for d in db.query(DriverProfile)
        .options(joinedload(DriverProfile.user))
        .filter(DriverProfile.id.in_(dids or {0}))
        .all()
    }
    items = [
        {
            "id": t.id,
            "kind": "trip",
            "driver_id": t.driver_id,
            "driver_name": drivers[t.driver_id].user.full_name if t.driver_id in drivers and drivers[t.driver_id].user else None,
            "driver_phone": drivers[t.driver_id].user.phone if t.driver_id in drivers and drivers[t.driver_id].user else None,
            "from_text": t.from_text,
            "to_text": t.to_text,
            "from_note": t.from_note,
            "to_note": t.to_note,
            "note": t.note,
            "scheduled_at": t.scheduled_at,
            "seats_available": t.seats_available,
            "seats_total": t.seats_total,
            "price": t.price,
            "status": t.status,
            "created_at": t.created_at,
            "passenger_name": None,
        }
        for t in published
    ]
    reqs = db.query(TripRequest).order_by(TripRequest.id.desc()).limit(200).all()
    pids = {r.passenger_id for r in reqs}
    names = {u.id: u.full_name for u in db.query(User).filter(User.id.in_(pids or {0})).all()}
    for r in reqs:
        items.append(
            {
                "id": r.id,
                "kind": "request",
                "driver_id": r.selected_driver_id,
                "from_text": r.from_text,
                "to_text": r.to_text,
                "scheduled_at": r.scheduled_at,
                "seats_available": r.passengers_count,
                "seats_total": r.passengers_count,
                "price": r.agreed_price or r.offered_price or 0,
                "status": r.status,
                "created_at": r.created_at,
                "passenger_name": names.get(r.passenger_id, "—"),
            }
        )
    items.sort(key=lambda x: x.get("created_at") or datetime.min, reverse=True)
    return items[:200]


@router.get("/requests")
def admin_requests(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    rows = db.query(TripRequest).order_by(TripRequest.id.desc()).limit(200).all()
    pids = {r.passenger_id for r in rows}
    names = {u.id: u.full_name for u in db.query(User).filter(User.id.in_(pids or {0})).all()}
    phones = {u.id: u.phone for u in db.query(User).filter(User.id.in_(pids or {0})).all()}
    return [
        {
            "id": r.id,
            "passenger_id": r.passenger_id,
            "passenger_name": names.get(r.passenger_id, "—"),
            "passenger_phone": phones.get(r.passenger_id, "—"),
            "from_text": r.from_text,
            "to_text": r.to_text,
            "scheduled_at": r.scheduled_at,
            "offered_price": r.offered_price,
            "agreed_price": r.agreed_price,
            "status": r.status,
            "selected_driver_id": r.selected_driver_id,
            "created_at": r.created_at,
        }
        for r in rows
    ]


@router.post("/notifications/broadcast", response_model=OkResponse)
def broadcast(body: NotifyBroadcastIn, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    q = db.query(User).filter(User.is_active.is_(True), User.is_blocked.is_(False))
    if body.audience == "user":
        if not body.user_id:
            raise HTTPException(400, "user_id kerak.")
        q = q.filter(User.id == body.user_id)
    elif body.audience == "drivers":
        q = q.join(DriverProfile).filter(DriverProfile.status == "APPROVED")
    elif body.audience == "passengers":
        q = q.filter(User.active_role == "passenger")
    users = q.all()
    for u in users:
        notify(db, user_id=u.id, title=body.title, body=body.body, type=body.type)
    _log(db, admin, "broadcast", "notification", None, None, {"audience": body.audience, "count": len(users)})
    db.commit()
    return OkResponse(ok=True, message=f"{len(users)} ta foydalanuvchiga yuborildi.")


@router.get("/settings")
def get_settings_admin(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    rows = db.query(SystemSetting).all()
    return {r.key: r.value for r in rows}


@router.post("/settings", response_model=OkResponse)
def set_settings(payload: dict, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    for k, v in payload.items():
        row = db.query(SystemSetting).filter(SystemSetting.key == k).first()
        if row:
            row.value = str(v)
        else:
            db.add(SystemSetting(key=k, value=str(v)))
    _log(db, admin, "settings_update", "settings", None, None, payload)
    db.commit()
    return OkResponse(ok=True)


def _export_file(filename: str, headers: list[str], rows: list[list], excel: bool = False):
    buf = io.StringIO()
    buf.write("\ufeff")
    writer = csv.writer(buf)
    writer.writerow(headers)
    writer.writerows(rows)
    mime = "application/vnd.ms-excel" if excel else "text/csv; charset=utf-8"
    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type=mime,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


def _excel(fmt: str) -> bool:
    return (fmt or "csv").lower() in {"xls", "xlsx", "excel"}


@router.get("/export/overview")
def export_overview(fmt: str = "csv", admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    today = datetime.utcnow().date()
    rows = [
        ["Ko‘rsatkich", "Qiymat"],
        ["Jami foydalanuvchilar", db.query(User).count()],
        ["Faol foydalanuvchilar", db.query(User).filter(User.is_active.is_(True), User.is_blocked.is_(False)).count()],
        ["Haydovchilar (tasdiqlangan)", db.query(DriverProfile).filter(DriverProfile.status == "APPROVED").count()],
        ["Haydovchilar (kutilmoqda)", db.query(DriverProfile).filter(DriverProfile.status == "PENDING").count()],
        ["Onlayn haydovchi", db.query(DriverProfile).filter(DriverProfile.is_online.is_(True), DriverProfile.status == "APPROVED").count()],
        ["Jami e’lon safarlar", db.query(Trip).count()],
        ["Faol e’lonlar", db.query(Trip).filter(Trip.status.in_(["OPEN", "FULL", "IN_PROGRESS"])).count()],
        ["Bugungi e’lonlar", db.query(Trip).filter(func.date(Trip.created_at) == today).count()],
        ["Jami buyurtmalar", db.query(TripRequest).count()],
        ["Bugungi buyurtmalar", db.query(TripRequest).filter(func.date(TripRequest.created_at) == today).count()],
        ["Jami tushum", db.query(func.coalesce(func.sum(DriverProfile.total_earnings), 0)).scalar() or 0],
        ["Bonus berilgan", db.query(func.coalesce(func.sum(BonusTransaction.amount), 0)).filter(BonusTransaction.status == "APPROVED", BonusTransaction.amount > 0).scalar() or 0],
        ["Kutilayotgan bonus", db.query(BonusTransaction).filter(BonusTransaction.status == "PENDING").count()],
        ["Eksport vaqti", datetime.utcnow().isoformat(timespec="seconds")],
    ]
    excel = _excel(fmt)
    return _export_file(f"safaron_statistika.{ 'xls' if excel else 'csv' }", rows[0], rows[1:], excel)


@router.get("/export/trips")
def export_trips(fmt: str = "csv", admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    items = admin_trips(admin, db)
    excel = _excel(fmt)
    headers = ["ID", "Turi", "Haydovchi", "Telefon", "Qayerdan", "Qayerga", "Vaqt", "Narx", "Joylar", "Holat", "Yaratilgan"]
    rows = [
        [
            x.get("id"),
            x.get("kind"),
            x.get("driver_name") or x.get("passenger_name") or "",
            x.get("driver_phone") or "",
            x.get("from_text"),
            x.get("to_text"),
            x.get("scheduled_at"),
            x.get("price"),
            f"{x.get('seats_available')}/{x.get('seats_total')}",
            x.get("status"),
            x.get("created_at"),
        ]
        for x in items
    ]
    return _export_file(f"safaron_safarlar.{ 'xls' if excel else 'csv' }", headers, rows, excel)


@router.get("/export/users")
def export_users(fmt: str = "csv", admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    rows = db.query(User).order_by(User.id.desc()).limit(5000).all()
    excel = _excel(fmt)
    headers = ["ID", "Ism", "Familiya", "Telefon", "Rol", "Blok", "Referal", "Reyting", "Ro‘yxat", "Oxirgi faollik"]
    data = [
        [
            u.id,
            u.first_name,
            u.last_name,
            u.phone,
            u.active_role,
            "ha" if u.is_blocked else "yo‘q",
            u.referral_code or "",
            u.rating_avg,
            u.created_at,
            u.last_seen_at,
        ]
        for u in rows
    ]
    return _export_file(f"safaron_foydalanuvchilar.{ 'xls' if excel else 'csv' }", headers, data, excel)


@router.get("/export/drivers")
def export_drivers(fmt: str = "csv", admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    rows = db.query(DriverProfile).options(joinedload(DriverProfile.user), joinedload(DriverProfile.vehicle)).order_by(DriverProfile.id.desc()).limit(2000).all()
    excel = _excel(fmt)
    headers = ["ID", "Ism", "Telefon", "Status", "Online", "Tajriba", "Reyting", "Safarlar", "Daromad", "Mashina", "Raqam"]
    data = [
        [
            d.id,
            d.user.full_name if d.user else "",
            d.user.phone if d.user else "",
            d.status,
            "ha" if d.is_online else "yo‘q",
            d.experience_years,
            d.rating_avg,
            d.trips_count,
            d.total_earnings,
            d.vehicle.model_name if d.vehicle else "",
            d.vehicle.plate if d.vehicle else "",
        ]
        for d in rows
    ]
    return _export_file(f"safaron_haydovchilar.{ 'xls' if excel else 'csv' }", headers, data, excel)


@router.get("/logs")
def logs(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    rows = db.query(AdminLog).order_by(AdminLog.id.desc()).limit(200).all()
    return [
        {
            "id": l.id,
            "admin_id": l.admin_id,
            "action": l.action,
            "object_type": l.object_type,
            "object_id": l.object_id,
            "before_json": l.before_json,
            "after_json": l.after_json,
            "ip": l.ip,
            "created_at": l.created_at,
        }
        for l in rows
    ]
