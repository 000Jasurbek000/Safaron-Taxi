#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SAFARON TAXI - PRODUCTION BACKEND DEPLOY
# ============================================================

PROJECT_DIR="/home/safaronu/Safaron-Taxi/backend"
VENV_DIR="/home/safaronu/virtualenv/Safaron-Taxi/backend/3.12"
PYTHON_BIN="${VENV_DIR}/bin/python"
PIP_BIN="${VENV_DIR}/bin/pip"

REPO_URL="https://github.com/000Jasurbek000/Safaron-Taxi.git"
BRANCH="main"

DOMAIN="https://safaron.uz"
HEALTH_URL="${DOMAIN}/health"

DEPLOY_TMP="/tmp/safaron-deploy"
LOCK_DIR="/tmp/safaron-deploy.lock"

# ============================================================
# COLORS
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================
# ERROR HANDLER
# ============================================================

cleanup() {
    rm -rf "${DEPLOY_TMP}" 2>/dev/null || true
    rmdir "${LOCK_DIR}" 2>/dev/null || true
}

trap cleanup EXIT

on_error() {
    error "Deploy muvaffaqiyatsiz tugadi."
    error "Production ma'lumotlar o'zgartirilmagan bo'lishi kerak."
    exit 1
}

trap on_error ERR

# ============================================================
# LOCK
# ============================================================

if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    error "Boshqa deploy jarayoni allaqachon ishlayapti."
    exit 1
fi

# ============================================================
# BASIC CHECKS
# ============================================================

info "Production directory tekshirilmoqda..."

if [[ ! -d "${PROJECT_DIR}" ]]; then
    error "PROJECT_DIR topilmadi: ${PROJECT_DIR}"
    exit 1
fi

if [[ ! -x "${PYTHON_BIN}" ]]; then
    error "Python topilmadi: ${PYTHON_BIN}"
    exit 1
fi

if [[ ! -x "${PIP_BIN}" ]]; then
    error "pip topilmadi: ${PIP_BIN}"
    exit 1
fi

if [[ ! -f "${PROJECT_DIR}/.env" ]]; then
    error ".env mavjud emas!"
    exit 1
fi

if [[ ! -f "${PROJECT_DIR}/passenger_wsgi.py" ]]; then
    error "passenger_wsgi.py mavjud emas!"
    exit 1
fi

ok "Production environment tayyor."

# ============================================================
# VERSION
# ============================================================

DEPLOY_TIME="$(date '+%Y-%m-%d %H:%M:%S')"

info "Deploy boshlandi: ${DEPLOY_TIME}"

# ============================================================
# PREPARE TEMP DIRECTORY
# ============================================================

rm -rf "${DEPLOY_TMP}"
mkdir -p "${DEPLOY_TMP}"

info "GitHub repository olinmoqda..."

cd "${DEPLOY_TMP}"

git clone \
    --depth 1 \
    --branch "${BRANCH}" \
    "${REPO_URL}" \
    repo

ok "GitHub repository olindi."

cd "${DEPLOY_TMP}/repo"

COMMIT_SHA="$(git rev-parse HEAD)"
COMMIT_SHORT="$(git rev-parse --short HEAD)"

info "Commit: ${COMMIT_SHA}"

# ============================================================
# EXTRACT ONLY BACKEND
# ============================================================

info "Faqat backend katalogi ajratilmoqda..."

mkdir -p "${DEPLOY_TMP}/backend"

git archive HEAD backend \
    | tar -x \
        --strip-components=1 \
        -C "${DEPLOY_TMP}/backend"

ok "Faqat backend tayyorlandi."

# ============================================================
# VERIFY BACKEND
# ============================================================

if [[ ! -f "${DEPLOY_TMP}/backend/requirements.txt" ]]; then
    error "backend/requirements.txt topilmadi."
    exit 1
fi

if [[ ! -d "${DEPLOY_TMP}/backend/app" ]]; then
    error "backend/app topilmadi."
    exit 1
fi

ok "Backend strukturasi tekshirildi."

# ============================================================
# PRODUCTION PROTECTED FILES
# ============================================================

info "Production fayllari himoyalanmoqda..."

PROTECTED_ENV="${DEPLOY_TMP}/production.env"
PROTECTED_PASSENGER="${DEPLOY_TMP}/production.passenger_wsgi.py"
PROTECTED_DEPLOY="${DEPLOY_TMP}/production.deploy.sh"

cp "${PROJECT_DIR}/.env" "${PROTECTED_ENV}"
cp "${PROJECT_DIR}/passenger_wsgi.py" "${PROTECTED_PASSENGER}"

if [[ -f "${PROJECT_DIR}/deploy.sh" ]]; then
    cp "${PROJECT_DIR}/deploy.sh" "${PROTECTED_DEPLOY}"
fi

ok ".env va passenger_wsgi.py himoyalandi."

# ============================================================
# SYNC BACKEND
# ============================================================

info "Backend production serverga yangilanmoqda..."

if command -v rsync >/dev/null 2>&1; then

    rsync -a --delete \
        --exclude='.env' \
        --exclude='data/' \
        --exclude='uploads/' \
        --exclude='passenger_wsgi.py' \
        --exclude='deploy.sh' \
        --exclude='public/' \
        --exclude='tmp/' \
        "${DEPLOY_TMP}/backend/" \
        "${PROJECT_DIR}/"

else

    warn "rsync topilmadi. Python fallback sync ishlatiladi."

    "${PYTHON_BIN}" - <<PY
from pathlib import Path
import shutil

src = Path("${DEPLOY_TMP}/backend")
dst = Path("${PROJECT_DIR}")

protected = {
    ".env",
    "data",
    "uploads",
    "passenger_wsgi.py",
    "deploy.sh",
    "public",
    "tmp",
}

for item in dst.iterdir():
    if item.name in protected:
        continue

    if item.name == ".git":
        continue

    if item.name not in {x.name for x in src.iterdir()}:
        if item.is_dir():
            shutil.rmtree(item)
        else:
            item.unlink()

for item in src.iterdir():

    if item.name in protected:
        continue

    target = dst / item.name

    if item.is_dir():

        if target.exists():
            shutil.rmtree(target)

        shutil.copytree(item, target)

    else:

        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(item, target)

PY

fi

ok "Backend code yangilandi."

# ============================================================
# RESTORE PROTECTED FILES
# ============================================================

info "Production konfiguratsiyasi tiklanmoqda..."

cp "${PROTECTED_ENV}" "${PROJECT_DIR}/.env"
cp "${PROTECTED_PASSENGER}" "${PROJECT_DIR}/passenger_wsgi.py"

if [[ -f "${PROTECTED_DEPLOY}" ]]; then
    cp "${PROTECTED_DEPLOY}" "${PROJECT_DIR}/deploy.sh"
    chmod +x "${PROJECT_DIR}/deploy.sh"
fi

ok "Production konfiguratsiyasi saqlandi."

# ============================================================
# PYTHON DEPENDENCIES
# ============================================================

info "Python dependencies tekshirilmoqda..."

"${PYTHON_BIN}" -m pip install \
    --disable-pip-version-check \
    -r "${PROJECT_DIR}/requirements.txt"

ok "Python dependencies tayyor."

# ============================================================
# FASTAPI IMPORT TEST
# ============================================================

info "FastAPI import test..."

cd "${PROJECT_DIR}"

"${PYTHON_BIN}" - <<'PY'
from app.main import app

print("APP:", app.title)
print("FASTAPI IMPORT: OK")
PY

ok "FastAPI import OK."

# ============================================================
# DATABASE TEST
# ============================================================

info "PostgreSQL connection test..."

"${PYTHON_BIN}" - <<'PY'
from app.database import engine

with engine.connect() as connection:
    result = connection.exec_driver_sql("SELECT version()")
    version = result.scalar()

print("POSTGRESQL:", version)
print("DATABASE CONNECTION: OK")
PY

ok "PostgreSQL connection OK."

# ============================================================
# DATABASE TABLE CHECK
# ============================================================

info "Database tables tekshirilmoqda..."

"${PYTHON_BIN}" - <<'PY'
from app.database import engine, Base, ensure_columns
import app.models

Base.metadata.create_all(bind=engine)
ensure_columns()

print("DATABASE TABLE CHECK: OK")
PY

ok "Database tables OK."

# ============================================================
# PASSENGER TEST
# ============================================================

info "Passenger WSGI test..."

"${PYTHON_BIN}" - <<'PY'
from passenger_wsgi import application

print("PASSENGER APPLICATION:", type(application).__name__)
print("PASSENGER IMPORT: OK")
PY

ok "Passenger WSGI OK."

# ============================================================
# RESTART PASSENGER
# ============================================================

info "Passenger restart qilinmoqda..."

touch "${PROJECT_DIR}/passenger_wsgi.py"

ok "Passenger restart trigger qilindi."

# ============================================================
# HEALTH CHECK
# ============================================================

info "Production health endpoint tekshirilmoqda..."

HEALTH_RESPONSE=""

for i in {1..10}; do

    if HEALTH_RESPONSE="$(curl -fsS --max-time 10 "${HEALTH_URL}" 2>/dev/null)"; then

        if echo "${HEALTH_RESPONSE}" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then
            ok "Health check OK."
            echo
            echo "${HEALTH_RESPONSE}"
            break
        fi

    fi

    if [[ "${i}" -eq 10 ]]; then
        error "Health check muvaffaqiyatsiz."
        error "URL: ${HEALTH_URL}"
        exit 1
    fi

    sleep 2

done

# ============================================================
# SUCCESS
# ============================================================

echo
echo "============================================================"
echo "                 DEPLOY SUCCESS"
echo "============================================================"
echo
echo "Project : SAFARON TAXI"
echo "Branch  : ${BRANCH}"
echo "Commit  : ${COMMIT_SHA}"
echo "Time    : ${DEPLOY_TIME}"
echo "Domain  : ${DOMAIN}"
echo
echo "Backend : UPDATED"
echo "Database: PRESERVED"
echo ".env    : PRESERVED"
echo "Uploads : PRESERVED"
echo "Data    : PRESERVED"
echo "Passenger: RESTARTED"
echo "Health  : OK"
echo
echo "============================================================"
