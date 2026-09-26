from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class ApiError(BaseModel):
    detail: str
    code: Optional[str] = None


class OkResponse(BaseModel):
    ok: bool = True
    message: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserOut"


class SendOtpIn(BaseModel):
    phone: str


class SendOtpOut(BaseModel):
    ok: bool = True
    message: Optional[str] = None
    user_exists: bool = False


class VerifyOtpIn(BaseModel):
    phone: str
    code: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None


class SignInIn(BaseModel):
    phone: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    referral_code: Optional[str] = None


class PhoneLookupOut(BaseModel):
    exists: bool
    first_name: str = ""
    last_name: str = ""
    full_name: str = ""
    phone_display: str = ""
    active_role: str = "passenger"


class UserOut(BaseModel):
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

    class Config:
        from_attributes = True


class RoleIn(BaseModel):
    role: str  # passenger|driver


class LanguageIn(BaseModel):
    language: str


class ProfileUpdateIn(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    experience_years: Optional[int] = Field(default=None, ge=0, le=60)


class ChangePhoneIn(BaseModel):
    phone: str
    code: str


class LocationOut(BaseModel):
    id: int
    name: str
    type: str
    description: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    is_approved: bool
    aliases: list[str] = []

    class Config:
        from_attributes = True


class LocationCreateIn(BaseModel):
    name: str
    type: str = "other"
    description: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    aliases: list[str] = []


class TripCreateIn(BaseModel):
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


class TripOut(BaseModel):
    id: int
    driver_id: int
    driver_user_id: Optional[int] = None
    driver_name: str = ""
    driver_rating: float = 5.0
    driver_reviews: int = 0
    driver_phone: str = ""
    driver_photo: Optional[str] = None
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


class BookTripIn(BaseModel):
    seats: int = Field(default=1, ge=1, le=15)


class RequestCreateIn(BaseModel):
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


class DriverRespondIn(BaseModel):
    action: str  # accept|reject
    offered_price: Optional[int] = Field(default=None, ge=1000)
    message: Optional[str] = None


class SelectDriverIn(BaseModel):
    driver_id: int


class CancelIn(BaseModel):
    reason: str


class DriverResponseOut(BaseModel):
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


class RequestOut(BaseModel):
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


class DriverApplyIn(BaseModel):
    experience_years: int = Field(ge=0, le=60)
    model_name: str
    plate: str
    seats: int = Field(ge=1, le=15)
    color: Optional[str] = None


class OnlineIn(BaseModel):
    is_online: bool
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class HeartbeatIn(BaseModel):
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class NotificationOut(BaseModel):
    id: int
    title: str
    body: str
    type: str
    is_read: bool
    related_type: Optional[str] = None
    related_id: Optional[int] = None
    created_at: datetime


class MessageIn(BaseModel):
    body: str
    request_id: Optional[int] = None
    trip_id: Optional[int] = None
    receiver_id: int


class MessageOut(BaseModel):
    id: int
    sender_id: int
    receiver_id: int
    body: str
    is_read: bool
    created_at: datetime
    request_id: Optional[int] = None
    trip_id: Optional[int] = None


class RatingIn(BaseModel):
    request_id: Optional[int] = None
    trip_id: Optional[int] = None
    to_user_id: int
    stars: int = Field(ge=1, le=5)
    comment: Optional[str] = None


class AdminLoginIn(BaseModel):
    phone: str
    password: str


class AdminOut(BaseModel):
    id: int
    phone: str
    email: Optional[str] = None
    full_name: str
    role: str
    is_active: bool
    created_at: Optional[datetime] = None


class AdminTokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    admin: AdminOut


class AdminProfileUpdateIn(BaseModel):
    full_name: Optional[str] = Field(default=None, min_length=2, max_length=120)
    email: Optional[str] = None
    phone: Optional[str] = None


class AdminPasswordChangeIn(BaseModel):
    current_password: str
    new_password: str
    confirm_password: str


class StatusUpdateIn(BaseModel):
    status: str
    reason: Optional[str] = None


class NotifyBroadcastIn(BaseModel):
    title: str
    body: str
    audience: str = "all"  # all|drivers|passengers|user
    user_id: Optional[int] = None
    type: str = "admin"


TokenResponse.model_rebuild()
