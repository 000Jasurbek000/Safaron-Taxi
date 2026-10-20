from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=str(BASE_DIR / ".env"), env_prefix="SAFARON_", extra="ignore")

    # Qasddan standart qiymatsiz — .env'da SAFARON_SECRET_KEY va
    # SAFARON_ADMIN_PASSWORD aniq o'rnatilmasa, ilova ishga tushmay xato
    # beradi. Avval bu yerda zaif, umumga oshkor standart qiymatlar bor edi
    # va production ularni hech qachon almashtirmagan edi.
    secret_key: str
    admin_password: str
    database_url: str = f"sqlite:///{(BASE_DIR / 'data' / 'safaron.db').as_posix()}"
    otp_dev_code: str = "1234"
    admin_phone: str = "+998901112233"
    cors_origins: str = "*"
    upload_dir: str = str(BASE_DIR / "uploads")
    access_token_expire_minutes: int = 60 * 24 * 30
    booking_timeout_sec: int = 300
    instant_booking_timeout_sec: int = 3600
    driver_heartbeat_sec: int = 60
    driver_offline_after_sec: int = 120
    timezone: str = "Asia/Tashkent"
    max_upload_mb: int = 8
    app_name: str = "SAFARON"


@lru_cache
def get_settings() -> Settings:
    return Settings()
