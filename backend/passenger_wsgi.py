"""Phusion Passenger entry point for SAFARON FastAPI.

Passenger looks for `application` in this file.
FastAPI app object: app.main:app
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent
os.chdir(BACKEND_DIR)
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.main import app as application  # noqa: E402
