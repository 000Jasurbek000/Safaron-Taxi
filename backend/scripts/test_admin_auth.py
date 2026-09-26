"""Admin auth production checks. Mavjud yozuvlarni o‘chirmaydi."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from fastapi.testclient import TestClient

from app.config import get_settings
from app.database import SessionLocal
from app.main import app
from app.models import AdminLog, AdminUser, Location, User
from app.security import safe_decode
from app.services.admin_auth import create_admin

TEST_PHONE = "+998909998877"
TEST_PASS = "TestPass123"
TEST_PASS_NEW = "NewSafe456"


def _fail(msg: str) -> None:
    print(f"FAIL  {msg}")
    raise SystemExit(1)


def _ok(msg: str) -> None:
    print(f"OK    {msg}")


def _snapshot(db):
    admins = {
        a.id: (a.phone, a.role, a.full_name, a.password_hash, a.is_active)
        for a in db.query(AdminUser).all()
    }
    return {
        "admins": admins,
        "users": db.query(User).count(),
        "locations": db.query(Location).count(),
    }


def main() -> None:
    settings = get_settings()
    client = TestClient(app)
    db = SessionLocal()
    test_admin_id = None
    try:
        before = _snapshot(db)
        seed_phone = settings.admin_phone
        seed_admin = db.query(AdminUser).filter(AdminUser.phone == seed_phone).first()
        if not seed_admin:
            _fail("Seed admin topilmadi — existing record buzilgan bo‘lishi mumkin.")
        seed_id = seed_admin.id
        seed_role = seed_admin.role
        seed_name = seed_admin.full_name
        seed_hash = seed_admin.password_hash
        _ok(f"existing seed admin id={seed_id} phone={seed_admin.phone} role={seed_role}")

        if seed_hash == settings.admin_password:
            _fail("Seed admin paroli plain text saqlangan.")
        if not str(seed_hash).startswith("$2"):
            _fail("password_hash bcrypt formatida emas.")
        _ok("seed password_hash hashed (plain text emas)")

        # 1) seed login
        r = client.post("/api/admin/auth/login", json={"phone": seed_phone, "password": settings.admin_password})
        if r.status_code != 200:
            print("  login body:", r.text[:300])
            _fail(f"admin login {r.status_code}")
        token = r.json()["access_token"]
        admin_body = r.json()["admin"]
        if admin_body.get("id") != seed_id:
            _fail("login javobidagi admin id noto‘g‘ri.")
        if "password_hash" in r.text or "password" in admin_body:
            _fail("login javobida parol yoki hash chiqmasligi kerak.")
        payload = safe_decode(token)
        if not payload or payload.get("typ") != "admin" or str(payload.get("sub")) != str(seed_id):
            _fail(f"JWT noto‘g‘ri: {payload}")
        _ok("admin login + JWT typ=admin")

        # 2) wrong password
        r = client.post("/api/admin/auth/login", json={"phone": seed_phone, "password": "wrong-password-99"})
        if r.status_code != 401 or r.json().get("detail") != "Login yoki parol noto‘g‘ri.":
            _fail(f"wrong password: {r.status_code} {r.json()}")
        _ok("wrong password -> 401 umumiy xabar")

        # throwaway admin — seed admin parolini o‘zgartirmaymiz
        existing_test = db.query(AdminUser).filter(AdminUser.phone == TEST_PHONE).first()
        if existing_test:
            db.query(AdminLog).filter(AdminLog.admin_id == existing_test.id).delete()
            db.delete(existing_test)
            db.commit()
        test_admin = create_admin(
            db,
            phone=TEST_PHONE,
            password=TEST_PASS,
            full_name="Auth Tester",
            role="ADMIN",
        )
        db.commit()
        test_admin_id = test_admin.id
        if test_admin.password_hash == TEST_PASS:
            _fail("Yangi admin paroli plain text yozilgan.")
        _ok(f"test admin yaratildi id={test_admin_id}")

        r = client.post("/api/admin/auth/login", json={"phone": TEST_PHONE, "password": TEST_PASS})
        if r.status_code != 200:
            _fail(f"test admin login {r.status_code} {r.text}")
        test_token = r.json()["access_token"]
        headers = {"Authorization": f"Bearer {test_token}"}
        _ok("test admin login")

        me = client.get("/api/admin/auth/me", headers=headers)
        if me.status_code != 200 or me.json()["id"] != test_admin_id:
            _fail(f"/auth/me {me.status_code} {me.text}")
        _ok("GET /auth/me o‘z profilini qaytaradi")

        # boshqa admin ma'lumotini JWT orqali o‘zgartirib bo‘lmaydi
        patched = client.patch(
            "/api/admin/auth/me",
            headers=headers,
            json={"full_name": "Auth Tester Updated", "email": "tester@safaron.uz"},
        )
        if patched.status_code != 200 or patched.json()["full_name"] != "Auth Tester Updated":
            _fail(f"profile update {patched.status_code} {patched.text}")
        db.refresh(seed_admin)
        if seed_admin.full_name != seed_name or seed_admin.id != seed_id or seed_admin.role != seed_role:
            _fail("Seed admin profili o‘zgargan — ruxsatsiz o‘zgarish.")
        _ok("profil yangilandi, seed admin tegilmagan")

        # 3) password change
        bad = client.post(
            "/api/admin/auth/password",
            headers=headers,
            json={"current_password": "not-current", "new_password": TEST_PASS_NEW, "confirm_password": TEST_PASS_NEW},
        )
        if bad.status_code != 400:
            _fail(f"noto‘g‘ri joriy parol {bad.status_code}")
        weak = client.post(
            "/api/admin/auth/password",
            headers=headers,
            json={"current_password": TEST_PASS, "new_password": "short", "confirm_password": "short"},
        )
        if weak.status_code != 400:
            _fail(f"zaif parol qabul qilindi {weak.status_code}")
        mismatch = client.post(
            "/api/admin/auth/password",
            headers=headers,
            json={"current_password": TEST_PASS, "new_password": TEST_PASS_NEW, "confirm_password": "Other789"},
        )
        if mismatch.status_code != 400:
            _fail("confirm mismatch qabul qilindi")
        ch = client.post(
            "/api/admin/auth/password",
            headers=headers,
            json={"current_password": TEST_PASS, "new_password": TEST_PASS_NEW, "confirm_password": TEST_PASS_NEW},
        )
        if ch.status_code != 200 or ch.json().get("ok") is not True:
            _fail(f"password change {ch.status_code} {ch.text}")
        _ok("current + new + confirm bilan parol yangilandi")

        old = client.post("/api/admin/auth/login", json={"phone": TEST_PHONE, "password": TEST_PASS})
        if old.status_code != 401 or old.json().get("detail") != "Login yoki parol noto‘g‘ri.":
            _fail(f"eski parol hali ishlayapti {old.status_code} {old.text}")
        _ok("eski parol bilan login muvaffaqiyatsiz")

        nxt = client.post("/api/admin/auth/login", json={"phone": TEST_PHONE, "password": TEST_PASS_NEW})
        if nxt.status_code != 200:
            _fail(f"yangi parol login {nxt.status_code} {nxt.text}")
        _ok("yangi parol bilan qayta login")

        # inactive
        row = db.get(AdminUser, test_admin_id)
        row.is_active = False
        db.commit()
        ina = client.post("/api/admin/auth/login", json={"phone": TEST_PHONE, "password": TEST_PASS_NEW})
        if ina.status_code != 403:
            _fail(f"inactive login {ina.status_code} {ina.text}")
        _ok("inactive admin -> 403")

        # OpenAPI
        spec = client.get("/openapi.json").json()
        paths = spec.get("paths", {})
        needed = ["/api/admin/auth/login", "/api/admin/auth/me", "/api/admin/auth/password"]
        missing = [p for p in needed if p not in paths]
        if missing:
            _fail(f"OpenAPI da yo‘q: {missing}")
        if "patch" not in paths["/api/admin/auth/me"]:
            _fail("PATCH /auth/me OpenAPI da yo‘q")
        _ok("endpointlar OpenAPI /docs da ko‘rinadi")

        db.expire_all()
        seed_now = db.get(AdminUser, seed_id)
        if (
            seed_now.phone != seed_phone
            or seed_now.role != seed_role
            or seed_now.full_name != seed_name
            or seed_now.password_hash != seed_hash
        ):
            _fail("Seed admin yozuvi o‘zgargan.")
        after_users = db.query(User).count()
        after_locs = db.query(Location).count()
        if after_users != before["users"] or after_locs != before["locations"]:
            _fail("Existing user/location yozuvlari o‘zgargan.")
        _ok("existing PostgreSQL/SQLite yozuvlari saqlanib qoldi")

        print("ALL PASSED")
    finally:
        if test_admin_id:
            db.query(AdminLog).filter(AdminLog.admin_id == test_admin_id).delete()
            row = db.get(AdminUser, test_admin_id)
            if row:
                db.delete(row)
            db.commit()
        db.close()


if __name__ == "__main__":
    main()
