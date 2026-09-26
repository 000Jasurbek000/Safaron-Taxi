from datetime import datetime

from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import (
    BonusRule,
    DriverProfile,
    FeatureFlag,
    FraudRule,
    Location,
    LocationAlias,
    SystemSetting,
    User,
    Vehicle,
)
from app.services.admin_auth import ensure_seed_admin
from app.services.rewards import ensure_code


SEED_LOCATIONS = [
    ("Beruniy", "city", ["Beruniy shahar", "Beruniy markazi", "Беруний", "Beruniy tumani"], 41.6911, 60.7525),
    ("Boston", "village", ["boston", "Boston mahalla"], 41.6520, 60.8100),
    ("Algabas", "mahalla", ["Alg‘abas", "Алғабас", "Algabas OFY"], 41.7780, 60.6480),
    ("Qizil qala", "village", ["Qizilqala", "Qizil-Qala", "Qizil qala OFY", "Қизил қалъа"], 41.8480, 60.6180),
    ("Sadvin", "mahalla", ["Sadvin OFY"], 41.8350, 60.6250),
    ("Beruniy markazi", "landmark", ["Markaz", "Beruniy markaz", "Hokimiyat"], 41.6915, 60.7530),
    ("Beruniy balnitsa", "landmark", ["Balnitsa", "Kasalxona"], 41.6890, 60.7490),
    ("Urganch", "city", ["Urgench", "Ургенч"], 41.5500, 60.6330),
    ("Urganch vokzal", "landmark", ["Vokzal"], 41.5480, 60.6400),
    ("Xiva", "city", ["Хива"], 41.3775, 60.3639),
    ("Xonqa", "district", [], 41.5330, 60.8000),
    ("Gurlan", "district", [], 41.8410, 60.3910),
    ("Tuproqqala", "district", ["Tuproq qala"], 41.7200, 60.8200),
    ("Bozor", "landmark", ["Beruniy bozor"], 41.6920, 60.7510),
]


def seed(db: Session) -> None:
    settings = get_settings()
    # .env paroli faqat admin yo‘q bo‘lsa ishlatiladi — mavjud hash qayta yozilmaydi.
    ensure_seed_admin(db, settings.admin_phone, settings.admin_password)

    defaults = {
        "app_name": "SAFARON",
        "slogan": "Bir yo‘lda birga",
        "support_phone": "+998914490219",
        "default_language": "uz",
        "allowed_languages": "uz,ru,en",
        "max_passengers": "15",
        "latest_version": "1.1.0",
        "minimum_version": "1.0.0",
        "version_code": "4",
        "update_url": "/api/app/apk",
        "force_update": "false",
        "telegram_admin_username": "Safaron_bot",
        "withdrawal_min": "1000",
        "withdrawal_max": "5000000",
        "maintenance_message": "Safaron texnik xizmat ko‘rsatish rejimida.",
        "driver_approval_required": "true",
        "location_approval_required": "true",
        "booking_timeout_sec": str(settings.booking_timeout_sec),
        "timezone": "Asia/Tashkent",
    }
    for k, v in defaults.items():
        if not db.query(SystemSetting).filter(SystemSetting.key == k).first():
            db.add(SystemSetting(key=k, value=v))

    if db.query(Location).count() == 0:
        for name, typ, aliases, lat, lng in SEED_LOCATIONS:
            loc = Location(
                name=name,
                type=typ,
                latitude=lat,
                longitude=lng,
                is_approved=True,
                is_active=True,
            )
            db.add(loc)
            db.flush()
            for a in aliases:
                db.add(LocationAlias(location_id=loc.id, alias=a))
    else:
        for name, typ, aliases, lat, lng in SEED_LOCATIONS:
            loc = db.query(Location).filter(Location.name == name).first()
            if loc is None:
                loc = Location(
                    name=name,
                    type=typ,
                    latitude=lat,
                    longitude=lng,
                    is_approved=True,
                    is_active=True,
                )
                db.add(loc)
                db.flush()
                for a in aliases:
                    db.add(LocationAlias(location_id=loc.id, alias=a))
            elif loc.latitude is None or loc.longitude is None:
                loc.latitude = lat
                loc.longitude = lng

    # Test passenger
    p_phone = "+998901234567"
    passenger = db.query(User).filter(User.phone == p_phone).first()
    if not passenger:
        passenger = User(phone=p_phone, first_name="Dilshod", last_name="Yoqubov", active_role="passenger", language="uz")
        db.add(passenger)

    # Test approved driver
    d_phone = "+998907654321"
    driver_user = db.query(User).filter(User.phone == d_phone).first()
    if not driver_user:
        driver_user = User(phone=d_phone, first_name="Jasur", last_name="Haydarov", active_role="driver", language="uz")
        db.add(driver_user)
        db.flush()
        dp = DriverProfile(
            user_id=driver_user.id,
            status="APPROVED",
            experience_years=5,
            is_online=True,
            last_seen_at=datetime.utcnow(),
            approved_at=datetime.utcnow(),
            rating_avg=4.9,
            trips_count=42,
        )
        db.add(dp)
        db.flush()
        db.add(Vehicle(driver_id=dp.id, model_name="Chevrolet Cobalt", plate="90A123BC", seats=4, color="Oq"))

    # Pending driver
    pend_phone = "+998933334455"
    pend = db.query(User).filter(User.phone == pend_phone).first()
    if not pend:
        pend = User(phone=pend_phone, first_name="Sardor", last_name="Pending", active_role="passenger")
        db.add(pend)
        db.flush()
        db.add(DriverProfile(user_id=pend.id, status="PENDING", experience_years=2))

    flags = [
        ("bonus", True, "Bonus menyusi"),
        ("referral", True, "Taklif kodi"),
        ("withdrawal", True, "Bonus yechish"),
        ("passenger_registration", True, "Yo‘lovchi ro‘yxati"),
        ("driver_registration", True, "Haydovchi ro‘yxati"),
        ("new_orders", True, "Yangi buyurtmalar"),
        ("driver_mode", True, "Haydovchi rejimi"),
        ("passenger_mode", True, "Yo‘lovchi rejimi"),
        ("notifications", True, "Bildirishnomalar"),
        ("maintenance", False, "Texnik rejim"),
    ]
    for key, enabled, desc in flags:
        if not db.query(FeatureFlag).filter(FeatureFlag.key == key).first():
            db.add(FeatureFlag(key=key, enabled=enabled, description=desc))

    rules = [
        ("passenger_referral", "Yo‘lovchi referral", 5000, 1, False),
        ("driver_referral", "Haydovchi referral", 10000, 1, False),
        ("passenger_first_trip", "Birinchi safar", 5000, 1, False),
        ("driver_milestone", "Haydovchi milestone", 15000, 5, False),
    ]
    for key, title, amount, trips, repeatable in rules:
        if not db.query(BonusRule).filter(BonusRule.key == key).first():
            db.add(BonusRule(key=key, title=title, amount=amount, required_trips=trips, enabled=True, repeatable=repeatable))

    fraud = [("min_distance_m", "300"), ("min_duration_sec", "120"), ("gps_min_accuracy_m", "80")]
    for key, value in fraud:
        if not db.query(FraudRule).filter(FraudRule.key == key).first():
            db.add(FraudRule(key=key, value=value, enabled=True))

    for user in db.query(User).filter(User.referral_code.is_(None)).all():
        ensure_code(db, user)

    db.commit()
