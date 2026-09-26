"""Passenger startup file. Entry point: application."""
from __future__ import annotations

import os
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent
os.chdir(BACKEND_DIR)
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from a2wsgi import ASGIMiddleware
from app.main import app

application = ASGIMiddleware(app)
