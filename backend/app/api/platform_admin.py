import csv
import io
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_admin, require_super_admin
from app.models import (
    AdminLog,
    AdminUser,
    BonusRule,
    BonusTransaction,
    FeatureFlag,
    FraudEvent,
    FraudRule,
    Referral,
    SystemSetting,
    TripCheck,
    User,
    WithdrawalRequest,
)
from app.services.rewards import admin_withdrawal, approve_bonus

router = APIRouter(prefix="/admin/platform", tags=["admin-platform"])


def _log(db, admin, request: Request, action, before=None, after=None, object_type=None, object_id=None):
    import json

    ip = request.client.host if request.client else None
    db.add(
        AdminLog(
            admin_id=admin.id,
            action=action,
            object_type=object_type,
            object_id=object_id,
            before_json=json.dumps(before, ensure_ascii=False, default=str) if before is not None else None,
            after_json=json.dumps(after, ensure_ascii=False, default=str) if after is not None else None,
            ip=ip,
        )
    )


class FlagIn(BaseModel):
    enabled: bool


class RuleIn(BaseModel):
    amount: int | None = None
    required_trips: int | None = None
    enabled: bool | None = None
    repeatable: bool | None = None


class NoteIn(BaseModel):
    note: str | None = None


class SettingIn(BaseModel):
    key: str
    value: str


@router.get("/stats")
def stats(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    today = datetime.utcnow().date()
    return {
        "users": db.query(User).filter(User.deleted_at.is_(None)).count(),
        "referrals": db.query(Referral).filter(Referral.deleted_at.is_(None)).count(),
        "pending_bonus": db.query(BonusTransaction).filter(BonusTransaction.status == "PENDING").count(),
        "pending_withdrawal": db.query(WithdrawalRequest).filter(WithdrawalRequest.status == "PENDING").count(),
        "fraud_open": db.query(FraudEvent).filter(FraudEvent.status == "OPEN").count(),
        "verified_trips": db.query(TripCheck).filter(TripCheck.status == "VERIFIED").count(),
        "bonus_paid": db.query(func.coalesce(func.sum(BonusTransaction.amount), 0))
        .filter(BonusTransaction.status == "APPROVED", BonusTransaction.amount > 0)
        .scalar(),
        "new_users_today": db.query(User).filter(func.date(User.created_at) == today).count(),
    }


_DEFAULT_FLAGS = (
    ("bonus", True, "Bonus menyusi"),
    ("referral", True, "Taklif kodi"),
    ("withdrawal", True, "Bonus yechish"),
)


def _ensure_flags(db: Session):
    existing = {f.key: f for f in db.query(FeatureFlag).all()}
    added = False
    for key, enabled, desc in _DEFAULT_FLAGS:
        if key not in existing:
            db.add(FeatureFlag(key=key, enabled=enabled, description=desc))
            added = True
    if added:
        db.commit()


@router.get("/flags")
def flags(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    _ensure_flags(db)
    return [{"key": f.key, "enabled": f.enabled, "description": f.description} for f in db.query(FeatureFlag).all()]


@router.patch("/flags/{key}")
def set_flag(key: str, body: FlagIn, request: Request, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    row = db.query(FeatureFlag).filter(FeatureFlag.key == key).first()
    if not row:
        row = FeatureFlag(key=key, enabled=body.enabled, description=key)
        db.add(row)
        before = None
    else:
        before = row.enabled
        row.enabled = body.enabled
    db.flush()
    _log(db, admin, request, "feature_flag", {"enabled": before}, {"enabled": body.enabled}, "feature_flag", row.id)
    db.commit()
    return {"ok": True, "key": key, "enabled": row.enabled}


@router.get("/bonus-rules")
def rules(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    return [
        {
            "key": r.key,
            "title": r.title,
            "amount": r.amount,
            "required_trips": r.required_trips,
            "enabled": r.enabled,
            "repeatable": r.repeatable,
        }
        for r in db.query(BonusRule).all()
    ]


@router.patch("/bonus-rules/{key}")
def set_rule(key: str, body: RuleIn, request: Request, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    row = db.query(BonusRule).filter(BonusRule.key == key).first()
    if not row:
        raise HTTPException(404, "Qoida topilmadi")
    before = {"amount": row.amount, "required_trips": row.required_trips, "enabled": row.enabled}
    if body.amount is not None:
        row.amount = body.amount
    if body.required_trips is not None:
        row.required_trips = body.required_trips
    if body.enabled is not None:
        row.enabled = body.enabled
    if body.repeatable is not None:
        row.repeatable = body.repeatable
    _log(db, admin, request, "bonus_rule", before, {"amount": row.amount, "required_trips": row.required_trips}, "bonus_rule", row.id)
    db.commit()
    return {"ok": True}


@router.get("/bonuses")
def bonuses(status: str = "PENDING", q: str = "", page: int = 1, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    query = db.query(BonusTransaction).filter(BonusTransaction.status == status)
    total = query.count()
    rows = query.order_by(BonusTransaction.id.desc()).offset((page - 1) * 20).limit(20).all()
    return {
        "total": total,
        "items": [
            {
                "id": t.id,
                "user_id": t.user_id,
                "amount": t.amount,
                "source": t.source,
                "status": t.status,
                "description": t.description,
                "created_at": t.created_at.isoformat(),
            }
            for t in rows
            if not q or q in str(t.user_id) or (t.description or "").lower().find(q.lower()) >= 0
        ],
    }


@router.post("/bonuses/{tx_id}/approve")
def approve(tx_id: int, request: Request, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    tx = db.get(BonusTransaction, tx_id)
    if not tx:
        raise HTTPException(404, "Topilmadi")
    approve_bonus(db, tx, admin.id, True, None)
    _log(db, admin, request, "bonus_approve", None, {"id": tx_id}, "bonus", tx_id)
    db.commit()
    return {"ok": True}


@router.post("/bonuses/{tx_id}/reject")
def reject_bonus(tx_id: int, body: NoteIn, request: Request, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    tx = db.get(BonusTransaction, tx_id)
    if not tx:
        raise HTTPException(404, "Topilmadi")
    approve_bonus(db, tx, admin.id, False, body.note)
    _log(db, admin, request, "bonus_reject", None, {"id": tx_id, "note": body.note}, "bonus", tx_id)
    db.commit()
    return {"ok": True}


@router.get("/withdrawals")
def withdrawals(status: str = "PENDING", page: int = 1, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    query = db.query(WithdrawalRequest)
    if status != "ALL":
        query = query.filter(WithdrawalRequest.status == status)
    total = query.count()
    rows = query.order_by(WithdrawalRequest.id.desc()).offset((page - 1) * 20).limit(20).all()
    return {
        "total": total,
        "items": [
            {
                "id": r.id,
                "user_id": r.user_id,
                "amount": r.amount,
                "status": r.status,
                "telegram_username": r.telegram_username,
                "admin_note": r.admin_note,
                "created_at": r.created_at.isoformat(),
            }
            for r in rows
        ],
    }


@router.post("/withdrawals/{wid}/{action}")
def withdrawal_action(wid: int, action: str, body: NoteIn, request: Request, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    row = db.get(WithdrawalRequest, wid)
    if not row:
        raise HTTPException(404, "Topilmadi")
    before = row.status
    admin_withdrawal(db, row, action, body.note, admin.id)
    _log(db, admin, request, f"withdrawal_{action}", {"status": before}, {"status": row.status}, "withdrawal", wid)
    db.commit()
    return {"ok": True, "status": row.status}


@router.get("/referrals")
def referrals(page: int = 1, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    query = db.query(Referral).filter(Referral.deleted_at.is_(None))
    total = query.count()
    rows = query.order_by(Referral.id.desc()).offset((page - 1) * 20).limit(20).all()
    return {
        "total": total,
        "items": [
            {"id": r.id, "referrer_id": r.referrer_id, "referred_id": r.referred_id, "code": r.code, "status": r.status}
            for r in rows
        ],
    }


@router.get("/fraud")
def fraud(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    rows = db.query(FraudEvent).order_by(FraudEvent.id.desc()).limit(50).all()
    return [
        {"id": e.id, "user_id": e.user_id, "code": e.code, "status": e.status, "details": e.details, "severity": e.severity}
        for e in rows
    ]


@router.post("/fraud/{eid}/close")
def close_fraud(eid: int, request: Request, admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    row = db.get(FraudEvent, eid)
    if not row:
        raise HTTPException(404, "Topilmadi")
    row.status = "REVIEWED"
    _log(db, admin, request, "fraud_close", None, {"id": eid}, "fraud", eid)
    db.commit()
    return {"ok": True}


@router.get("/settings")
def settings_list(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    return [{"key": s.key, "value": s.value} for s in db.query(SystemSetting).all()]


@router.put("/settings")
def settings_put(body: SettingIn, request: Request, admin: AdminUser = Depends(require_super_admin), db: Session = Depends(get_db)):
    row = db.query(SystemSetting).filter(SystemSetting.key == body.key).first()
    before = row.value if row else None
    if row:
        row.value = body.value
    else:
        row = SystemSetting(key=body.key, value=body.value)
        db.add(row)
    _log(db, admin, request, "setting", {"value": before}, {"value": body.value}, "setting", None)
    db.commit()
    return {"ok": True}


@router.get("/fraud-rules")
def fraud_rules(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    return [{"key": r.key, "value": r.value, "enabled": r.enabled} for r in db.query(FraudRule).all()]


@router.get("/export/withdrawals.csv")
def export_wd(admin: AdminUser = Depends(get_current_admin), db: Session = Depends(get_db)):
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["id", "user_id", "amount", "status", "telegram", "note"])
    for r in db.query(WithdrawalRequest).all():
        w.writerow([r.id, r.user_id, r.amount, r.status, r.telegram_username, r.admin_note or ""])
    buf.seek(0)
    return StreamingResponse(iter([buf.getvalue()]), media_type="text/csv", headers={"Content-Disposition": "attachment; filename=withdrawals.csv"})
