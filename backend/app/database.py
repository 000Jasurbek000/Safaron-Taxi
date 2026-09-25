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
        ],
        "admin_logs": [("ip", "VARCHAR(64)")],
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


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
