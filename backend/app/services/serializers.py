from datetime import datetime

from sqlalchemy.orm import Session, joinedload

from app.models import DriverProfile, DriverResponse, Trip, TripBooking, TripRequest, User, Vehicle
from app.schemas import DriverResponseOut, RequestOut, TripBookingOut, TripOut, UserOut
from app.services.phone import format_phone_display


def passenger_phone_for_driver(passenger: User | None) -> str:
    """Yo'lovchi `hide_phone`ni yoqqan bo'lsa, haydovchiga ko'rinadigan
    raqamni "+998***" shakliga qisqartiradi — asl raqam hech qanday
    band qilish/so'rov javobida to'liq chiqmaydi."""
    if not passenger:
        return ""
    if passenger.hide_phone:
        return "+998***"
    return passenger.phone or ""


def compute_avg_response_secs(db: Session, driver_ids: list[int]) -> dict[int, int]:
    """Har bir haydovchi o‘tgan so‘rovlarga qancha tez javob berganini (soniyada)
    hisoblaydi — qidiruv natijalarida tezroq javob beradiganlarni yuqoriga chiqarish uchun."""
    if not driver_ids:
        return {}
    rows = (
        db.query(DriverResponse.driver_id, DriverResponse.updated_at, TripRequest.created_at)
        .join(TripRequest, TripRequest.id == DriverResponse.request_id)
        .filter(DriverResponse.driver_id.in_(driver_ids), DriverResponse.status != "PENDING")
        .all()
    )
    sums: dict[int, float] = {}
    counts: dict[int, int] = {}
    for driver_id, updated_at, created_at in rows:
        if updated_at is None or created_at is None:
            continue
        delta = (updated_at - created_at).total_seconds()
        if delta < 0:
            continue
        sums[driver_id] = sums.get(driver_id, 0.0) + delta
        counts[driver_id] = counts.get(driver_id, 0) + 1
    return {d: int(sums[d] / counts[d]) for d in sums if counts.get(d)}


def user_out(user: User) -> UserOut:
    driver = user.driver_profile
    vehicle = driver.vehicle if driver else None
    return UserOut(
        id=user.id,
        phone=user.phone,
        phone_display=format_phone_display(user.phone),
        first_name=user.first_name,
        last_name=user.last_name,
        full_name=user.full_name,
        avatar_path=user.avatar_path,
        active_role=user.active_role,
        language=user.language,
        is_active=user.is_active,
        driver_status=driver.status if driver else None,
        driver_id=driver.id if driver else None,
        is_online=driver.is_online if driver else None,
        rating_avg=user.rating_avg,
        experience_years=driver.experience_years if driver else None,
        car_model=vehicle.model_name if vehicle else None,
        plate=vehicle.plate if vehicle else None,
        car_seats=vehicle.seats if vehicle else None,
        car_photo=vehicle.photo_path if vehicle else None,
        car_color=vehicle.color if vehicle else None,
        hide_phone=user.hide_phone,
    )


def trip_out(
    trip: Trip,
    driver: DriverProfile | None = None,
    vehicle: Vehicle | None = None,
    user: User | None = None,
    avg_response_sec: int | None = None,
    *,
    override_from: str | None = None,
    override_to: str | None = None,
    override_price: int | None = None,
) -> TripOut:
    d = driver
    v = vehicle
    u = user
    return TripOut(
        id=trip.id,
        driver_id=trip.driver_id,
        driver_user_id=u.id if u else None,
        driver_name=u.full_name if u else "",
        driver_rating=(d.rating_avg if d else 5.0) or 5.0,
        driver_reviews=d.rating_count if d else 0,
        driver_phone=u.phone if u else "",
        driver_photo=(d.photo_path if d else None) or (u.avatar_path if u else None),
        driver_avg_response_sec=avg_response_sec,
        driver_is_online=bool(d.is_online) if d else False,
        car_model=v.model_name if v else "",
        plate=v.plate if v else "",
        car_photo=v.photo_path if v else None,
        from_text=override_from or trip.from_text,
        to_text=override_to or trip.to_text,
        from_note=trip.from_note,
        scheduled_at=trip.scheduled_at,
        seats_total=trip.seats_total,
        seats_available=trip.seats_available,
        price=override_price if override_price is not None else trip.price,
        note=trip.note,
        status=trip.status,
        created_at=trip.created_at,
    )


def trip_out_for(
    db: Session,
    trip: Trip,
    *,
    override_from: str | None = None,
    override_to: str | None = None,
    override_price: int | None = None,
) -> TripOut:
    driver = (
        db.query(DriverProfile)
        .options(joinedload(DriverProfile.user), joinedload(DriverProfile.vehicle))
        .filter(DriverProfile.id == trip.driver_id)
        .first()
    )
    return trip_out(
        trip,
        driver,
        driver.vehicle if driver else None,
        driver.user if driver else None,
        override_from=override_from,
        override_to=override_to,
        override_price=override_price,
    )


def booking_out(db: Session, booking: TripBooking) -> TripBookingOut:
    passenger = db.get(User, booking.passenger_id)
    return TripBookingOut(
        id=booking.id,
        trip_id=booking.trip_id,
        passenger_id=booking.passenger_id,
        seats=booking.seats,
        status=booking.status,
        agreed_price=booking.agreed_price,
        eta_minutes=booking.eta_minutes,
        eta_arrive_at=booking.eta_arrive_at,
        picked_up_at=booking.picked_up_at,
        exact_pickup=booking.exact_pickup,
        note=booking.note,
        pending_seats=booking.pending_seats,
        cancelled_by=booking.cancelled_by,
        cancel_reason=booking.cancel_reason,
        cancelled_at=booking.cancelled_at,
        completed_at=booking.completed_at,
        created_at=booking.created_at,
        expires_at=booking.expires_at,
        trip=trip_out_for(
            db,
            booking.trip,
            override_from=booking.open_from_text,
            override_to=booking.open_to_text,
            override_price=booking.open_offered_price,
        ),
        passenger_name=passenger.full_name if passenger else "",
        passenger_phone=passenger_phone_for_driver(passenger),
        passenger_rating=passenger.rating_avg if passenger else 5.0,
        passenger_photo=passenger.avatar_path if passenger else None,
    )


def response_out(resp: DriverResponse, driver: DriverProfile, vehicle: Vehicle | None, user: User, passenger_price: int) -> DriverResponseOut:
    final = resp.offered_price if resp.offered_price is not None else passenger_price
    return DriverResponseOut(
        id=resp.id,
        driver_id=driver.id,
        driver_name=user.full_name,
        driver_rating=driver.rating_avg,
        experience_years=driver.experience_years,
        car_model=vehicle.model_name if vehicle else "",
        plate=vehicle.plate if vehicle else "",
        photo=driver.photo_path or user.avatar_path,
        car_photo=vehicle.photo_path if vehicle else None,
        phone=user.phone,
        status=resp.status,
        offered_price=resp.offered_price,
        passenger_offered_price=passenger_price,
        final_price=final,
    )


def request_out(
    req: TripRequest,
    responses: list[DriverResponseOut] | None = None,
    passenger: User | None = None,
    viewed_by_driver: bool = False,
) -> RequestOut:
    return RequestOut(
        id=req.id,
        passenger_id=req.passenger_id,
        from_text=req.from_text,
        to_text=req.to_text,
        exact_place=req.exact_place,
        scheduled_at=req.scheduled_at,
        passengers_count=req.passengers_count,
        has_luggage=req.has_luggage,
        note=req.note,
        offered_price=req.offered_price,
        agreed_price=req.agreed_price,
        status=req.status,
        selected_driver_id=req.selected_driver_id,
        responses=responses or [],
        created_at=req.created_at,
        expires_at=req.expires_at,
        passenger_name=passenger.full_name if passenger else "",
        passenger_phone=passenger_phone_for_driver(passenger) if viewed_by_driver else (passenger.phone if passenger else ""),
        passenger_photo=passenger.avatar_path if passenger else None,
    )


def parse_dt(value: datetime) -> datetime:
    return value.replace(tzinfo=None) if value.tzinfo else value
