from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import User, WithdrawalRequest
from app.services.rewards import bonus_summary, public_config, record_gps, referral_summary, request_withdrawal

router = APIRouter(tags=["platform"])


class WithdrawIn(BaseModel):
    telegram_username: str
    amount: int | None = None


class GpsIn(BaseModel):
    local_booking_id: str
    role: str = "passenger"
    phase: str = "START"
    status: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    accuracy_m: float | None = None
    driver_user_id: int | None = None
    passenger_user_id: int | None = None
    device_id: str | None = None


@router.get("/config")
def app_config(db: Session = Depends(get_db)):
    return public_config(db)


@router.get("/referral/me")
def my_referral(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    data = referral_summary(db, user)
    db.commit()
    return data


@router.get("/bonus/me")
def my_bonus(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return bonus_summary(db, user)


@router.post("/bonus/withdraw")
def withdraw(body: WithdrawIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    req = request_withdrawal(db, user, body.telegram_username, body.amount)
    db.commit()
    db.refresh(req)
    return {
        "ok": True,
        "id": req.id,
        "status": req.status,
        "message": "Bonusni yechib olish so‘rovingiz Safaron adminiga yuborildi. Tasdiqlangandan so‘ng to‘lov amalga oshiriladi.",
    }


@router.get("/bonus/withdrawals")
def my_withdrawals(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = (
        db.query(WithdrawalRequest)
        .filter(WithdrawalRequest.user_id == user.id)
        .order_by(WithdrawalRequest.id.desc())
        .limit(50)
        .all()
    )
    return [
        {
            "id": r.id,
            "amount": r.amount,
            "status": r.status,
            "telegram_username": r.telegram_username,
            "admin_note": r.admin_note,
            "created_at": r.created_at.isoformat(),
        }
        for r in rows
    ]


@router.post("/trips/gps")
def gps(body: GpsIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    check = record_gps(db, user, body.model_dump())
    db.commit()
    return {"ok": True, "id": check.id, "status": check.status, "distance_m": check.distance_m}
