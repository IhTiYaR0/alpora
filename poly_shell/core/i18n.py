"""Lightweight internationalisation for Poly Shell.

Locale strings are stored as flat JSON objects keyed by dot-notation identifiers
(e.g. ``"weather.clear"``).  The module loads the requested locale file from
``assets/locales/`` and falls back to Russian when a key is missing.

The locale preference is read from ``settings.json`` (``locale`` field) and
injected into the session snapshot so that QML receives it alongside other
settings without an extra file watch.
"""
import json
import os
from pathlib import Path

from .state import ROOT

_LOCALES_DIR = ROOT / "assets" / "locales"
_DEFAULT_LOCALE = "en"
_SUPPORTED = ("en", "vi", "ru", "es")

# Module-level cache: ``{locale_code: {key: string}}``
_cache: dict[str, dict[str, str]] = {}


def _load(code: str) -> dict[str, str]:
    """Load and cache a locale file.  Returns ``{}`` if the file is missing."""
    if code in _cache:
        return _cache[code]
    path = _LOCALES_DIR / f"{code}.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        data = {}
    if not isinstance(data, dict):
        data = {}
    _cache[code] = data
    return data


def clear_cache() -> None:
    """Drop cached locale data.  Useful after file changes during tests."""
    _cache.clear()


def supported_locales() -> tuple[str, ...]:
    """Return the tuple of supported locale codes."""
    return _SUPPORTED


def tr(key: str, locale: str = _DEFAULT_LOCALE, **kwargs: str) -> str:
    """Look up *key* in the requested locale with English baseline fallback.

    Optional *kwargs* are interpolated into the result using ``str.format_map``
    so that translated strings can contain ``{name}`` placeholders.

    Returns the key itself as a last resort so the UI always shows *something*.
    """
    strings = _load(locale)
    value = strings.get(key)
    if value is None and locale != _DEFAULT_LOCALE:
        value = _load(_DEFAULT_LOCALE).get(key)
    if value is None:
        return key
    if kwargs:
        try:
            return value.format_map(kwargs)
        except (KeyError, ValueError):
            return value
    return value


def locale_for_settings(settings: dict) -> str:
    """Extract and validate the locale code from a settings dict."""
    code = settings.get("locale", _DEFAULT_LOCALE)
    if not isinstance(code, str) or code not in _SUPPORTED:
        return _DEFAULT_LOCALE
    return code


def locale_strings(locale: str) -> dict[str, str]:
    """Return the full merged string table for *locale* (with English baseline fallback).

    Every key present in the English file is guaranteed to appear in the result.
    """
    base = dict(_load(_DEFAULT_LOCALE))
    if locale != _DEFAULT_LOCALE:
        overlay = _load(locale)
        base.update(overlay)
    return base
