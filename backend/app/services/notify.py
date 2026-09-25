from sqlalchemy.orm import Session

from app.models import Notification, User


def notify(
    db: Session,
    *,
    user_id: int,
    title: str,
    body: str,
    type: str = "system",
    related_type: str | None = None,
    related_id: int | None = None,
) -> Notification:
    n = Notification(
        user_id=user_id,
        title=title,
        body=body,
        type=type,
        related_type=related_type,
        related_id=related_id,
    )
    db.add(n)
    return n


def notify_many(db: Session, users: list[User], **kwargs) -> None:
    for u in users:
        notify(db, user_id=u.id, **kwargs)
