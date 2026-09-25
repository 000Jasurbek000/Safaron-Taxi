from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=str(BASE_DIR / ".env"), env_prefix="SAFARON_", extra="ignore")

    secret_key: str = "dev-secret-change-me-safaron-2026"
    database_url: str = f"sqlite:///{(BASE_DIR / 'data' / 'safaron.db').as_posix()}"
    otp_dev_code: str = "1234"
    admin_phone: str = "+998901112233"
    admin_password: str = "admin12345"
    cors_origins: str = "*"
    upload_dir: str = str(BASE_DIR / "uploads")
    access_token_expire_minutes: int = 60 * 24 * 30
    booking_timeout_sec: int = 300
    driver_heartbeat_sec: int = 60
    driver_offline_after_sec: int = 120
    timezone: str = "Asia/Tashkent"
    max_upload_mb: int = 8
    app_name: str = "SAFARON"


@lru_cache
def get_settings() -> Settings:
    return Settings()
