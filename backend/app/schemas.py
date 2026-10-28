from datetime import datetime, timezone
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class UTCModel(BaseModel):
    """Chiquvchi `datetime` maydonlarini aniq UTC deb belgilaydi.

    Backend hamma joyda `datetime.utcnow()` (naiv, lekin UTC qiymatni
    ifodalovchi) ishlatadi. Pydantic'ning standart JSON chiqishi esa bunday
    naiv datetime'larni hech qanday vaqt mintaqasi belgisisiz ("Z" yoki
    "+00:00" yo'q) qatorga aylantiradi. Flutter tomonida `DateTime.parse()`
    belgisiz ISO qatorni MAHALLIY vaqt deb o'qiydi — Toshkentda (UTC+5) bu
    har qanday server vaqtini haqiqiy mahalliy soatdan 5 soat "orqada"
    ko'rsatib yuboradi, va shu sababli masalan 1 soatlik "haydovchi javob
    bermadi" muddati bron yaratilgan zahotiyoq "allaqachon o'tgan" bo'lib
    chiqadi. Shu klass har bir chiquvchi datetime'ni aniq UTC deb
    belgilab beradi.
    """

    model_config = ConfigDict(
        json_encoders={
            datetime: lambda v: v.replace(tzinfo=timezone.utc).isoformat() if v.tzinfo is None else v.isoformat()
        }
    )


class ApiError(UTCModel):
    detail: str
    code: Optional[str] = None


class OkResponse(UTCModel):
    ok: bool = True
    message: Optional[str] = None


class TokenResponse(UTCModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserOut"


class SendOtpIn(UTCModel):
    phone: str


class SendOtpOut(UTCModel):
    ok: bool = True
    message: Optional[str] = None
    user_exists: bool = False


class VerifyOtpIn(UTCModel):
    phone: str
    code: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    referral_code: Optional[str] = None


class SignInIn(UTCModel):
    phone: str
    password: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    referral_code: Optional[str] = None


class PhoneLookupOut(UTCModel):
    # Qasddan faqat `exists` — ro'yxatdagi raqamning egasi kim ekanini
    # (ism, rol) avtorizatsiyasiz oshkor qilish, parolni bilmagan odamga
    # ham o'zganing profilini "ko'rib chiqish" imkonini berardi.
    exists: bool


class UserOut(UTCModel):
    id: int
    phone: str
    phone_display: str
    first_name: str
    last_name: str
    full_name: str
    avatar_path: Optional[str] = None
    active_role: str
    language: str
    is_active: bool
    driver_status: Optional[str] = None
    driver_id: Optional[int] = None
    is_online: Optional[bool] = None
    rating_avg: float = 5.0
    experience_years: Optional[int] = None
    car_model: Optional[str] = None
    plate: Optional[str] = None
    car_seats: Optional[int] = None
    car_photo: Optional[str] = None
    car_color: Optional[str] = None
    hide_phone: bool = False

    class Config:
        from_attributes = True


class RoleIn(UTCModel):
    role: str  # passenger|driver


class LanguageIn(UTCModel):
    language: str


class ProfileUpdateIn(UTCModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    experience_years: Optional[int] = Field(default=None, ge=0, le=60)
    hide_phone: Optional[bool] = None


class ChangePhoneIn(UTCModel):
    phone: str
    code: str


class LocationOut(UTCModel):
    id: int
    name: str
    type: str
    description: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    radius_m: Optional[float] = None
    is_approved: bool
    aliases: list[str] = []

    class Config:
        from_attributes = True


class LocationCreateIn(UTCModel):
    name: str
    type: str = "other"
    description: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    radius_m: Optional[float] = None
    aliases: list[str] = []


class LocationBulkDeleteIn(BaseModel):
    ids: list[int]


class TripCreateIn(UTCModel):
    from_location_id: Optional[int] = None
    to_location_id: Optional[int] = None
    from_text: str
    to_text: str
    from_note: Optional[str] = None
    to_note: Optional[str] = None
    scheduled_at: datetime
    seats_total: int = Field(ge=1, le=15)
    price: int = Field(ge=0)
    note: Optional[str] = None


class TripOut(UTCModel):
    id: int
    driver_id: int
    driver_user_id: Optional[int] = None
    driver_name: str = ""
    driver_rating: float = 5.0
    driver_reviews: int = 0
    driver_phone: str = ""
    driver_photo: Optional[str] = None
    driver_avg_response_sec: Optional[int] = None
    driver_is_online: bool = False
    car_model: str = ""
    plate: str = ""
    car_photo: Optional[str] = None
    from_text: str
    to_text: str
    from_note: Optional[str] = None
    scheduled_at: datetime
    seats_total: int
    seats_available: int
    price: int
    note: Optional[str] = None
    status: str
    created_at: datetime


class BookTripIn(UTCModel):
    seats: int = Field(default=1, ge=1, le=15)
    note: Optional[str] = None
    exact_pickup: Optional[str] = None
    # Trip "ochiq" bo'lsa (haydovchi yo'nalish/narx belgilamagan e'lon
    # qilgan) — yo'lovchi o'zi kiritgan haqiqiy yo'nalish/narx.
    from_text: Optional[str] = None
    to_text: Optional[str] = None
    offered_price: Optional[int] = None


class IncreaseSeatsIn(UTCModel):
    new_seats: int = Field(ge=1, le=15)


class SeatIncreaseRespondIn(BaseModel):
    accept: bool


class TripBookingOut(UTCModel):
    id: int
    trip_id: int
    passenger_id: int
    seats: int
    status: str
    agreed_price: Optional[int] = None
    eta_minutes: Optional[int] = None
    eta_arrive_at: Optional[datetime] = None
    picked_up_at: Optional[datetime] = None
    exact_pickup: Optional[str] = None
    note: Optional[str] = None
    pending_seats: Optional[int] = None
    cancelled_by: Optional[str] = None
    cancel_reason: Optional[str] = None
    cancelled_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime
    expires_at: Optional[datetime] = None
    trip: TripOut
    passenger_name: str = ""
    passenger_phone: str = ""
    passenger_rating: float = 5.0
    passenger_photo: Optional[str] = None


class RequestCreateIn(UTCModel):
    from_location_id: Optional[int] = None
    to_location_id: Optional[int] = None
    from_text: str
    to_text: str
    exact_place: Optional[str] = None
    scheduled_at: datetime
    passengers_count: int = Field(ge=1, le=15)
    has_luggage: bool = False
    note: Optional[str] = None
    offered_price: int = Field(ge=1000)


class DriverRespondIn(UTCModel):
    action: str  # accept|reject
    offered_price: Optional[int] = Field(default=None, ge=1000)
    message: Optional[str] = None
    eta_minutes: Optional[int] = Field(default=None, ge=1, le=300)


class SelectDriverIn(UTCModel):
    driver_id: int


class CancelIn(UTCModel):
    reason: str


class DriverResponseOut(UTCModel):
    id: int
    driver_id: int
    driver_name: str
    driver_rating: float
    experience_years: int
    car_model: str
    plate: str
    photo: Optional[str] = None
    car_photo: Optional[str] = None
    phone: str
    status: str
    offered_price: Optional[int] = None
    passenger_offered_price: int
    final_price: int


class RequestOut(UTCModel):
    id: int
    passenger_id: int
    from_text: str
    to_text: str
    exact_place: Optional[str] = None
    scheduled_at: datetime
    passengers_count: int
    has_luggage: bool
    note: Optional[str] = None
    offered_price: int
    agreed_price: Optional[int] = None
    status: str
    selected_driver_id: Optional[int] = None
    responses: list[DriverResponseOut] = []
    created_at: datetime
    expires_at: Optional[datetime] = None
    passenger_name: str = ""
    passenger_phone: str = ""
    passenger_photo: Optional[str] = None


class DriverApplyIn(UTCModel):
    experience_years: int = Field(ge=0, le=60)
    model_name: str
    plate: str
    seats: int = Field(ge=1, le=15)
    color: Optional[str] = None


class OnlineIn(UTCModel):
    is_online: bool
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class HeartbeatIn(UTCModel):
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class NotificationOut(UTCModel):
    id: int
    title: str
    body: str
    type: str
    is_read: bool
    related_type: Optional[str] = None
    related_id: Optional[int] = None
    created_at: datetime


class MessageIn(UTCModel):
    body: str
    request_id: Optional[int] = None
    trip_id: Optional[int] = None
    receiver_id: int


class MessageOut(UTCModel):
    id: int
    sender_id: int
    receiver_id: int
    body: str
    is_read: bool
    created_at: datetime
    request_id: Optional[int] = None
    trip_id: Optional[int] = None


class MessageReadIn(BaseModel):
    trip_id: Optional[int] = None
    request_id: Optional[int] = None


class RatingIn(UTCModel):
    request_id: Optional[int] = None
    trip_id: Optional[int] = None
    to_user_id: int
    stars: int = Field(ge=1, le=5)
    comment: Optional[str] = None


class AdminLoginIn(UTCModel):
    phone: str
    password: str


class AdminOut(UTCModel):
    id: int
    phone: str
    email: Optional[str] = None
    full_name: str
    role: str
    is_active: bool
    created_at: Optional[datetime] = None


class AdminTokenOut(UTCModel):
    access_token: str
    token_type: str = "bearer"
    admin: AdminOut


class AdminProfileUpdateIn(UTCModel):
    full_name: Optional[str] = Field(default=None, min_length=2, max_length=120)
    email: Optional[str] = None
    phone: Optional[str] = None


class AdminPasswordChangeIn(UTCModel):
    current_password: str
    new_password: str
    confirm_password: str


class StatusUpdateIn(UTCModel):
    status: str
    reason: Optional[str] = None


class UserUpdateIn(UTCModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None


class TripUpdateIn(UTCModel):
    from_text: Optional[str] = None
    to_text: Optional[str] = None
    scheduled_at: Optional[datetime] = None
    seats_total: Optional[int] = Field(default=None, ge=1, le=15)
    price: Optional[int] = Field(default=None, ge=0)
    note: Optional[str] = None


class RequestUpdateIn(UTCModel):
    from_text: Optional[str] = None
    to_text: Optional[str] = None
    exact_place: Optional[str] = None
    scheduled_at: Optional[datetime] = None
    offered_price: Optional[int] = Field(default=None, ge=0)
    passengers_count: Optional[int] = Field(default=None, ge=1, le=15)
    has_luggage: Optional[bool] = None
    note: Optional[str] = None


class ClientErrorIn(UTCModel):
    message: str
    detail: Optional[str] = None
    path: Optional[str] = None
    app_version: Optional[str] = None


class ErrorLogOut(UTCModel):
    id: int
    source: str
    message: str
    detail: Optional[str] = None
    path: Optional[str] = None
    user_id: Optional[int] = None
    app_version: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class NotifyBroadcastIn(UTCModel):
    title: str
    body: str
    audience: str = "all"  # all|drivers|passengers|user
    user_id: Optional[int] = None
    type: str = "admin"


TokenResponse.model_rebuild()
