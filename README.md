# SAFARON

**Bir yo�lda birga** � yo�lovchi + haydovchi + admin taxi/carpooling platformasi.

## Stack

| Qism | Texnologiya |
|------|-------------|
| Mobil | Flutter (`lib/`) |
| API | FastAPI + SQLAlchemy + SQLite |
| Admin | HTML/CSS/JS (`backend/admin_panel/`) |

## Backend ishga tushirish

```bash
cd backend
python -m venv .venv312
.\.venv312\Scripts\pip install -r requirements.txt   # Windows
.\.venv312\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- API docs: http://127.0.0.1:8000/docs  
- Admin panel: http://127.0.0.1:8000/admin/  
- Health: http://127.0.0.1:8000/health  

### Seed akkauntlar

| Rol | Telefon | Parol / OTP |
|-----|---------|-------------|
| Super Admin | `+998901112233` | `admin12345` |
| Test yo�lovchi | `+998901234567` | OTP `1234` |
| Test haydovchi (APPROVED) | `+998907654321` | OTP `1234` |
| Pending haydovchi | `+998933334455` | OTP `1234` |

Dev OTP har doim: **1234** (`.env` ? `SAFARON_OTP_DEV_CODE`).

## Flutter

```bash
flutter pub get
flutter run -d chrome
```

API manzil: `lib/services/api_client.dart`  
- Web/desktop: `http://127.0.0.1:8000`  
- Android emulator: `http://10.0.2.2:8000`

## Asosiy API

- `POST /api/auth/otp/send` � `POST /api/auth/otp/verify`
- `GET/POST /api/locations` � admin approve
- `POST /api/requests` � respond � select � status � cancel
- `GET/POST /api/trips` � book
- `POST /api/drivers/apply` � online � heartbeat
- `GET /api/notifications`
- `POST /api/admin/auth/login` � dashboard � users � drivers � locations � �

## Holat mashinasi (so�rov)

`SEARCHING ? DRIVER_ACCEPTED ? PASSENGER_SELECTED ? CONFIRMED ? DRIVER_ON_WAY ? PASSENGER_PICKED ? IN_PROGRESS ? COMPLETED`  
(+ `CANCELLED` / `EXPIRED`)

## Eslatma

- Productionda `SAFARON_SECRET_KEY`, admin parol va PostgreSQL URL ni almashtiring.
- Hujjatlar `/uploads` da; admin panel orqali tasdiqlanadi.
- To�liq i18n (uz/ru/en) UI matnlari bosqichma-bosqich kengaytirilmoqda; til saqlash API orqali ishlaydi.
