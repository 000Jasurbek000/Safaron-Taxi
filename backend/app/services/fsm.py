"""Trip / request finite state machine — invalid transitions raise ValueError."""

from __future__ import annotations

REQUEST_TRANSITIONS: dict[str, set[str]] = {
    "REQUESTED": {"SEARCHING", "CANCELLED", "EXPIRED"},
    "SEARCHING": {"DRIVER_ACCEPTED", "CANCELLED", "EXPIRED", "PASSENGER_SELECTED"},
    "DRIVER_ACCEPTED": {"PASSENGER_SELECTED", "CANCELLED", "EXPIRED", "SEARCHING"},
    "PASSENGER_SELECTED": {"CONFIRMED", "CANCELLED"},
    "CONFIRMED": {"DRIVER_ON_WAY", "CANCELLED"},
    "DRIVER_ON_WAY": {"PASSENGER_PICKED", "CANCELLED"},
    "PASSENGER_PICKED": {"IN_PROGRESS", "CANCELLED"},
    "IN_PROGRESS": {"COMPLETED", "CANCELLED"},
    "COMPLETED": set(),
    "CANCELLED": set(),
    "EXPIRED": set(),
}

DRIVER_RESPONSE_TRANSITIONS: dict[str, set[str]] = {
    "PENDING": {"ACCEPTED", "REJECTED", "EXPIRED"},
    "ACCEPTED": {"SELECTED", "NOT_SELECTED", "EXPIRED", "CANCELLED"},
    "REJECTED": set(),
    "SELECTED": {"CONFIRMED", "CANCELLED"},
    "NOT_SELECTED": set(),
    "EXPIRED": set(),
    "CANCELLED": set(),
}

TRIP_TRANSITIONS: dict[str, set[str]] = {
    "OPEN": {"FULL", "IN_PROGRESS", "CANCELLED", "EXPIRED", "COMPLETED"},
    "FULL": {"IN_PROGRESS", "CANCELLED", "OPEN"},
    "IN_PROGRESS": {"COMPLETED", "CANCELLED"},
    "COMPLETED": set(),
    "CANCELLED": set(),
    "EXPIRED": set(),
}


def can_transition(table: dict[str, set[str]], current: str, new: str) -> bool:
    return new in table.get(current, set())


def assert_transition(table: dict[str, set[str]], current: str, new: str, label: str = "status") -> None:
    if current == new:
        return
    if not can_transition(table, current, new):
        raise ValueError(f"Noto‘g‘ri {label} o‘tishi: {current} → {new}")
