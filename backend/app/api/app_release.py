import json
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

router = APIRouter(prefix="/app", tags=["app"])

_RELEASES = Path(__file__).resolve().parent.parent.parent / "releases"
_APK = _RELEASES / "SAFARON.apk"
_META = _RELEASES / "version.json"


def _default_meta() -> dict:
    return {"version": "1.0.0", "build": 1, "filename": "SAFARON.apk"}


@router.get("/info")
def app_info():
    meta = _default_meta()
    if _META.exists():
        try:
            meta.update(json.loads(_META.read_text(encoding="utf-8")))
        except Exception:
            pass
    meta["apk_available"] = _APK.exists()
    if _APK.exists():
        meta["apk_size_mb"] = round(_APK.stat().st_size / (1024 * 1024), 1)
    return meta


@router.get("/apk")
def download_apk():
    if not _APK.exists():
        raise HTTPException(404, "APK hali yuklanmagan. Kompyuterdan build qiling.")
    return FileResponse(
        path=str(_APK),
        media_type="application/vnd.android.package-archive",
        filename="SAFARON.apk",
    )
