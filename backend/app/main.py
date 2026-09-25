from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

import time
from collections import defaultdict

from app.api import admin, app_release, auth, drivers, locations, misc, platform, platform_admin, requests, trips, users
from app.config import get_settings
from app.database import Base, SessionLocal, engine, ensure_columns
from app.seed import seed

settings = get_settings()
Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)
Path(settings.upload_dir).joinpath("drivers").mkdir(exist_ok=True)
Path(settings.upload_dir).joinpath("vehicles").mkdir(exist_ok=True)
Path(settings.upload_dir).joinpath("docs").mkdir(exist_ok=True)
(Path(__file__).resolve().parent.parent / "data").mkdir(exist_ok=True)

app = FastAPI(title="SAFARON API", version="1.0.0", description="Bir yo‘lda birga")

origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if origins == ["*"] else origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(ValueError)
async def value_error_handler(_: Request, exc: ValueError):
    return JSONResponse(status_code=400, content={"detail": str(exc)})


@app.exception_handler(Exception)
async def unhandled(request: Request, exc: Exception):
    # Don't leak stack traces to clients
    return JSONResponse(status_code=500, content={"detail": "Server bilan bog‘lanishda xatolik yuz berdi."})


@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)
    ensure_columns()
    db = SessionLocal()
    try:
        seed(db)
    finally:
        db.close()


@app.get("/")
def root():
    return {
        "app": settings.app_name,
        "slogan": "Bir yo‘lda birga",
        "health": "/health",
        "docs": "/docs",
        "admin": "/admin/",
        "api": "/api/",
    }


@app.get("/health")
def health():
    return {"ok": True, "app": settings.app_name}


api = FastAPI()  # unused — mount routers on main
app.include_router(auth.router, prefix="/api")
app.include_router(users.router, prefix="/api")
app.include_router(locations.router, prefix="/api")
app.include_router(drivers.router, prefix="/api")
app.include_router(trips.router, prefix="/api")
app.include_router(requests.router, prefix="/api")
app.include_router(misc.router, prefix="/api")
app.include_router(app_release.router, prefix="/api")
app.include_router(admin.router, prefix="/api")
app.include_router(platform.router, prefix="/api")
app.include_router(platform_admin.router, prefix="/api")

_hits: dict[str, list[float]] = defaultdict(list)


@app.middleware("http")
async def rate_limit(request: Request, call_next):
    if request.url.path.startswith("/api/auth"):
        ip = request.client.host if request.client else "?"
        now = time.time()
        window = [t for t in _hits[ip] if now - t < 60]
        if len(window) >= 40:
            return JSONResponse(status_code=429, content={"detail": "Juda ko‘p so‘rov. Biroz kuting."})
        window.append(now)
        _hits[ip] = window
    return await call_next(request)

uploads = Path(settings.upload_dir)
app.mount("/uploads", StaticFiles(directory=str(uploads)), name="uploads")

admin_dir = Path(__file__).resolve().parent.parent / "admin_panel"
if admin_dir.exists():
    app.mount("/admin", StaticFiles(directory=str(admin_dir), html=True), name="admin")
