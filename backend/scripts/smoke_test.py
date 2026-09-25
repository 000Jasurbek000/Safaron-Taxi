import httpx

b = httpx.Client(base_url="http://127.0.0.1:8000", timeout=30.0)
print("health", b.get("/health").json())
r = b.post("/api/auth/otp/send", json={"phone": "901234567"})
print("otp", r.status_code, r.json())
r = b.post(
    "/api/auth/otp/verify",
    json={"phone": "901234567", "code": "1234", "first_name": "Test", "last_name": "User"},
)
print("verify", r.status_code)
data = r.json()
print("user", data.get("user", {}).get("full_name"), data.get("detail"))
tok = data["access_token"]
h = {"Authorization": f"Bearer {tok}"}
print("locs", len(b.get("/api/locations", headers=h).json()))

a = b.post("/api/admin/auth/login", json={"phone": "+998901112233", "password": "admin12345"})
print("admin", a.status_code, a.json().get("admin", a.text))
ah = {"Authorization": f"Bearer {a.json()['access_token']}"}
print("dash", b.get("/api/admin/dashboard", headers=ah).json())

b.post("/api/auth/otp/send", json={"phone": "+998907654321"})
r2 = b.post("/api/auth/otp/verify", json={"phone": "+998907654321", "code": "1234"})
print("driver verify", r2.status_code, r2.json().get("user", {}).get("driver_status"))
dh = {"Authorization": f"Bearer {r2.json()['access_token']}"}
print("online", b.post("/api/drivers/online", headers=dh, json={"is_online": True}).json())

req = b.post(
    "/api/requests",
    headers=h,
    json={
        "from_text": "Qizil qala",
        "to_text": "Beruniy",
        "scheduled_at": "2026-09-20T10:00:00",
        "passengers_count": 1,
        "has_luggage": False,
        "offered_price": 100000,
        "exact_place": "Azam magazin",
    },
)
print("request", req.status_code, req.json())
rid = req.json()["id"]
acc = b.post(f"/api/requests/{rid}/respond", headers=dh, json={"action": "accept", "offered_price": 120000})
print("accept", acc.status_code, acc.json().get("status"), acc.json().get("detail"))
resp = acc.json()
sel = b.post(f"/api/requests/{rid}/select", headers=h, json={"driver_id": resp["responses"][0]["driver_id"]})
print("select", sel.status_code, sel.json().get("status"), sel.json().get("agreed_price"), sel.json().get("detail"))
