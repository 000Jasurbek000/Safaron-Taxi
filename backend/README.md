# SAFARON TAXI — API (lokal)

## Windows

```powershell
cd backend
.\run_local.ps1
```

## Linux / macOS

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp -n .env.example .env
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

- API: http://127.0.0.1:8000
- Admin: http://127.0.0.1:8000/admin/
- Docs: http://127.0.0.1:8000/docs
- Health: http://127.0.0.1:8000/health

Admin: `.env` dagi `SAFARON_ADMIN_PHONE` / `SAFARON_ADMIN_PASSWORD`  
Dev OTP: `1234`
