"""Local day planner and restart-safe focus timer; no external calendar account."""
from datetime import date, datetime
from copy import deepcopy
import time
import uuid

from ..core.state import ConfigError, atomic_json, read_object, state_lock


def empty():
    return {"schemaVersion": 1, "events": [], "tasks": [], "note": "",
            "timer": {"duration": 1500, "remaining": 1500, "endsAt": 0}}


def text(value, limit=200):
    if not isinstance(value, str) or not value.strip() or len(value) > limit or "\0" in value:
        raise ConfigError(f"Enter text (up to {limit} characters)")
    return value.strip()


def day(value):
    try:
        if date.fromisoformat(value).isoformat() != value:
            raise ValueError()
    except (ValueError, TypeError):
        raise ConfigError("Date must be in YYYY-MM-DD format") from None
    return value


def validate(data):
    if data.get("schemaVersion") != 1 or not isinstance(data.get("events"), list) or not isinstance(data.get("tasks"), list):
        raise ConfigError("Unknown planner schema; original file preserved")
    if not isinstance(data.get("note"), str):
        raise ConfigError("Corrupt note; original file preserved")
    identifiers = set()
    for kind in ("events", "tasks"):
        for item in data[kind]:
            if not isinstance(item, dict):
                raise ConfigError("Corrupt planner entries")
            identifier = text(item.get("id"))
            if identifier in identifiers:
                raise ConfigError("Duplicate entry identifier")
            identifiers.add(identifier)
            day(item.get("date")); text(item.get("title"))
            if kind == "events":
                clock_time(item.get("time"))
            elif type(item.get("done")) is not bool:
                raise ConfigError("Corrupt task status")
    timer = data.get("timer")
    if not isinstance(timer, dict) or type(timer.get("duration")) is not int or not 60 <= timer["duration"] <= 7200:
        raise ConfigError("Corrupted timer duration")
    if type(timer.get("remaining")) is not int or not 0 <= timer["remaining"] <= timer["duration"]:
        raise ConfigError("Corrupted timer remaining")
    if type(timer.get("endsAt")) not in (int, float) or not 0 <= timer["endsAt"] < 10**12:
        raise ConfigError("Corrupted timer endsAt")
    return data


def clock_time(value):
    try:
        if not isinstance(value, str) or datetime.strptime(value, "%H:%M").strftime("%H:%M") != value:
            raise ValueError()
    except (ValueError, TypeError):
        raise ConfigError("Time must be in HH:MM format") from None
    return value


def organizer(paths, action="get", payload=None, *, now=None):
    now = time.time() if now is None else now
    payload = {} if payload is None else payload
    if not isinstance(payload, dict):
        raise ConfigError("Expected JSON object")
    target = paths.state / "organizer.json"
    with state_lock(paths):
        data = validate(read_object(target)) if target.exists() else empty()
        previous = deepcopy(data)
        timer = data["timer"]
        if timer["endsAt"] and timer["endsAt"] <= now:
            timer.update(endsAt=0, remaining=0)
        if action in ("task-add", "event-add"):
            kind = "tasks" if action == "task-add" else "events"
            item = {"id": uuid.uuid4().hex, "date": day(payload.get("date")), "title": text(payload.get("title"))}
            if kind == "tasks": item["done"] = False
            else: item["time"] = clock_time(payload.get("time"))
            data[kind].append(item)
        elif action in ("task-toggle", "item-remove"):
            identifier = payload.get("id")
            items = data["tasks"] if action == "task-toggle" else data["tasks"] + data["events"]
            item = next((item for item in items if item["id"] == identifier), None)
            if item is None: raise ConfigError("Entry already deleted")
            if action == "task-toggle": item["done"] = not item["done"]
            else:
                for kind in ("tasks", "events"): data[kind] = [entry for entry in data[kind] if entry["id"] != identifier]
        elif action == "note":
            note = payload.get("text")
            if not isinstance(note, str) or len(note) > 100000 or "\0" in note:
                raise ConfigError("Note too long or contains invalid character")
            data["note"] = note
        elif action == "timer-start":
            if not timer["endsAt"]:
                timer["remaining"] = timer["remaining"] or timer["duration"]
                timer["endsAt"] = now + timer["remaining"]
        elif action == "timer-pause":
            if timer["endsAt"]:
                timer["remaining"] = max(0, min(timer["duration"], round(timer["endsAt"] - now)))
                timer["endsAt"] = 0
        elif action == "timer-reset": timer.update(endsAt=0, remaining=timer["duration"])
        elif action == "timer-duration":
            minutes = payload.get("minutes")
            if type(minutes) is not int or not 1 <= minutes <= 120:
                raise ConfigError("Duration must be between 1 and 120 minutes")
            timer.update(duration=minutes * 60, remaining=minutes * 60, endsAt=0)
        elif action != "get": raise ConfigError("Unknown planner action")
        if data != previous or not target.exists(): atomic_json(target, data)
        return data
