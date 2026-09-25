from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from app.config import get_settings
from app.database import get_db
from app.deps import get_approved_driver, get_current_user
from app.models import DriverProfile, DriverResponse, TripRequest, User, Vehicle
from app.schemas import CancelIn, DriverRespondIn, OkResponse, RequestCreateIn, RequestOut, SelectDriverIn, StatusUpdateIn
from app.services.fsm import REQUEST_TRANSITIONS, DRIVER_RESPONSE_TRANSITIONS, assert_transition
from app.services.notify import notify
from app.services.serializers import parse_dt, request_out, response_out

router = APIRouter(prefix="/requests", tags=["requests"])


def _build_request_out(db: Session, req: TripRequest) -> RequestOut:
    responses = []
    for resp in req.responses:
        driver = db.query(DriverProfile).options(joinedload(DriverProfile.user), joinedload(DriverProfile.vehicle)).filter(DriverProfile.id == resp.driver_id).first()
        if not driver:
            continue
        responses.append(response_out(resp, driver, driver.vehicle, driver.user, req.offered_price))
    return request_out(req, responses)


def _expire_if_needed(db: Session, req: TripRequest) -> None:
    if req.status in ("SEARCHING", "DRIVER_ACCEPTED", "REQUESTED") and req.expires_at and req.expires_at < datetime.utcnow():
        assert_transition(REQUEST_TRANSITIONS, req.status, "EXPIRED")
        req.status = "EXPIRED"
        for r in req.responses:
            if r.status in ("PENDING", "ACCEPTED"):
                r.status = "EXPIRED"


@router.post("", response_model=RequestOut)
def create_request(body: RequestCreateIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    from_text = body.from_text.strip()
    to_text = body.to_text.strip()
    if not from_text or not to_text:
        raise HTTPException(400, "Qayerdan va qayerga majburiy.")
    if from_text.lower() == to_text.lower():
        raise HTTPException(400, "Qayerdan va qayerga bir xil bo‘lishi mumkin emas.")
    scheduled = parse_dt(body.scheduled_at)
    if scheduled < datetime.utcnow() - timedelta(minutes=1):
        raise HTTPException(400, "Vaqt o‘tib ketgan.")
    settings = get_settings()
    req = TripRequest(
        passenger_id=user.id,
        from_location_id=body.from_location_id,
        to_location_id=body.to_location_id,
        from_text=from_text,
        to_text=to_text,
        exact_place=body.exact_place,
        scheduled_at=scheduled,
        passengers_count=body.passengers_count,
        has_luggage=body.has_luggage,
        note=body.note,
        offered_price=body.offered_price,
        status="SEARCHING",
        expires_at=datetime.utcnow() + timedelta(seconds=settings.booking_timeout_sec),
    )
    db.add(req)
    db.flush()

    online_drivers = (
        db.query(DriverProfile)
        .filter(DriverProfile.status == "APPROVED", DriverProfile.is_online.is_(True))
        .all()
    )
    # Stale online cleanup
    cutoff = datetime.utcnow() - timedelta(seconds=settings.driver_offline_after_sec)
    live = []
    for d in online_drivers:
        if d.last_seen_at and d.last_seen_at < cutoff:
            d.is_online = False
            continue
        live.append(d)

    for d in live:
        db.add(DriverResponse(request_id=req.id, driver_id=d.id, status="PENDING"))
        notify(
            db,
            user_id=d.user_id,
            title="Yangi yo‘lovchi so‘rovi",
            body=f"{from_text} → {to_text} · {body.offered_price} so‘m",
            type="new_request",
            related_type="request",
            related_id=req.id,
        )

    notify(
        db,
        user_id=user.id,
        title="So‘rovingiz yuborildi!",
        body="Haydovchilar javobi kutilmoqda...",
        type="request",
        related_type="request",
        related_id=req.id,
    )
    db.commit()
    req = db.query(TripRequest).options(joinedload(TripRequest.responses)).filter(TripRequest.id == req.id).one()
    return _build_request_out(db, req)


@router.get("/mine", response_model=list[RequestOut])
def my_requests(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = (
        db.query(TripRequest)
        .options(joinedload(TripRequest.responses))
        .filter(TripRequest.passenger_id == user.id)
        .order_by(TripRequest.created_at.desc())
        .limit(50)
        .all()
    )
    for r in rows:
        _expire_if_needed(db, r)
    db.commit()
    return [_build_request_out(db, r) for r in rows]


@router.get("/inbox", response_model=list[RequestOut])
def driver_inbox(driver: DriverProfile = Depends(get_approved_driver), db: Session = Depends(get_db)):
    if not driver.is_online:
        return []
    resp_ids = db.query(DriverResponse.request_id).filter(
        DriverResponse.driver_id == driver.id,
        DriverResponse.status.in_(["PENDING", "ACCEPTED", "SELECTED", "CONFIRMED"]),
    )
    rows = (
        db.query(TripRequest)
        .options(joinedload(TripRequest.responses))
        .filter(TripRequest.id.in_(resp_ids), TripRequest.status.in_(["SEARCHING", "DRIVER_ACCEPTED", "PASSENGER_SELECTED", "CONFIRMED", "DRIVER_ON_WAY", "PASSENGER_PICKED", "IN_PROGRESS"]))
        .order_by(TripRequest.created_at.desc())
        .limit(50)
        .all()
    )
    out = []
    for r in rows:
        _expire_if_needed(db, r)
        # Only show this driver's perspective for open requests
        out.append(_build_request_out(db, r))
    db.commit()
    return out


@router.get("/{request_id}", response_model=RequestOut)
def get_request(request_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    req = db.query(TripRequest).options(joinedload(TripRequest.responses)).filter(TripRequest.id == request_id).first()
    if not req:
        raise HTTPException(404, "Ma'lumot topilmadi.")
    driver = db.query(DriverProfile).filter(DriverProfile.user_id == user.id).first()
    if req.passenger_id != user.id and (not driver or not any(r.driver_id == driver.id for r in req.responses)):
        raise HTTPException(403, "Bu amalni bajarish huquqingiz yo‘q.")
    _expire_if_needed(db, req)
    db.commit()
    return _build_request_out(db, req)


@router.post("/{request_id}/respond", response_model=RequestOut)
def respond(request_id: int, body: DriverRespondIn, driver: DriverProfile = Depends(get_approved_driver), db: Session = Depends(get_db)):
    if not driver.is_online:
        raise HTTPException(400, "Avval onlayn holatga o‘ting.")
    req = db.query(TripRequest).options(joinedload(TripRequest.responses)).filter(TripRequest.id == request_id).first()
    if not req:
        raise HTTPException(404, "So‘rov topilmadi.")
    _expire_if_needed(db, req)
    if req.status not in ("SEARCHING", "DRIVER_ACCEPTED"):
        raise HTTPException(400, "Bu so‘rovga javob berib bo‘lmaydi.")
    resp = next((r for r in req.responses if r.driver_id == driver.id), None)
    if resp is None:
        # Late join for online driver who wasn't initially notified
        resp = DriverResponse(request_id=req.id, driver_id=driver.id, status="PENDING")
        db.add(resp)
        db.flush()
        req.responses.append(resp)
    if resp.status not in ("PENDING",):
        raise HTTPException(400, "Siz allaqachon javob bergansiz.")

    action = body.action.lower()
    if action == "reject":
        assert_transition(DRIVER_RESPONSE_TRANSITIONS, resp.status, "REJECTED")
        resp.status = "REJECTED"
        db.commit()
        return _build_request_out(db, req)

    if action != "accept":
        raise HTTPException(400, "action: accept yoki reject.")
    assert_transition(DRIVER_RESPONSE_TRANSITIONS, resp.status, "ACCEPTED")
    resp.status = "ACCEPTED"
    if body.offered_price is not None:
        resp.offered_price = body.offered_price
    resp.message = body.message
    if req.status == "SEARCHING":
        assert_transition(REQUEST_TRANSITIONS, req.status, "DRIVER_ACCEPTED")
        req.status = "DRIVER_ACCEPTED"

    notify(
        db,
        user_id=req.passenger_id,
        title="Haydovchi topildi",
        body=f"{driver.user.full_name if driver.user else 'Haydovchi'} so‘rovni qabul qildi.",
        type="driver_accepted",
        related_type="request",
        related_id=req.id,
    )
    notify(
        db,
        user_id=driver.user_id,
        title="So‘rov qabul qilindi",
        body="Yo‘lovchi tanlovi kutilmoqda.",
        type="waiting_selection",
        related_type="request",
        related_id=req.id,
    )
    db.commit()
    req = db.query(TripRequest).options(joinedload(TripRequest.responses)).filter(TripRequest.id == request_id).one()
    return _build_request_out(db, req)


@router.post("/{request_id}/select", response_model=RequestOut)
def select_driver(request_id: int, body: SelectDriverIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    req = db.query(TripRequest).options(joinedload(TripRequest.responses)).filter(TripRequest.id == request_id).first()
    if not req or req.passenger_id != user.id:
        raise HTTPException(403, "Bu amalni bajarish huquqingiz yo‘q.")
    if req.status not in ("DRIVER_ACCEPTED", "SEARCHING"):
        raise HTTPException(400, "Haydovchini tanlash mumkin emas.")
    chosen = next((r for r in req.responses if r.driver_id == body.driver_id and r.status == "ACCEPTED"), None)
    if not chosen:
        raise HTTPException(400, "Tanlangan haydovchi topilmadi yoki qabul qilmagan.")

    assert_transition(REQUEST_TRANSITIONS, req.status, "PASSENGER_SELECTED")
    req.status = "PASSENGER_SELECTED"
    req.selected_driver_id = body.driver_id
    req.agreed_price = chosen.offered_price if chosen.offered_price is not None else req.offered_price

    assert_transition(DRIVER_RESPONSE_TRANSITIONS, chosen.status, "SELECTED")
    chosen.status = "SELECTED"

    for r in req.responses:
        if r.id == chosen.id:
            continue
        if r.status == "ACCEPTED":
            r.status = "NOT_SELECTED"
            d = db.get(DriverProfile, r.driver_id)
            if d:
                notify(db, user_id=d.user_id, title="Safar boshqa haydovchiga berildi", body="Yo‘lovchi boshqa haydovchini tanladi.", type="not_selected", related_type="request", related_id=req.id)
        elif r.status == "PENDING":
            r.status = "CANCELLED"

    # Auto confirm
    assert_transition(REQUEST_TRANSITIONS, req.status, "CONFIRMED")
    req.status = "CONFIRMED"
    chosen.status = "CONFIRMED"

    selected_driver = db.get(DriverProfile, body.driver_id)
    if selected_driver:
        notify(db, user_id=selected_driver.user_id, title="Yo‘lovchi sizni tanladi!", body="Safar tasdiqlandi.", type="selected", related_type="request", related_id=req.id)
    notify(db, user_id=user.id, title="Safar tasdiqlandi!", body=f"{req.from_text} → {req.to_text}", type="confirmed", related_type="request", related_id=req.id)
    db.commit()
    req = db.query(TripRequest).options(joinedload(TripRequest.responses)).filter(TripRequest.id == request_id).one()
    return _build_request_out(db, req)


@router.post("/{request_id}/status", response_model=RequestOut)
def advance_status(request_id: int, body: StatusUpdateIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    req = db.query(TripRequest).options(joinedload(TripRequest.responses)).filter(TripRequest.id == request_id).first()
    if not req:
        raise HTTPException(404, "So‘rov topilmadi.")
    driver = db.query(DriverProfile).filter(DriverProfile.user_id == user.id).first()
    if not driver or req.selected_driver_id != driver.id:
        raise HTTPException(403, "Faqat tanlangan haydovchi statusni o‘zgartira oladi.")
    new = body.status.upper()
    assert_transition(REQUEST_TRANSITIONS, req.status, new)
    req.status = new
    titles = {
        "DRIVER_ON_WAY": ("Haydovchi yo‘lga chiqdi", "Yo‘lovchini olishga yo‘l oldim"),
        "PASSENGER_PICKED": ("Yo‘lovchi olindi", "Haydovchi sizni oldi"),
        "IN_PROGRESS": ("Safar boshlandi", "Safar davom etmoqda"),
        "COMPLETED": ("Safar yakunlandi", "Safaringiz yakunlandi. Baholash mumkin."),
    }
    if new in titles:
        notify(db, user_id=req.passenger_id, title=titles[new][0], body=titles[new][1], type=new.lower(), related_type="request", related_id=req.id)
    if new == "COMPLETED":
        price = req.agreed_price or req.offered_price
        driver.trips_count += 1
        driver.total_earnings += price
    db.commit()
    req = db.query(TripRequest).options(joinedload(TripRequest.responses)).filter(TripRequest.id == request_id).one()
    return _build_request_out(db, req)


@router.post("/{request_id}/cancel", response_model=OkResponse)
def cancel_request(request_id: int, body: CancelIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    req = db.query(TripRequest).options(joinedload(TripRequest.responses)).filter(TripRequest.id == request_id).first()
    if not req:
        raise HTTPException(404, "So‘rov topilmadi.")
    if req.status in ("COMPLETED", "CANCELLED", "EXPIRED"):
        raise HTTPException(400, "Bu so‘rovni bekor qilib bo‘lmaydi.")
    driver = db.query(DriverProfile).filter(DriverProfile.user_id == user.id).first()
    is_passenger = req.passenger_id == user.id
    is_selected_driver = driver and req.selected_driver_id == driver.id
    if not is_passenger and not is_selected_driver:
        raise HTTPException(403, "Bu amalni bajarish huquqingiz yo‘q.")
    assert_transition(REQUEST_TRANSITIONS, req.status, "CANCELLED")
    req.status = "CANCELLED"
    req.cancelled_by = "passenger" if is_passenger else "driver"
    req.cancel_reason = body.reason
    req.cancelled_at = datetime.utcnow()
    notified_drivers: set[int] = set()
    for r in req.responses:
        if r.status in ("PENDING", "ACCEPTED", "SELECTED", "CONFIRMED"):
            r.status = "CANCELLED"
            if is_passenger:
                d = db.get(DriverProfile, r.driver_id)
                if d and d.user_id not in notified_drivers:
                    notify(
                        db,
                        user_id=d.user_id,
                        title="Safar bekor qilindi",
                        body=body.reason,
                        type="cancelled",
                        related_type="request",
                        related_id=req.id,
                    )
                    notified_drivers.add(d.user_id)
    if is_passenger and req.selected_driver_id:
        d = db.get(DriverProfile, req.selected_driver_id)
        if d and d.user_id not in notified_drivers:
            notify(
                db,
                user_id=d.user_id,
                title="Safar bekor qilindi",
                body=body.reason,
                type="cancelled",
                related_type="request",
                related_id=req.id,
            )
    if is_selected_driver:
        notify(
            db,
            user_id=req.passenger_id,
            title="Safar bekor qilindi",
            body=body.reason,
            type="cancelled",
            related_type="request",
            related_id=req.id,
        )
    db.commit()
    return OkResponse(ok=True, message="Bekor qilindi.")
