#!/usr/bin/env bash
# SAFARON TAXI — production deploy (backend only)
# Run from: /home/safaronu/Safaron-Taxi/backend
set -euo pipefail

BACKEND_DIR="/home/safaronu/Safaron-Taxi/backend"
VENV_ACTIVATE="/home/safaronu/virtualenv/Safaron-Taxi/backend/3.12/bin/activate"
DOMAIN="https://safaron.uz"

step=0
fail() {
  echo
  echo "ERROR: $1"
  echo "Deploy to‘xtadi (bosqich ${step})."
  echo ".env, data/ va uploads/ o‘zgartirilmadi."
  exit 1
}

ok() {
  echo "  OK: $1"
}

begin() {
  step=$((step + 1))
  echo
  echo "[${step}] $1"
}

trap 'fail "kutilmagan xatolik (exit $?)"' ERR

echo "========================================"
echo " SAFARON backend deploy"
echo " ${BACKEND_DIR}"
echo "========================================"

begin "Backend katalogini tekshirish"
if [ ! -d "${BACKEND_DIR}" ]; then
  fail "${BACKEND_DIR} topilmadi"
fi
cd "${BACKEND_DIR}" || fail "backend katalogiga o‘tib bo‘lmadi"
if [ ! -f "app/main.py" ] || [ ! -f "requirements.txt" ]; then
  fail "backend fayllari yo‘q (app/main.py yoki requirements.txt)"
fi
ok "ishchi katalog: $(pwd)"

begin "Muhim production fayllarni saqlash (.env, data, uploads)"
if [ ! -f ".env" ]; then
  echo "  OGOHLANTIRISH: .env yo‘q. GitHub'dan olinmaydi — serverda qo‘lda yarating."
else
  ok ".env saqlanadi"
fi
mkdir -p data uploads/drivers uploads/vehicles uploads/docs
ok "data/ va uploads/ saqlanadi (o‘chirilmaydi)"

begin "Git pull (faqat kod, production fayllarsiz)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "${REPO_ROOT}" ]; then
  fail "git repository topilmadi"
fi
ok "repo: ${REPO_ROOT}"
git -C "${REPO_ROOT}" pull --ff-only || fail "git pull muvaffaqiyatsiz"
ok "kod yangilandi"

begin "Virtualenv: Python 3.12"
if [ ! -f "${VENV_ACTIVATE}" ]; then
  fail "virtualenv topilmadi: ${VENV_ACTIVATE}"
fi
# shellcheck disable=SC1090
source "${VENV_ACTIVATE}" || fail "virtualenv aktivlashmadi"
ok "$(python -c 'import sys; print(sys.executable)')"
ok "$(python -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"

begin "Dependencylar (requirements.txt)"
python -m pip install -r requirements.txt || fail "pip install xato"
ok "requirements o‘rnatildi"

begin "Backend import testi (app.main:app)"
python -c "from app.main import app; print(app.title)" || fail "app import qilinmadi"
ok "FastAPI application yuklandi"

echo
echo "========================================"
echo " SUCCESS"
echo " Backend: ${BACKEND_DIR}"
echo " Domain:  ${DOMAIN}"
echo " Admin:   ${DOMAIN}/admin/"
echo " Docs:    ${DOMAIN}/docs"
echo " Health:  ${DOMAIN}/health"
echo "========================================"
