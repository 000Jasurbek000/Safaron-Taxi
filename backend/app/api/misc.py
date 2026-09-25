from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import Message, Notification, Rating, TripRequest, User, DriverProfile
from app.schemas import MessageIn, MessageOut, NotificationOut, OkResponse, RatingIn

router = APIRouter(tags=["misc"])


@router.get("/notifications", response_model=list[NotificationOut])
def list_notifications(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = (
        db.query(Notification)
        .filter(Notification.user_id == user.id)
        .order_by(Notification.created_at.desc())
        .limit(100)
        .all()
    )
    return [
        NotificationOut(
            id=n.id,
            title=n.title,
            body=n.body,
            type=n.type,
            is_read=n.is_read,
            related_type=n.related_type,
            related_id=n.related_id,
            created_at=n.created_at,
        )
        for n in rows
    ]


@router.get("/notifications/unread-count")
def unread_count(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    c = db.query(Notification).filter(Notification.user_id == user.id, Notification.is_read.is_(False)).count()
    return {"count": c}


@router.post("/notifications/{notification_id}/read", response_model=OkResponse)
def mark_read(notification_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    n = db.get(Notification, notification_id)
    if not n or n.user_id != user.id:
        raise HTTPException(404, "Ma'lumot topilmadi.")
    n.is_read = True
    db.commit()
    return OkResponse(ok=True)


@router.post("/notifications/read-all", response_model=OkResponse)
def mark_all(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(Notification).filter(Notification.user_id == user.id, Notification.is_read.is_(False)).update({"is_read": True})
    db.commit()
    return OkResponse(ok=True)


@router.post("/messages", response_model=MessageOut)
def send_message(body: MessageIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    text = body.body.strip()
    if not text:
        raise HTTPException(400, "Xabar bo‘sh bo‘lishi mumkin emas.")
    if body.request_id:
        req = db.get(TripRequest, body.request_id)
        if not req or req.status not in ("CONFIRMED", "DRIVER_ON_WAY", "PASSENGER_PICKED", "IN_PROGRESS", "COMPLETED"):
            raise HTTPException(403, "Chat faqat tasdiqlangan safarda.")
        driver = db.query(DriverProfile).filter(DriverProfile.user_id == user.id).first()
        ok = req.passenger_id == user.id or (driver and req.selected_driver_id == driver.id)
        if not ok:
            raise HTTPException(403, "Bu chatga kirish huquqingiz yo‘q.")
    msg = Message(
        sender_id=user.id,
        receiver_id=body.receiver_id,
        body=text,
        request_id=body.request_id,
        trip_id=body.trip_id,
    )
    db.add(msg)
    from app.services.notify import notify

    notify(db, user_id=body.receiver_id, title="Yangi xabar", body=text[:80], type="message", related_type="message", related_id=None)
    db.commit()
    db.refresh(msg)
    return MessageOut(
        id=msg.id,
        sender_id=msg.sender_id,
        receiver_id=msg.receiver_id,
        body=msg.body,
        is_read=msg.is_read,
        created_at=msg.created_at,
        request_id=msg.request_id,
        trip_id=msg.trip_id,
    )


@router.get("/messages", response_model=list[MessageOut])
def list_messages(request_id: int | None = None, peer_id: int | None = None, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    q = db.query(Message).filter((Message.sender_id == user.id) | (Message.receiver_id == user.id))
    if request_id:
        q = q.filter(Message.request_id == request_id)
    if peer_id:
        q = q.filter(((Message.sender_id == user.id) & (Message.receiver_id == peer_id)) | ((Message.sender_id == peer_id) & (Message.receiver_id == user.id)))
    rows = q.order_by(Message.created_at.asc()).limit(200).all()
    return [
        MessageOut(
            id=m.id,
            sender_id=m.sender_id,
            receiver_id=m.receiver_id,
            body=m.body,
            is_read=m.is_read,
            created_at=m.created_at,
            request_id=m.request_id,
            trip_id=m.trip_id,
        )
        for m in rows
    ]


@router.post("/ratings", response_model=OkResponse)
def rate(body: RatingIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if body.request_id:
        req = db.get(TripRequest, body.request_id)
        if not req or req.status != "COMPLETED":
            raise HTTPException(400, "Faqat yakunlangan safarni baholash mumkin.")
        exists = db.query(Rating).filter(Rating.request_id == body.request_id, Rating.from_user_id == user.id).first()
        if exists:
            raise HTTPException(400, "Siz allaqachon baho bergansiz.")
    rating = Rating(
        request_id=body.request_id,
        trip_id=body.trip_id,
        from_user_id=user.id,
        to_user_id=body.to_user_id,
        stars=body.stars,
        comment=body.comment,
    )
    db.add(rating)
    target = db.get(User, body.to_user_id)
    if target:
        total = target.rating_avg * target.rating_count + body.stars
        target.rating_count += 1
        target.rating_avg = round(total / target.rating_count, 2)
        d = db.query(DriverProfile).filter(DriverProfile.user_id == target.id).first()
        if d:
            d.rating_count = target.rating_count
            d.rating_avg = target.rating_avg
    db.commit()
    return OkResponse(ok=True, message="Baho saqlandi.")
