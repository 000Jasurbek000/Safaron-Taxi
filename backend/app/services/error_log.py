from sqlalchemy.orm import Session

from app.models import ErrorLog

_MAX_LEN = 4000


def log_error(
    db: Session,
    *,
    source: str,
    message: str,
    detail: str | None = None,
    path: str | None = None,
    user_id: int | None = None,
    app_version: str | None = None,
) -> None:
    """Xatoni error_logs jadvaliga yozadi. Bu funksiya hech qachon xato tashlamasin —
    xato logini yozishning o'zi yana xato keltirib chiqarmasligi kerak."""
    try:
        row = ErrorLog(
            source=source[:20],
            message=(message or "")[:_MAX_LEN],
            detail=(detail or None) and detail[:_MAX_LEN],
            path=(path or None) and path[:255],
            user_id=user_id,
            app_version=(app_version or None) and app_version[:40],
        )
        db.add(row)
        db.commit()
    except Exception:
        try:
            db.rollback()
        except Exception:
            pass
