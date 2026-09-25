from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.deps import get_approved_driver, get_current_user, get_optional_user
from app.models import DriverProfile, Trip, TripBooking, User, Vehicle
from app.schemas import BookTripIn, CancelIn, OkResponse, TripCreateIn, TripOut
from app.services.fsm import TRIP_TRANSITIONS, assert_transition
from app.services.notify import notify
from app.services.serializers import parse_dt, trip_out

router = APIRouter(prefix="/trips", tags=["trips"])


def _load_trip_bundle(db: Session, trip: Trip):
    driver = db.query(DriverProfile).options(joinedload(DriverProfile.user), joinedload(DriverProfile.vehicle)).filter(DriverProfile.id == trip.driver_id).first()
    return trip_out(trip, driver, driver.vehicle if driver else None, driver.user if driver else None)


@router.get("", response_model=list[TripOut])
def list_ready_trips(
    from_q: str | None = Query(None),
    to_q: str | None = Query(None),
    db: Session = Depends(get_db),
    _: User | None = Depends(get_optional_user),
):
    q = db.query(Trip).filter(Trip.status == "OPEN", Trip.seats_available > 0, Trip.scheduled_at >= datetime.utcnow())
    if from_q:
        q = q.filter(Trip.from_text.ilike(f"%{from_q.strip()}%"))
    if to_q:
        q = q.filter(Trip.to_text.ilike(f"%{to_q.strip()}%"))
    trips = q.order_by(Trip.scheduled_at.asc()).limit(100).all()
    return [_load_trip_bundle(db, t) for t in trips]


@router.post("", response_model=TripOut)
def create_trip(body: TripCreateIn, driver: DriverProfile = Depends(get_approved_driver), db: Session = Depends(get_db)):
    if not driver.is_online:
        # Allow create offline, but warn via message — still allow publish
        pass
    from_text = body.from_text.strip()
    to_text = body.to_text.strip()
    if not from_text or not to_text:
        raise HTTPException(400, "Qayerdan va qayerga majburiy.")
    if from_text.lower() == to_text.lower():
        raise HTTPException(400, "Qayerdan va qayerga bir xil bo‘lishi mumkin emas.")
    scheduled = parse_dt(body.scheduled_at)
    if scheduled < datetime.utcnow():
        raise HTTPException(400, "Vaqt o‘tib ketgan.")
    trip = Trip(
        driver_id=driver.id,
        from_location_id=body.from_location_id,
        to_location_id=body.to_location_id,
        from_text=from_text,
        to_text=to_text,
        from_note=body.from_note,
        to_note=body.to_note,
        scheduled_at=scheduled,
        seats_total=body.seats_total,
        seats_available=body.seats_total,
        price=body.price,
        note=body.note,
        status="OPEN",
    )
    db.add(trip)
    db.commit()
    db.refresh(trip)
    return _load_trip_bundle(db, trip)


@router.get("/mine", response_model=list[TripOut])
def my_trips(driver: DriverProfile = Depends(get_approved_driver), db: Session = Depends(get_db)):
    trips = db.query(Trip).filter(Trip.driver_id == driver.id).order_by(Trip.scheduled_at.desc()).limit(100).all()
    return [_load_trip_bundle(db, t) for t in trips]


@router.post("/{trip_id}/book", response_model=OkResponse)
def book_trip(trip_id: int, body: BookTripIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    trip = db.query(Trip).filter(Trip.id == trip_id).with_for_update(of=Trip).first() if False else db.query(Trip).filter(Trip.id == trip_id).first()
    # SQLite: emulate lock with re-check
    if not trip:
        raise HTTPException(404, "Safar topilmadi.")
    if trip.status != "OPEN":
        raise HTTPException(400, "Bu safarga joy band qilib bo‘lmaydi.")
    if trip.scheduled_at < datetime.utcnow():
        trip.status = "EXPIRED"
        db.commit()
        raise HTTPException(400, "Safar vaqti o‘tgan.")
    if body.seats > trip.seats_available:
        raise HTTPException(400, "Bo‘sh joy yetarli emas.")
    exists = db.query(TripBooking).filter(TripBooking.trip_id == trip.id, TripBooking.passenger_id == user.id, TripBooking.status == "CONFIRMED").first()
    if exists:
        raise HTTPException(400, "Siz allaqachon shu safarga joy band qilgansiz.")

    # Race-safe: re-read seats
    trip = db.query(Trip).filter(Trip.id == trip_id).first()
    if trip.seats_available < body.seats:
        raise HTTPException(400, "Bo‘sh joy yetarli emas.")
    trip.seats_available -= body.seats
    if trip.seats_available == 0:
        assert_transition(TRIP_TRANSITIONS, trip.status, "FULL")
        trip.status = "FULL"
    booking = TripBooking(trip_id=trip.id, passenger_id=user.id, seats=body.seats, status="CONFIRMED")
    db.add(booking)
    driver = db.get(DriverProfile, trip.driver_id)
    if driver:
        notify(
            db,
            user_id=driver.user_id,
            title="Yangi joy band qilindi",
            body=f"{user.full_name}: {trip.from_text} → {trip.to_text}",
            type="booking",
            related_type="trip",
            related_id=trip.id,
        )
    notify(
        db,
        user_id=user.id,
        title="Joy band qilindi",
        body=f"{trip.from_text} → {trip.to_text}",
        type="booking",
        related_type="trip",
        related_id=trip.id,
    )
    db.commit()
    return OkResponse(ok=True, message="Joy band qilindi.")


@router.post("/{trip_id}/cancel", response_model=OkResponse)
def cancel_trip(trip_id: int, body: CancelIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    trip = db.get(Trip, trip_id)
    if not trip:
        raise HTTPException(404, "Safar topilmadi.")
    driver = db.query(DriverProfile).filter(DriverProfile.user_id == user.id).first()
    if driver and trip.driver_id == driver.id:
        assert_transition(TRIP_TRANSITIONS, trip.status, "CANCELLED")
        trip.status = "CANCELLED"
        for b in db.query(TripBooking).filter(TripBooking.trip_id == trip.id, TripBooking.status == "CONFIRMED"):
            b.status = "CANCELLED"
            b.cancelled_by = "driver"
            b.cancel_reason = body.reason
            b.cancelled_at = datetime.utcnow()
            notify(db, user_id=b.passenger_id, title="Safar bekor qilindi", body=body.reason, type="trip_cancelled", related_type="trip", related_id=trip.id)
        db.commit()
        return OkResponse(ok=True, message="Safar bekor qilindi.")

    booking = db.query(TripBooking).filter(TripBooking.trip_id == trip.id, TripBooking.passenger_id == user.id, TripBooking.status == "CONFIRMED").first()
    if not booking:
        raise HTTPException(403, "Bu amalni bajarish huquqingiz yo‘q.")
    booking.status = "CANCELLED"
    booking.cancelled_by = "passenger"
    booking.cancel_reason = body.reason
    booking.cancelled_at = datetime.utcnow()
    trip.seats_available = min(trip.seats_total, trip.seats_available + booking.seats)
    if trip.status == "FULL":
        trip.status = "OPEN"
    driver = db.get(DriverProfile, trip.driver_id)
    if driver:
        notify(
            db,
            user_id=driver.user_id,
            title="Safar bekor qilindi",
            body=body.reason,
            type="trip_cancelled",
            related_type="trip",
            related_id=trip.id,
        )
    db.commit()
    return OkResponse(ok=True, message="Band bekor qilindi.")
