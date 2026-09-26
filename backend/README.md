# SAFARON TAXI — API

Python FastAPI backend + admin panel.

## Ishga tushirish

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
nano .env
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- API: `http://SERVER_IP:8000`
- Admin: `http://SERVER_IP:8000/admin/`
- Docs: `http://SERVER_IP:8000/docs`
