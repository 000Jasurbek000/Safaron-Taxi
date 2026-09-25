from datetime import datetime

from app.models import DriverProfile, DriverResponse, Trip, TripRequest, User, Vehicle
from app.schemas import DriverResponseOut, RequestOut, TripOut, UserOut
from app.services.phone import format_phone_display


def user_out(user: User) -> UserOut:
    driver = user.driver_profile
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
    )


def trip_out(trip: Trip, driver: DriverProfile | None = None, vehicle: Vehicle | None = None, user: User | None = None) -> TripOut:
    d = driver
    v = vehicle
    u = user
    return TripOut(
        id=trip.id,
        driver_id=trip.driver_id,
        driver_name=u.full_name if u else "",
        driver_rating=d.rating_avg if d else 5.0,
        driver_phone=u.phone if u else "",
        car_model=v.model_name if v else "",
        plate=v.plate if v else "",
        car_photo=v.photo_path if v else None,
        from_text=trip.from_text,
        to_text=trip.to_text,
        from_note=trip.from_note,
        scheduled_at=trip.scheduled_at,
        seats_total=trip.seats_total,
        seats_available=trip.seats_available,
        price=trip.price,
        note=trip.note,
        status=trip.status,
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


def request_out(req: TripRequest, responses: list[DriverResponseOut] | None = None) -> RequestOut:
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
    )


def parse_dt(value: datetime) -> datetime:
    return value.replace(tzinfo=None) if value.tzinfo else value
