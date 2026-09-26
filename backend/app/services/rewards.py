"""Referral, bonus, withdrawal, feature flags, GPS fraud."""
from __future__ import annotations

import math
import random
import string
from datetime import datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import (
    BonusRule,
    BonusTransaction,
    BonusWallet,
    FeatureFlag,
    FraudEvent,
    FraudRule,
    Notification,
    Referral,
    SystemSetting,
    TripCheck,
    TripLocationPoint,
    User,
    UserDevice,
    WithdrawalRequest,
)

_ALLOWED = {
    "REQUESTED": {"ACCEPTED_BY_DRIVER", "CANCELLED"},
    "ACCEPTED_BY_DRIVER": {"STARTED", "CANCELLED"},
    "STARTED": {"IN_PROGRESS", "COMPLETED", "CANCELLED"},
    "IN_PROGRESS": {"COMPLETED", "CANCELLED"},
    "COMPLETED": {"VERIFIED", "FRAUD_REVIEW"},
    "VERIFIED": set(),
    "FRAUD_REVIEW": {"VERIFIED", "CANCELLED"},
    "CANCELLED": set(),
}


def flag_on(db: Session, key: str) -> bool:
    row = db.query(FeatureFlag).filter(FeatureFlag.key == key).first()
    return bool(row and row.enabled)


def setting(db: Session, key: str, default: str) -> str:
    row = db.query(SystemSetting).filter(SystemSetting.key == key).first()
    return row.value if row else default


def _wallet(db: Session, user_id: int) -> BonusWallet:
    w = db.query(BonusWallet).filter(BonusWallet.user_id == user_id).first()
    if w:
        return w
    w = BonusWallet(user_id=user_id, available=0, held=0, lifetime_earned=0)
    db.add(w)
    db.flush()
    return w


def new_referral_code(db: Session) -> str:
    alphabet = string.ascii_uppercase
    for _ in range(40):
        code = f"{''.join(random.choice(alphabet) for _ in range(3))}-{random.randint(100, 999)}"
        if not db.query(User).filter(User.referral_code == code).first():
            return code
    return f"S{random.randint(100000, 999999)}"


def ensure_code(db: Session, user: User) -> str:
    if user.referral_code:
        return user.referral_code
    user.referral_code = new_referral_code(db)
    db.flush()
    return user.referral_code


def attach_referral(db: Session, user: User, code: str | None) -> None:
    raw = (code or "").strip().upper()
    if not raw:
        return
    if not flag_on(db, "referral"):
        return
    if user.referred_by_user_id:
        raise HTTPException(400, "Referral keyinchalik o‘zgartirib bo‘lmaydi.")
    owner = db.query(User).filter(User.referral_code == raw, User.deleted_at.is_(None)).first()
    if not owner:
        raise HTTPException(400, "Taklif kodi topilmadi")
    if owner.id == user.id:
        raise HTTPException(400, "O‘z referral kodingizni ishlata olmaysiz.")
    user.referred_by_user_id = owner.id
    db.add(Referral(referrer_id=owner.id, referred_id=user.id, code=raw, status="PENDING"))


def public_config(db: Session) -> dict:
    flags = {f.key: f.enabled for f in db.query(FeatureFlag).all()}
    return {
        "flags": flags,
        "maintenance": flags.get("maintenance", False),
        "maintenance_message": setting(db, "maintenance_message", "Safaron texnik xizmat ko‘rsatish rejimida."),
        "latest_version": setting(db, "latest_version", "1.0.0"),
        "minimum_version": setting(db, "minimum_version", "1.0.0"),
        "version_code": int(setting(db, "version_code", "1") or "1"),
        "update_url": setting(db, "update_url", "/api/app/apk"),
        "force_update": setting(db, "force_update", "false") == "true",
        "telegram_admin": setting(db, "telegram_admin_username", "Safaron_bot"),
        "bonus_enabled": flags.get("bonus", True),
        "referral_enabled": flags.get("referral", True),
        "withdrawal_enabled": flags.get("withdrawal", True),
        "withdrawal_min": int(setting(db, "withdrawal_min", "10000") or "10000"),
        "vehicle_models": [
            s.strip()
            for s in setting(
                db,
                "vehicle_models",
                "Chevrolet Cobalt,Chevrolet Nexia,Chevrolet Spark,Chevrolet Tracker,BYD Chazor,Chevrolet Lacetti",
            ).split(",")
            if s.strip()
        ],
        "bonus_rules": [
            {
                "key": r.key,
                "title": r.title,
                "amount": r.amount,
                "required_trips": r.required_trips,
                "enabled": r.enabled,
            }
            for r in db.query(BonusRule).order_by(BonusRule.id.asc()).all()
            if r.enabled
        ],
    }


def bonus_summary(db: Session, user: User) -> dict:
    if not flag_on(db, "bonus"):
        return {"enabled": False}
    w = _wallet(db, user.id)
    txs = (
        db.query(BonusTransaction)
        .filter(BonusTransaction.user_id == user.id)
        .order_by(BonusTransaction.id.desc())
        .limit(50)
        .all()
    )
    return {
        "enabled": True,
        "available": w.available,
        "held": w.held,
        "lifetime_earned": w.lifetime_earned,
        "history": [
            {
                "id": t.id,
                "amount": t.amount,
                "type": t.type,
                "source": t.source,
                "status": t.status,
                "description": t.description,
                "created_at": t.created_at.isoformat(),
            }
            for t in txs
        ],
    }


def referral_summary(db: Session, user: User) -> dict:
    if not flag_on(db, "referral"):
        return {"enabled": False}
    code = ensure_code(db, user)
    rows = db.query(Referral).filter(Referral.referrer_id == user.id, Referral.deleted_at.is_(None)).all()
    earned = (
        db.query(BonusTransaction)
        .filter(
            BonusTransaction.user_id == user.id,
            BonusTransaction.source == "REFERRAL",
            BonusTransaction.status == "APPROVED",
        )
        .all()
    )
    return {
        "enabled": True,
        "code": code,
        "invited": len(rows),
        "successful": sum(1 for r in rows if r.status in ("QUALIFIED", "APPROVED")),
        "bonus_earned": sum(t.amount for t in earned if t.amount > 0),
    }


def request_withdrawal(db: Session, user: User, telegram: str, amount: int | None) -> WithdrawalRequest:
    if not flag_on(db, "withdrawal") or not flag_on(db, "bonus"):
        raise HTTPException(400, "Bonus yechish hozir o‘chirilgan.")
    nick = telegram.strip().lstrip("@")
    if len(nick) < 3:
        raise HTTPException(400, "Telegram username kiriting.")
    active = (
        db.query(WithdrawalRequest)
        .filter(WithdrawalRequest.user_id == user.id, WithdrawalRequest.status.in_(("PENDING", "APPROVED")))
        .first()
    )
    if active:
        raise HTTPException(400, "Sizda faol withdrawal so‘rovi mavjud.")
    w = _wallet(db, user.id)
    if w.available <= 0:
        raise HTTPException(400, "Sizda yechib olish uchun bonus mablag‘i mavjud emas.")
    take = amount or w.available
    mn = int(setting(db, "withdrawal_min", "1000") or "1000")
    mx = int(setting(db, "withdrawal_max", "5000000") or "5000000")
    if take < mn or take > mx or take > w.available:
        raise HTTPException(400, f"Summa {mn} dan {min(mx, w.available)} so‘mgacha bo‘lishi kerak.")
    w.available -= take
    w.held += take
    user.telegram_username = nick
    req = WithdrawalRequest(user_id=user.id, amount=take, telegram_username=nick, status="PENDING")
    db.add(req)
    db.flush()
    db.add(
        BonusTransaction(
            user_id=user.id,
            amount=-take,
            type="HOLD",
            source="WITHDRAWAL",
            status="POSTED",
            description="Withdrawal so‘rovi",
        )
    )
    return req


def admin_withdrawal(db: Session, req: WithdrawalRequest, action: str, note: str | None, admin_id: int) -> None:
    w = _wallet(db, req.user_id)
    if action == "approve" and req.status == "PENDING":
        req.status = "APPROVED"
    elif action == "paid" and req.status in ("PENDING", "APPROVED"):
        req.status = "PAID"
        w.held = max(0, w.held - req.amount)
    elif action == "reject" and req.status in ("PENDING", "APPROVED"):
        req.status = "REJECTED"
        w.held = max(0, w.held - req.amount)
        w.available += req.amount
        db.add(
            BonusTransaction(
                user_id=req.user_id,
                amount=req.amount,
                type="RELEASE",
                source="WITHDRAWAL",
                status="POSTED",
                description=note or "Withdrawal rad etildi",
                approved_by=admin_id,
                approved_at=datetime.utcnow(),
            )
        )
    elif action == "cancel" and req.status == "PENDING":
        req.status = "CANCELLED"
        w.held = max(0, w.held - req.amount)
        w.available += req.amount
    else:
        raise HTTPException(400, "Bu holatdan o‘tkazib bo‘lmaydi.")
    req.admin_note = note
    req.updated_at = datetime.utcnow()
    title = "Bonus yechish"
    body = f"So‘rov #{req.id}: {req.status}"
    if note:
        body += f". {note}"
    db.add(Notification(user_id=req.user_id, title=title, body=body, type="withdrawal"))


def _haversine(a_lat, a_lng, b_lat, b_lng) -> float:
    r = 6371000
    p1, p2 = math.radians(a_lat), math.radians(b_lat)
    dp = math.radians(b_lat - a_lat)
    dl = math.radians(b_lng - a_lng)
    x = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(x))


def _rule_float(db: Session, key: str, default: float) -> float:
    row = db.query(FraudRule).filter(FraudRule.key == key).first()
    if not row or not row.enabled:
        return default
    try:
        return float(row.value)
    except ValueError:
        return default


def record_gps(db: Session, user: User, body: dict) -> TripCheck:
    booking = str(body.get("local_booking_id") or "")
    if not booking:
        raise HTTPException(400, "Safar identifikatori yo‘q.")
    role = body.get("role") or "passenger"
    phase = body.get("phase") or "START"
    lat = body.get("latitude")
    lng = body.get("longitude")
    acc = body.get("accuracy_m")
    if lat is None or lng is None:
        raise HTTPException(400, "Joylashuv xizmatini yoqing.")
    min_acc = _rule_float(db, "gps_min_accuracy_m", 80)
    if acc is not None and float(acc) > min_acc:
        raise HTTPException(400, "Joylashuv aniqligi yetarli emas. Iltimos, GPS signalini yaxshilang.")
    driver_id = body.get("driver_user_id")
    if driver_id and int(driver_id) == user.id and role == "passenger":
        raise HTTPException(400, "Bir qurilmada o‘z safaringizni o‘zingiz qabul qila olmaysiz.")
    check = (
        db.query(TripCheck)
        .filter(TripCheck.local_booking_id == booking, TripCheck.deleted_at.is_(None))
        .first()
    )
    if check is None:
        check = TripCheck(
            local_booking_id=booking,
            passenger_user_id=user.id if role == "passenger" else int(body.get("passenger_user_id") or user.id),
            driver_user_id=int(driver_id) if driver_id else (user.id if role == "driver" else None),
            status="REQUESTED",
            device_id=body.get("device_id"),
        )
        db.add(check)
        db.flush()
    if check.passenger_user_id == check.driver_user_id and check.driver_user_id:
        db.add(FraudEvent(user_id=user.id, trip_check_id=check.id, code="SELF_TRIP", severity="high", details="same user"))
        raise HTTPException(400, "O‘z safaringizni o‘zingiz qabul qila olmaysiz.")
    target = body.get("status") or ("STARTED" if phase == "START" else "COMPLETED" if phase == "END" else check.status)
    allowed = _ALLOWED.get(check.status, set())
    if target != check.status and target not in allowed and not (check.status == "REQUESTED" and target == "STARTED"):
        if target not in allowed and target != check.status:
            # STARTED from REQUESTED is allowed above; other illegal jumps rejected
            if not (check.status == "REQUESTED" and target in ("STARTED", "ACCEPTED_BY_DRIVER")):
                raise HTTPException(400, "Safar holatini orqaga qaytarib bo‘lmaydi.")
    if target != check.status and (target in allowed or (check.status == "REQUESTED" and target in ("STARTED", "ACCEPTED_BY_DRIVER"))):
        check.status = target
    db.add(
        TripLocationPoint(
            trip_check_id=check.id,
            user_id=user.id,
            role=role,
            phase=phase,
            latitude=float(lat),
            longitude=float(lng),
            accuracy_m=float(acc) if acc is not None else None,
        )
    )
    if body.get("device_id"):
        dev = (
            db.query(UserDevice)
            .filter(UserDevice.user_id == user.id, UserDevice.device_id == body["device_id"])
            .first()
        )
        if dev:
            dev.last_role = role
            dev.last_seen_at = datetime.utcnow()
        else:
            db.add(UserDevice(user_id=user.id, device_id=body["device_id"], last_role=role))
    if phase == "END":
        db.flush()
        _finish_check(db, check)
    return check


def _finish_check(db: Session, check: TripCheck) -> None:
    points = db.query(TripLocationPoint).filter(TripLocationPoint.trip_check_id == check.id).all()
    starts = [p for p in points if p.phase == "START"]
    ends = [p for p in points if p.phase == "END"]
    if starts and ends:
        check.distance_m = _haversine(starts[0].latitude, starts[0].longitude, ends[-1].latitude, ends[-1].longitude)
        delta = ends[-1].recorded_at - starts[0].recorded_at
        check.duration_sec = int(abs(delta.total_seconds()))
    min_dist = _rule_float(db, "min_distance_m", 300)
    min_dur = _rule_float(db, "min_duration_sec", 120)
    suspicious = check.distance_m is None or check.duration_sec is None
    if check.distance_m is not None and check.distance_m < min_dist:
        suspicious = True
    if check.duration_sec is not None and check.duration_sec < min_dur:
        suspicious = True
    if suspicious:
        check.status = "FRAUD_REVIEW"
        db.add(
            FraudEvent(
                user_id=check.passenger_user_id,
                trip_check_id=check.id,
                code="SHORT_TRIP",
                details=f"distance={check.distance_m} duration={check.duration_sec}",
            )
        )
        return
    check.status = "VERIFIED"
    _grant_pending_bonuses(db, check)


def _pending_credit(db: Session, user_id: int, amount: int, source: str, description: str, referral_id: int | None = None) -> None:
    if amount <= 0 or not flag_on(db, "bonus"):
        return
    db.add(
        BonusTransaction(
            user_id=user_id,
            amount=amount,
            type="CREDIT",
            source=source,
            status="PENDING",
            related_referral_id=referral_id,
            description=description,
        )
    )


def _grant_pending_bonuses(db: Session, check: TripCheck) -> None:
    passenger = db.get(User, check.passenger_user_id)
    if not passenger:
        return
    first = passenger.verified_trip_count == 0
    passenger.verified_trip_count += 1
    if first:
        rule = db.query(BonusRule).filter(BonusRule.key == "passenger_first_trip").first()
        if rule and rule.enabled:
            _pending_credit(db, passenger.id, rule.amount, "FIRST_TRIP", "Birinchi safar bonusi")
        ref = db.query(Referral).filter(Referral.referred_id == passenger.id, Referral.status == "PENDING").first()
        if ref and flag_on(db, "referral"):
            ref.status = "QUALIFIED"
            pr = db.query(BonusRule).filter(BonusRule.key == "passenger_referral").first()
            if pr and pr.enabled:
                _pending_credit(db, ref.referrer_id, pr.amount, "REFERRAL", "Referral bonus", ref.id)
                _pending_credit(db, ref.referred_id, pr.amount, "REFERRAL", "Taklif bonusi", ref.id)
    if check.driver_user_id:
        driver = db.get(User, check.driver_user_id)
        if driver:
            driver.verified_trip_count += 1
            rule = db.query(BonusRule).filter(BonusRule.key == "driver_milestone").first()
            if rule and rule.enabled and rule.required_trips > 0 and driver.verified_trip_count % rule.required_trips == 0:
                if rule.repeatable or driver.verified_trip_count == rule.required_trips:
                    _pending_credit(db, driver.id, rule.amount, "MILESTONE", f"{rule.required_trips} safar bonusi")


def approve_bonus(db: Session, tx: BonusTransaction, admin_id: int, ok: bool, note: str | None) -> None:
    if tx.status != "PENDING":
        raise HTTPException(400, "Bu bonus allaqachon ko‘rib chiqilgan.")
    tx.approved_by = admin_id
    tx.approved_at = datetime.utcnow()
    if not ok:
        tx.status = "REJECTED"
        if note:
            tx.description = note
        db.add(Notification(user_id=tx.user_id, title="Bonus rad etildi", body=note or "Bonus tasdiqlanmadi.", type="bonus"))
        return
    tx.status = "APPROVED"
    w = _wallet(db, tx.user_id)
    w.available += tx.amount
    w.lifetime_earned += tx.amount
    if tx.related_referral_id:
        ref = db.get(Referral, tx.related_referral_id)
        if ref and ref.status == "QUALIFIED":
            ref.status = "APPROVED"
    db.add(Notification(user_id=tx.user_id, title="Bonus tasdiqlandi", body=tx.description or f"+{tx.amount} so‘m", type="bonus"))
