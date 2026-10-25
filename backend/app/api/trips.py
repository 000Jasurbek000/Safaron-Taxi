from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload

from app.config import get_settings
from app.database import get_db
from app.deps import get_approved_driver, get_current_user, get_driver_profile, get_optional_user
from app.models import DriverProfile, Trip, TripBooking, User, Vehicle
from app.schemas import (
    BookTripIn,
    CancelIn,
    DriverRespondIn,
    IncreaseSeatsIn,
    OkResponse,
    SeatIncreaseRespondIn,
    StatusUpdateIn,
    TripBookingOut,
    TripCreateIn,
    TripOut,
)
from app.services.fsm import TRIP_BOOKING_TRANSITIONS, TRIP_TRANSITIONS, assert_transition
from app.services.notify import notify
from app.services.serializers import booking_out, compute_avg_response_secs, parse_dt, trip_out

router = APIRouter(prefix="/trips", tags=["trips"])


def _expire_booking_if_needed(db: Session, booking: TripBooking) -> None:
    if booking.status in ("PENDING", "COUNTERED") and booking.expires_at and booking.expires_at < datetime.utcnow():
        assert_transition(TRIP_BOOKING_TRANSITIONS, booking.status, "EXPIRED")
        booking.status = "EXPIRED"


def _load_trip_bundle(db: Session, trip: Trip, avg_response_sec: int | None = None):
    driver = db.query(DriverProfile).options(joinedload(DriverProfile.user), joinedload(DriverProfile.vehicle)).filter(DriverProfile.id == trip.driver_id).first()
    return trip_out(trip, driver, driver.vehicle if driver else None, driver.user if driver else None, avg_response_sec)


@router.get("", response_model=list[TripOut])
def list_ready_trips(
    from_q: str | None = Query(None),
    to_q: str | None = Query(None),
    db: Session = Depends(get_db),
    _: User | None = Depends(get_optional_user),
):
    q = (
        db.query(Trip)
        .join(DriverProfile, DriverProfile.id == Trip.driver_id)
        .join(User, User.id == DriverProfile.user_id)
        .filter(
            Trip.status.in_(["OPEN", "FULL"]),
            Trip.seats_available > 0,
            DriverProfile.status == "APPROVED",
            DriverProfile.is_online.is_(True),
            User.deleted_at.is_(None),
        )
    )
    if from_q:
        q = q.filter(Trip.from_text.ilike(f"%{from_q.strip()}%"))
    if to_q:
        q = q.filter(Trip.to_text.ilike(f"%{to_q.strip()}%"))
    trips = q.order_by(Trip.scheduled_at.asc()).limit(100).all()
    avg_map = compute_avg_response_secs(db, [t.driver_id for t in trips])
    return [_load_trip_bundle(db, t, avg_map.get(t.driver_id)) for t in trips]


@router.post("", response_model=TripOut)
def create_trip(body: TripCreateIn, driver: DriverProfile = Depends(get_driver_profile), db: Session = Depends(get_db)):
    if not driver.is_online:
        # Allow create offline, but warn via message — still allow publish
        pass
    from_text = (body.from_text or "").strip() or "Ochiq"
    to_text = (body.to_text or "").strip() or "Yo‘nalish ochiq"
    if from_text.lower() == to_text.lower():
        to_text = f"{to_text} (qaytish)"
    scheduled = parse_dt(body.scheduled_at)
    if scheduled.tzinfo is not None:
        scheduled = scheduled.replace(tzinfo=None)
    if scheduled < datetime.utcnow() - timedelta(hours=1):
        raise HTTPException(400, "Vaqt o‘tib ketgan.")
    if scheduled < datetime.utcnow():
        scheduled = datetime.utcnow() + timedelta(minutes=1)
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


# NOTE: literal "/bookings/inbox" must stay registered before the dynamic
# "/bookings/{booking_id}" below it, otherwise "inbox" would be captured as
# booking_id and fail int conversion.
@router.get("/bookings/inbox", response_model=list[TripBookingOut])
def bookings_inbox(driver: DriverProfile = Depends(get_approved_driver), db: Session = Depends(get_db)):
    # Oflayn bo'lsa faqat YANGI (PENDING, hali javob berilmagan) band
    # qilishlar yashiriladi — COUNTERED/CONFIRMED/DRIVER_ON_WAY/
    # PASSENGER_PICKED kabi allaqachon qabul qilingan buyurtmalar
    # (haydovchining faol majburiyati) oflaynda ham ko'rinishda qolishi
    # kerak. Avval butun ro'yxat oflaynda bo'sh qaytarilardi — heartbeat
    # bir lahza kechiksa ham (fon rejimi, tarmoq uzilishi) bu tasdiqlangan
    # safarni mobil ilovada vaqtincha "yo'qolib" ko'rsatardi.
    statuses = ["COUNTERED", "CONFIRMED", "DRIVER_ON_WAY", "PASSENGER_PICKED"]
    if driver.is_online:
        statuses.append("PENDING")
    rows = (
        db.query(TripBooking)
        .join(Trip, Trip.id == TripBooking.trip_id)
        .filter(
            Trip.driver_id == driver.id,
            TripBooking.status.in_(statuses),
        )
        .order_by(TripBooking.created_at.desc())
        .limit(50)
        .all()
    )
    out = []
    for b in rows:
        _expire_booking_if_needed(db, b)
        out.append(booking_out(db, b))
    db.commit()
    return out


# NOTE: same reason as "/bookings/inbox" above — must stay before
# "/bookings/{booking_id}".
@router.get("/bookings/mine", response_model=list[TripBookingOut])
def my_bookings(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Yo'lovchi sifatida o'zim band qilgan safarlar tarixi (yakunlangan,
    bekor qilingan, rad etilgan, muddati o'tgan) — login/qayta tiklashda
    foydalaniladi."""
    rows = (
        db.query(TripBooking)
        .filter(
            TripBooking.passenger_id == user.id,
            TripBooking.status.in_(["COMPLETED", "CANCELLED", "REJECTED", "EXPIRED"]),
        )
        .order_by(TripBooking.created_at.desc())
        .limit(100)
        .all()
    )
    return [booking_out(db, b) for b in rows]


@router.get("/bookings/{booking_id}", response_model=TripBookingOut)
def get_booking(booking_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    booking = db.get(TripBooking, booking_id)
    if not booking:
        raise HTTPException(404, "Band qilish topilmadi.")
    trip = db.get(Trip, booking.trip_id)
    driver = db.query(DriverProfile).filter(DriverProfile.user_id == user.id).first()
    is_owner_driver = driver is not None and trip is not None and trip.driver_id == driver.id
    if booking.passenger_id != user.id and not is_owner_driver:
        raise HTTPException(403, "Bu amalni bajarish huquqingiz yo‘q.")
    _expire_booking_if_needed(db, booking)
    db.commit()
    return booking_out(db, booking)


@router.post("/{trip_id}/book", response_model=TripBookingOut)
def book_trip(trip_id: int, body: BookTripIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    trip = db.query(Trip).filter(Trip.id == trip_id).with_for_update(of=Trip).first() if False else db.query(Trip).filter(Trip.id == trip_id).first()
    # SQLite: emulate lock with re-check
    if not trip:
        raise HTTPException(404, "Safar topilmadi.")
    if trip.status != "OPEN":
        raise HTTPException(400, "Bu safarga joy band qilib bo‘lmaydi.")
    driver_check = db.get(DriverProfile, trip.driver_id)
    if not driver_check or not driver_check.is_online:
        raise HTTPException(400, "Haydovchi hozir oflayn — bu safarga joy band qilib bo‘lmaydi.")
    if trip.scheduled_at < datetime.utcnow():
        trip.status = "EXPIRED"
        db.commit()
        raise HTTPException(400, "Safar vaqti o‘tgan.")
    if body.seats > trip.seats_available:
        raise HTTPException(400, "Bo‘sh joy yetarli emas.")
    # Faqat FAOL (hali yakunlanmagan) band qilish bloklaydi — rad etilgan,
    # bekor qilingan, muddati o'tgan yoki allaqachon yakunlangan eski band
    # qilish shu passenger uchun ushbu safarni abadiy qayta band qilib
    # bo'lmaydigan qilib qo'ymasligi kerak (masalan avval rad etilgandan
    # keyin qayta urinish, yoki safar bo'yicha oldingi safar yakunlangandan
    # keyin yana bo'sh joy bo'lsa qayta band qilish).
    exists = (
        db.query(TripBooking)
        .filter(
            TripBooking.trip_id == trip.id,
            TripBooking.passenger_id == user.id,
            TripBooking.status.in_(["PENDING", "COUNTERED", "CONFIRMED", "DRIVER_ON_WAY", "PASSENGER_PICKED"]),
        )
        .first()
    )
    if exists:
        if exists.status in ("PENDING", "COUNTERED"):
            raise HTTPException(400, "Siz bu safarga allaqachon so‘rov yubordingiz — javobni kuting.")
        raise HTTPException(400, "Siz allaqachon shu safarga joy band qilgansiz.")

    # Yuqoridagi tekshiruv faqat AYNAN shu trip_id uchun — agar haydovchi
    # xuddi shu yo'nalishni BOSHQA (masalan qayta e'lon qilingan) safar
    # sifatida joylagan bo'lsa, passenger yana bir faol so'rov yuborib,
    # bitta haydovchiga bir vaqtning o'zida bir xil manzilga ikkita
    # parallel so'rov ochib qo'yishi mumkin edi. Shuni ham yopamiz.
    same_route_active = (
        db.query(TripBooking)
        .join(Trip, Trip.id == TripBooking.trip_id)
        .filter(
            Trip.driver_id == trip.driver_id,
            Trip.from_text == trip.from_text,
            Trip.to_text == trip.to_text,
            TripBooking.passenger_id == user.id,
            TripBooking.status.in_(["PENDING", "COUNTERED", "CONFIRMED", "DRIVER_ON_WAY", "PASSENGER_PICKED"]),
        )
        .first()
    )
    if same_route_active:
        raise HTTPException(400, "Siz shu haydovchiga shu yo‘nalishga allaqachon faol so‘rov yuborgansiz.")

    settings = get_settings()
    booking = TripBooking(
        trip_id=trip.id,
        passenger_id=user.id,
        seats=body.seats,
        status="PENDING",
        expires_at=datetime.utcnow() + timedelta(seconds=settings.instant_booking_timeout_sec),
        exact_pickup=(body.exact_pickup or "").strip() or None,
        note=(body.note or "").strip() or None,
    )
    db.add(booking)
    db.flush()
    driver = db.get(DriverProfile, trip.driver_id)
    if driver:
        note = (body.note or "").strip()
        booking_body = f"{user.full_name}: {trip.from_text} → {trip.to_text}"
        if note:
            booking_body += f" ({note})"
        notify(
            db,
            user_id=driver.user_id,
            title="Yangi yo‘lovchi so‘rovi",
            body=booking_body,
            type="new_booking_request",
            related_type="trip_booking",
            related_id=booking.id,
        )
    notify(
        db,
        user_id=user.id,
        title="So‘rovingiz yuborildi!",
        body="Haydovchi javobini kutamiz...",
        type="booking_requested",
        related_type="trip_booking",
        related_id=booking.id,
    )
    db.commit()
    db.refresh(booking)
    return booking_out(db, booking)


@router.post("/{trip_id}/cancel", response_model=OkResponse)
def cancel_trip(trip_id: int, body: CancelIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    trip = db.get(Trip, trip_id)
    if not trip:
        raise HTTPException(404, "Safar topilmadi.")
    driver = db.query(DriverProfile).filter(DriverProfile.user_id == user.id).first()
    if driver and trip.driver_id == driver.id:
        assert_transition(TRIP_TRANSITIONS, trip.status, "CANCELLED")
        trip.status = "CANCELLED"
        for b in db.query(TripBooking).filter(
            TripBooking.trip_id == trip.id,
            TripBooking.status.in_(["PENDING", "COUNTERED", "CONFIRMED", "DRIVER_ON_WAY", "PASSENGER_PICKED"]),
        ):
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


@router.post("/bookings/{booking_id}/respond", response_model=TripBookingOut)
def respond_booking(
    booking_id: int,
    body: DriverRespondIn,
    driver: DriverProfile = Depends(get_approved_driver),
    db: Session = Depends(get_db),
):
    if not driver.is_online:
        raise HTTPException(400, "Avval onlayn holatga o‘ting.")
    booking = db.get(TripBooking, booking_id)
    if not booking:
        raise HTTPException(404, "So‘rov topilmadi.")
    trip = db.get(Trip, booking.trip_id)
    if not trip or trip.driver_id != driver.id:
        raise HTTPException(403, "Bu amalni bajarish huquqingiz yo‘q.")
    _expire_booking_if_needed(db, booking)
    if booking.status != "PENDING":
        raise HTTPException(400, "Bu so‘rovga javob berib bo‘lmaydi.")

    action = body.action.lower()
    if action == "reject":
        assert_transition(TRIP_BOOKING_TRANSITIONS, booking.status, "REJECTED")
        booking.status = "REJECTED"
        booking.cancelled_by = "driver"
        booking.cancel_reason = body.message
        booking.cancelled_at = datetime.utcnow()
        notify(
            db,
            user_id=booking.passenger_id,
            title="So‘rov rad etildi",
            body="Haydovchi so‘rovni rad etdi. Boshqa taksini tanlashingiz mumkin.",
            type="booking_rejected",
            related_type="trip_booking",
            related_id=booking.id,
        )
        db.commit()
        return booking_out(db, booking)

    if action != "accept":
        raise HTTPException(400, "action: accept yoki reject.")

    agreed = body.offered_price if body.offered_price is not None else trip.price
    is_counter = agreed != trip.price

    if is_counter:
        assert_transition(TRIP_BOOKING_TRANSITIONS, booking.status, "COUNTERED")
        booking.status = "COUNTERED"
        booking.agreed_price = agreed
        booking.eta_minutes = body.eta_minutes
        notify(
            db,
            user_id=booking.passenger_id,
            title="Qarshi narx taklifi",
            body=f"Haydovchi {agreed} so‘m taklif qildi.",
            type="booking_countered",
            related_type="trip_booking",
            related_id=booking.id,
        )
        db.commit()
        return booking_out(db, booking)

    # Narx mos keldi — joy sonini qayta tekshirib (race-safe re-read) kamaytiramiz.
    trip = db.query(Trip).filter(Trip.id == trip.id).first()
    if trip.seats_available < booking.seats:
        raise HTTPException(400, "Bo‘sh joy yetarli emas — avval boshqa so‘rovni rad eting.")
    trip.seats_available -= booking.seats
    if trip.seats_available == 0:
        assert_transition(TRIP_TRANSITIONS, trip.status, "FULL")
        trip.status = "FULL"
    booking.agreed_price = agreed
    if body.eta_minutes is not None:
        booking.eta_minutes = body.eta_minutes
        booking.eta_arrive_at = datetime.utcnow() + timedelta(minutes=body.eta_minutes)
        assert_transition(TRIP_BOOKING_TRANSITIONS, booking.status, "DRIVER_ON_WAY")
        booking.status = "DRIVER_ON_WAY"
    else:
        assert_transition(TRIP_BOOKING_TRANSITIONS, booking.status, "CONFIRMED")
        booking.status = "CONFIRMED"
    notify(
        db,
        user_id=booking.passenger_id,
        title="Haydovchi qabul qildi!",
        body=f"{trip.from_text} → {trip.to_text}",
        type="booking_accepted",
        related_type="trip_booking",
        related_id=booking.id,
    )
    db.commit()
    return booking_out(db, booking)


@router.post("/bookings/{booking_id}/confirm-counter", response_model=TripBookingOut)
def confirm_counter(booking_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    booking = db.get(TripBooking, booking_id)
    if not booking or booking.passenger_id != user.id:
        raise HTTPException(403, "Bu amalni bajarish huquqingiz yo‘q.")
    _expire_booking_if_needed(db, booking)
    if booking.status != "COUNTERED":
        raise HTTPException(400, "Tasdiqlash mumkin emas.")
    trip = db.query(Trip).filter(Trip.id == booking.trip_id).first()
    if not trip:
        raise HTTPException(404, "Safar topilmadi.")
    if trip.seats_available < booking.seats:
        raise HTTPException(400, "Bo‘sh joy yetarli emas.")
    trip.seats_available -= booking.seats
    if trip.seats_available == 0:
        assert_transition(TRIP_TRANSITIONS, trip.status, "FULL")
        trip.status = "FULL"
    if booking.eta_minutes is not None:
        booking.eta_arrive_at = datetime.utcnow() + timedelta(minutes=booking.eta_minutes)
        assert_transition(TRIP_BOOKING_TRANSITIONS, booking.status, "DRIVER_ON_WAY")
        booking.status = "DRIVER_ON_WAY"
    else:
        assert_transition(TRIP_BOOKING_TRANSITIONS, booking.status, "CONFIRMED")
        booking.status = "CONFIRMED"
    driver = db.get(DriverProfile, trip.driver_id)
    if driver:
        notify(
            db,
            user_id=driver.user_id,
            title="Yo‘lovchi narxni tasdiqladi",
            body=f"{trip.from_text} → {trip.to_text}",
            type="booking_confirmed",
            related_type="trip_booking",
            related_id=booking.id,
        )
    db.commit()
    return booking_out(db, booking)


@router.post("/bookings/{booking_id}/increase-seats", response_model=TripBookingOut)
def increase_seats(booking_id: int, body: IncreaseSeatsIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Yo'lovchi allaqachon tasdiqlangan band qilishdagi o'rindiq sonini
    OSHIRISHNI SO'RAYDI (hech qachon kamaytira olmaydi). Bu darhol amalga
    oshmaydi — `pending_seats`ga yoziladi va haydovchiga bildirishnoma
    boradi; haydovchi buni aniq TASDIQLASHI yoki RAD ETISHI kerak
    (`respond-seat-increase`). Faqat tasdiqlangandan keyin `seats` va demak
    jami narx (1 o'rindiq narxi * o'rindiq soni) o'zgaradi."""
    booking = db.get(TripBooking, booking_id)
    if not booking or booking.passenger_id != user.id:
        raise HTTPException(403, "Bu amalni bajarish huquqingiz yo‘q.")
    if booking.status not in ("CONFIRMED", "DRIVER_ON_WAY"):
        raise HTTPException(400, "Faqat tasdiqlangan safarda o'rindiq sonini oshirish mumkin.")
    if body.new_seats <= booking.seats:
        raise HTTPException(400, "Yangi son joriy o'rindiq sonidan ko'p bo'lishi shart — kamaytirib bo'lmaydi.")
    trip = db.query(Trip).filter(Trip.id == booking.trip_id).first()
    if not trip:
        raise HTTPException(404, "Safar topilmadi.")
    extra = body.new_seats - booking.seats
    if trip.seats_available < extra:
        raise HTTPException(400, "Haydovchida yetarli bo'sh joy yo'q.")
    booking.pending_seats = body.new_seats
    driver = db.get(DriverProfile, trip.driver_id)
    if driver:
        notify(
            db,
            user_id=driver.user_id,
            title="Yo‘lovchilar sonini oshirish so‘rovi",
            body=f"{trip.from_text} → {trip.to_text}: {body.new_seats} kishiga oshirishni so‘rayapti.",
            type="seats_increase_requested",
            related_type="trip_booking",
            related_id=booking.id,
        )
    db.commit()
    db.refresh(booking)
    return booking_out(db, booking)


@router.post("/bookings/{booking_id}/respond-seat-increase", response_model=TripBookingOut)
def respond_seat_increase(
    booking_id: int,
    body: SeatIncreaseRespondIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Haydovchi yo'lovchining o'rindiq sonini oshirish so'rovini
    TASDIQLAYDI (haqiqatan amalga oshiradi) yoki RAD ETADI (joriy son
    o'zgarishsiz qoladi)."""
    booking = db.get(TripBooking, booking_id)
    if not booking:
        raise HTTPException(404, "Band qilish topilmadi.")
    trip = db.get(Trip, booking.trip_id)
    driver = db.query(DriverProfile).filter(DriverProfile.user_id == user.id).first()
    is_owner_driver = driver is not None and trip is not None and trip.driver_id == driver.id
    if not is_owner_driver:
        raise HTTPException(403, "Bu amalni bajarish huquqingiz yo‘q.")
    if booking.pending_seats is None:
        raise HTTPException(400, "Kutilayotgan o'rindiq oshirish so'rovi yo'q.")
    pending = booking.pending_seats
    if body.accept:
        extra = pending - booking.seats
        if trip.seats_available < extra:
            raise HTTPException(400, "Haydovchida yetarli bo'sh joy yo'q.")
        trip.seats_available -= extra
        booking.seats = pending
        booking.pending_seats = None
        if trip.seats_available == 0:
            assert_transition(TRIP_TRANSITIONS, trip.status, "FULL")
            trip.status = "FULL"
        notify(
            db,
            user_id=booking.passenger_id,
            title="O‘rindiq sonini oshirish tasdiqlandi",
            body=f"{trip.from_text} → {trip.to_text}: endi {pending} kishi.",
            type="seats_increase_accepted",
            related_type="trip_booking",
            related_id=booking.id,
        )
    else:
        booking.pending_seats = None
        notify(
            db,
            user_id=booking.passenger_id,
            title="O‘rindiq sonini oshirish rad etildi",
            body=f"{trip.from_text} → {trip.to_text}: haydovchi {booking.seats} kishilik joyni saqlab qoldi.",
            type="seats_increase_declined",
            related_type="trip_booking",
            related_id=booking.id,
        )
    db.commit()
    db.refresh(booking)
    return booking_out(db, booking)


@router.post("/bookings/{booking_id}/status", response_model=TripBookingOut)
def advance_booking_status(
    booking_id: int,
    body: StatusUpdateIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    booking = db.get(TripBooking, booking_id)
    if not booking:
        raise HTTPException(404, "Band qilish topilmadi.")
    trip = db.get(Trip, booking.trip_id)
    driver = db.query(DriverProfile).filter(DriverProfile.user_id == user.id).first()
    is_owner_driver = driver is not None and trip is not None and trip.driver_id == driver.id
    is_passenger = booking.passenger_id == user.id
    new = body.status.upper()

    if new in ("CANCELLED", "REJECTED", "EXPIRED"):
        # Bu endpoint faqat ijobiy progress (on-way/picked-up/completed) uchun —
        # bekor qilish uchun /cancel ishlatilsin, u joy sonini to'g'ri qaytaradi
        # va cancelled_by/cancel_reason/cancelled_at'ni to'ldiradi.
        raise HTTPException(400, "Bekor qilish uchun /cancel endpointidan foydalaning.")

    if new == "COMPLETED":
        if not is_owner_driver and not is_passenger:
            raise HTTPException(403, "Bu amalni bajarish huquqingiz yo‘q.")
    elif not is_owner_driver:
        raise HTTPException(403, "Faqat haydovchi holatni o‘zgartira oladi.")

    assert_transition(TRIP_BOOKING_TRANSITIONS, booking.status, new)
    booking.status = new
    if new == "PASSENGER_PICKED":
        booking.picked_up_at = datetime.utcnow()
    elif new == "COMPLETED":
        booking.completed_at = datetime.utcnow()

    trip_driver = db.get(DriverProfile, trip.driver_id) if trip else None
    titles = {
        "DRIVER_ON_WAY": ("Haydovchi yo‘lga chiqdi", "Yo‘lovchini olishga yo‘l oldim"),
        "PASSENGER_PICKED": ("Yo‘lovchi olindi", "Haydovchi sizni oldi"),
        "COMPLETED": ("Safar yakunlandi", "Safaringiz yakunlandi. Baholash mumkin."),
    }
    if new in titles:
        if new == "COMPLETED" and is_passenger and not is_owner_driver:
            if trip_driver:
                notify(
                    db,
                    user_id=trip_driver.user_id,
                    title=titles[new][0],
                    body="Yo‘lovchi safarni yakunladi.",
                    type=new.lower(),
                    related_type="trip_booking",
                    related_id=booking.id,
                )
        else:
            notify(
                db,
                user_id=booking.passenger_id,
                title=titles[new][0],
                body=titles[new][1],
                type=new.lower(),
                related_type="trip_booking",
                related_id=booking.id,
            )

    if new == "COMPLETED" and trip_driver:
        # agreed_price/trip.price har doim 1 o'rindiq narxi — shu band
        # qilish necha o'rindiqni egallagani (booking.seats) bilan
        # ko'paytirmasak, 1 dan ortiq o'rindiq band qilingan safarlar uchun
        # haydovchi daromadi kam hisoblanib qolardi.
        unit_price = booking.agreed_price or (trip.price if trip else 0)
        price = unit_price * booking.seats
        trip_driver.trips_count += 1
        trip_driver.total_earnings += price
    db.commit()
    return booking_out(db, booking)


@router.post("/bookings/{booking_id}/cancel", response_model=OkResponse)
def cancel_booking(booking_id: int, body: CancelIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    booking = db.get(TripBooking, booking_id)
    if not booking:
        raise HTTPException(404, "Band qilish topilmadi.")
    if booking.status in ("COMPLETED", "CANCELLED", "REJECTED", "EXPIRED"):
        raise HTTPException(400, "Bu band qilishni bekor qilib bo‘lmaydi.")
    trip = db.get(Trip, booking.trip_id)
    driver = db.query(DriverProfile).filter(DriverProfile.user_id == user.id).first()
    is_owner_driver = driver is not None and trip is not None and trip.driver_id == driver.id
    is_passenger = booking.passenger_id == user.id
    if not is_passenger and not is_owner_driver:
        raise HTTPException(403, "Bu amalni bajarish huquqingiz yo‘q.")
    if is_owner_driver and not is_passenger and booking.status == "PENDING":
        raise HTTPException(400, "Hali javob berilmagan so‘rovni /respond orqali rad eting.")

    had_seats = booking.status in ("CONFIRMED", "DRIVER_ON_WAY", "PASSENGER_PICKED")
    assert_transition(TRIP_BOOKING_TRANSITIONS, booking.status, "CANCELLED")
    booking.status = "CANCELLED"
    booking.cancelled_by = "passenger" if is_passenger else "driver"
    booking.cancel_reason = body.reason
    booking.cancelled_at = datetime.utcnow()
    if had_seats and trip:
        trip.seats_available = min(trip.seats_total, trip.seats_available + booking.seats)
        if trip.status == "FULL":
            trip.status = "OPEN"
    if trip:
        if is_passenger:
            driver_profile = db.get(DriverProfile, trip.driver_id)
            if driver_profile:
                notify(
                    db,
                    user_id=driver_profile.user_id,
                    title="Safar bekor qilindi",
                    body=body.reason,
                    type="booking_cancelled",
                    related_type="trip_booking",
                    related_id=booking.id,
                )
        else:
            notify(
                db,
                user_id=booking.passenger_id,
                title="Safar bekor qilindi",
                body=body.reason,
                type="booking_cancelled",
                related_type="trip_booking",
                related_id=booking.id,
            )
    db.commit()
    return OkResponse(ok=True, message="Bekor qilindi.")
