from collections.abc import Generator

from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import get_settings

settings = get_settings()

connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
engine = create_engine(settings.database_url, connect_args=connect_args, future=True)

if settings.database_url.startswith("sqlite"):

    @event.listens_for(engine, "connect")
    def _sqlite_pragma(dbapi_conn, _):
        cursor = dbapi_conn.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()


SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)


class Base(DeclarativeBase):
    pass


def ensure_columns() -> None:
    """Mavjud SQLite/Postgres jadvallariga yangi ustunlar."""
    wanted = {
        "users": [
            ("referral_code", "VARCHAR(16)"),
            ("referred_by_user_id", "INTEGER"),
            ("telegram_username", "VARCHAR(64)"),
            ("verified_trip_count", "INTEGER DEFAULT 0"),
            ("deleted_at", "TIMESTAMP"),
            ("hide_phone", "BOOLEAN DEFAULT FALSE"),
        ],
        "admin_logs": [("ip", "VARCHAR(64)")],
        "locations": [("radius_m", "FLOAT")],
        "trip_bookings": [
            ("agreed_price", "INTEGER"),
            ("eta_minutes", "INTEGER"),
            ("eta_arrive_at", "TIMESTAMP"),
            ("picked_up_at", "TIMESTAMP"),
            ("expires_at", "TIMESTAMP"),
            ("completed_at", "TIMESTAMP"),
            ("exact_pickup", "VARCHAR(255)"),
            ("note", "TEXT"),
            ("pending_seats", "INTEGER"),
        ],
        "messages": [
            ("request_id", "INTEGER"),
            ("trip_id", "INTEGER"),
        ],
    }
    insp = inspect(engine)
    names = set(insp.get_table_names())
    with engine.begin() as conn:
        for table, cols in wanted.items():
            if table not in names:
                continue
            have = {c["name"] for c in insp.get_columns(table)}
            for col, ddl in cols:
                if col not in have:
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {col} {ddl}"))

        # Mavjud (ilgari deploy qilingan) bazalarda hali ham eski
        # (trip_id, passenger_id) UNIQUE cheklovi bo'lishi mumkin — uni olib
        # tashlaymiz, aks holda models.py'dan o'chirilgan bo'lsa ham eski
        # bazada hali amal qilib, qayta band qilishni bloklab turaveradi.
        # SQLite ALTER TABLE orqali cheklov o'chirishni qo'llab-quvvatlamaydi
        # (jadvalni to'liq qayta qurishni talab qiladi) — bu faqat lokal/test
        # bazalar uchun, ular bir martalik bo'lgani uchun o'tkazib yuboriladi.
        if "trip_bookings" in names and engine.dialect.name == "postgresql":
            conn.execute(text("ALTER TABLE trip_bookings DROP CONSTRAINT IF EXISTS uq_trip_passenger"))


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
