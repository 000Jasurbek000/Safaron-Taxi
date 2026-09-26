#!/usr/bin/env bash
# SAFARON API — serverga yangilash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> Git pull"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git pull --ff-only
else
  echo "Bu papka git repo emas. Avval:"
  echo "  git clone https://github.com/000Jasurbek000/Safaron-Taxi.git"
  exit 1
fi

echo "==> Virtualenv"
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
pip install -q -r requirements.txt

if [ ! -f ".env" ]; then
  cp .env.example .env
  echo "Diqqat: .env yaratildi. SECRET_KEY va parolni o‘zgartiring."
fi

mkdir -p data uploads/drivers uploads/vehicles uploads/docs

restart_uvicorn() {
  echo "==> Uvicorn qayta ishga tushirilmoqda (port 8000)"
  if command -v fuser >/dev/null 2>&1; then
    fuser -k 8000/tcp >/dev/null 2>&1 || true
  else
    pkill -f "uvicorn app.main:app" >/dev/null 2>&1 || true
  fi
  sleep 1
  nohup .venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 \
    > data/uvicorn.log 2>&1 &
  echo "PID $!"
}

echo "==> Restart"
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q '^safaron'; then
  sudo systemctl restart safaron
  sudo systemctl --no-pager --lines=8 status safaron || true
else
  restart_uvicorn
fi

echo "Tayyor."
echo "  API:   http://$(hostname -I 2>/dev/null | awk '{print $1}'):8000"
echo "  Admin: http://$(hostname -I 2>/dev/null | awk '{print $1}'):8000/admin/"
echo "Brauzerda Ctrl+F5 (hard refresh) qiling — eski logo keshda qolmasin."
