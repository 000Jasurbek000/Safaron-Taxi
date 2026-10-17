import math

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.deps import get_current_user, get_optional_user
from app.models import Location, LocationAlias, User
from app.schemas import LocationCreateIn, LocationOut, OkResponse
from app.services.notify import notify

router = APIRouter(prefix="/locations", tags=["locations"])

_EARTH_RADIUS_M = 6_371_000.0


def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Ikki koordinata orasidagi masofa (metrda)."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * _EARTH_RADIUS_M * math.asin(math.sqrt(a))


def _loc_out(loc: Location) -> LocationOut:
    return LocationOut(
        id=loc.id,
        name=loc.name,
        type=loc.type,
        description=loc.description,
        latitude=loc.latitude,
        longitude=loc.longitude,
        radius_m=loc.radius_m,
        is_approved=loc.is_approved,
        aliases=[a.alias for a in loc.aliases],
    )


@router.get("", response_model=list[LocationOut])
def list_locations(
    q: str | None = Query(None),
    db: Session = Depends(get_db),
    _: User | None = Depends(get_optional_user),
):
    query = (
        db.query(Location)
        .options(joinedload(Location.aliases))
        .filter(Location.is_active.is_(True), Location.is_approved.is_(True))
    )
    if q:
        like = f"%{q.strip()}%"
        alias_ids = db.query(LocationAlias.location_id).filter(LocationAlias.alias.ilike(like))
        query = query.filter(or_(Location.name.ilike(like), Location.id.in_(alias_ids)))
    rows = query.order_by(Location.name.asc()).limit(100).all()
    return [_loc_out(r) for r in rows]


@router.post("", response_model=LocationOut)
def suggest_location(body: LocationCreateIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    name = body.name.strip()
    if len(name) < 2:
        raise HTTPException(400, "Joy nomi juda qisqa.")
    existing = db.query(Location).filter(Location.name.ilike(name)).first()
    if existing and existing.is_approved:
        raise HTTPException(400, "Bu joy allaqachon mavjud.")
    loc = Location(
        name=name,
        type=body.type or "other",
        description=body.description,
        latitude=body.latitude,
        longitude=body.longitude,
        is_active=True,
        is_approved=False,
        created_by=user.id,
    )
    db.add(loc)
    db.flush()
    for a in body.aliases:
        alias = a.strip()
        if alias:
            db.add(LocationAlias(location_id=loc.id, alias=alias))
    notify(
        db,
        user_id=user.id,
        title="Joy taklifi qabul qilindi",
        body=f"“{name}” admin tasdiqini kutmoqda.",
        type="location",
        related_type="location",
        related_id=loc.id,
    )
    db.commit()
    loc = db.query(Location).options(joinedload(Location.aliases)).filter(Location.id == loc.id).one()
    return _loc_out(loc)


@router.get("/resolve", response_model=LocationOut)
def resolve_location(
    lat: float = Query(...),
    lng: float = Query(...),
    db: Session = Depends(get_db),
    _: User | None = Depends(get_optional_user),
):
    """Admin belgilagan doira (lat/lng/radius_m) ichiga tushgan nuqta uchun
    eng yaqin joy nomini topadi — qishloqlarda xaritadan tanlashda nom
    avtomatik yoziladi (masalan Algabas, radius 1 km)."""
    rows = (
        db.query(Location)
        .options(joinedload(Location.aliases))
        .filter(
            Location.is_active.is_(True),
            Location.is_approved.is_(True),
            Location.latitude.isnot(None),
            Location.longitude.isnot(None),
            Location.radius_m.isnot(None),
        )
        .all()
    )
    best: Location | None = None
    best_dist = None
    for loc in rows:
        dist = _haversine_m(lat, lng, loc.latitude, loc.longitude)
        if dist <= loc.radius_m and (best_dist is None or dist < best_dist):
            best = loc
            best_dist = dist
    if best is None:
        raise HTTPException(404, "Bu nuqta uchun belgilangan joy topilmadi.")
    return _loc_out(best)


@router.get("/{location_id}", response_model=LocationOut)
def get_location(location_id: int, db: Session = Depends(get_db)):
    loc = db.query(Location).options(joinedload(Location.aliases)).filter(Location.id == location_id).first()
    if not loc or not loc.is_approved:
        raise HTTPException(404, "Ma'lumot topilmadi.")
    return _loc_out(loc)
