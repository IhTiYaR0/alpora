"""A saved, cyclic time-of-day position; the shell blends images in memory."""
import os
from pathlib import Path
import signal
import subprocess

from ..core.state import ConfigError, ROOT, atomic_json, read_object, state_lock

DEFAULT_MINUTE = 1110
STOPS = ((0, 'night', 'Night'), (330, 'dawn', 'Dawn'),
         (480, 'morning', 'Morning'), (780, 'day', 'Day'),
         (1110, 'sunset', 'Sunset'), (1260, 'dusk', 'Dusk'))

# Semantic colors for the same six lighting states as the wallpaper.
PALETTES = (
    ('#131c30', '#232e49', '#e9eef7', '#a8b4ce', '#9eafe8', '#bdacda', '#88b9df', '#465578'),
    ('#292433', '#403648', '#f5eaf0', '#c8b6ca', '#dcaccb', '#edb2a5', '#adb8dc', '#715b78'),
    ('#242f35', '#35484c', '#eff3ed', '#b6c7c5', '#d6ccab', '#ecc89a', '#9cc7da', '#627e83'),
    ('#1f2e38', '#324755', '#eef5f8', '#afc7d4', '#9ecbdc', '#c9d8aa', '#8ebbe5', '#5a7c91'),
    ('#30272a', '#4b3938', '#f7eee4', '#cdb9b2', '#e3b796', '#f1c186', '#c5b4cd', '#83655c'),
    ('#211f35', '#35314d', '#eeeafa', '#b8b0cf', '#baa9dd', '#d3a2ba', '#9daedb', '#615878'),
)
PALETTE_KEYS = ('background', 'surface', 'text', 'muted', 'accent', 'secondary', 'cool', 'border')


def palette_for(minute):
    value = validate_minute(minute)
    lower = len(STOPS) - 1
    for index in range(len(STOPS) - 1):
        if value < STOPS[index + 1][0]:
            lower = index
            break
    upper = (lower + 1) % len(STOPS)
    start, end = STOPS[lower][0], STOPS[upper][0] if upper else 1440
    t = (value - start) / (end - start)
    t = t * t * (3 - 2 * t)
    def blend(a, b):
        return '#' + ''.join(f'{int(int(a[i:i+2],16)*(1-t) + int(b[i:i+2],16)*t + .5):02x}' for i in (1,3,5))
    return {key: blend(a, b) for key, a, b in zip(PALETTE_KEYS, PALETTES[lower], PALETTES[upper])}


def validate_minute(value):
    if type(value) is not int or not 0 <= value <= 1440:
        raise ConfigError('Timeline time must be between 00:00 and 24:00')
    return value % 1440


def saved_minute(paths):
    path = paths.config / 'timeline.json'
    if not path.exists():
        return DEFAULT_MINUTE
    saved = read_object(path)
    if saved.get('schemaVersion') != 1:
        raise ConfigError('Unknown Timeline settings schema')
    return validate_minute(saved.get('minute'))


def assets():
    result = []
    for minute, name, label in STOPS:
        path = ROOT / 'assets/wallpapers/timeline' / (name + '.png')
        if not path.is_file():
            raise ConfigError('Timeline landscape not found: ' + name)
        result.append({'minute': minute, 'name': name, 'label': label, 'image': str(path),
                       'palette': palette_for(minute)})
    return result


def release_fallback():
    """Remove only this theme's static renderer once every output is ready."""
    expected = str(ROOT / 'assets/wallpapers/timeline/sunset.png')
    uid_str = str(os.getuid()) if hasattr(os, 'getuid') else '1000'
    result = subprocess.run(['pgrep', '-u', uid_str, '-x', 'swaybg'],
                            capture_output=True, text=True, timeout=3, check=False)
    for token in result.stdout.split():
        if not token.isdecimal(): continue
        try:
            args = Path('/proc', token, 'cmdline').read_bytes().decode().split('\0')
            if any(arg in ('-i', '--image') and index + 1 < len(args) and args[index + 1] == expected
                   for index, arg in enumerate(args)):
                os.kill(int(token), signal.SIGTERM)
        except ProcessLookupError:
            pass
        except FileNotFoundError:
            pass


def timeline_control(paths, action, payload):
    if not isinstance(payload, dict):
        raise ConfigError('Invalid Timeline request')
    with state_lock(paths):
        if action == 'get':
            return {'minute': saved_minute(paths), 'stops': assets()}
        if action == 'ready':
            if payload: raise ConfigError('Invalid Timeline readiness request')
            selected = paths.config / 'appearance.json'
            if not selected.exists() or read_object(selected).get('theme') != 'timeline':
                return {'presented': False}
            release_fallback()
            return {'presented': True}
        if action == 'sync-clock':
            from datetime import datetime
            now = datetime.now()
            minute = now.hour * 60 + now.minute
            selected = paths.config / 'appearance.json'
            if not selected.exists() or read_object(selected).get('theme') != 'timeline':
                return {'synced': False, 'minute': minute, 'reason': 'Timeline theme not active'}
            assets()
            selection = read_object(selected)
            if selection.get('colorsFromWallpaper', True):
                from .themes import apply_timeline_palette
                apply_timeline_palette(paths, minute, palette_for(minute), selection)
            else:
                atomic_json(paths.config / 'timeline.json', {'schemaVersion': 1, 'minute': minute})
            return {'synced': True, 'saved': True, 'minute': minute}
        if action != 'set' or set(payload) != {'minute'}:
            raise ConfigError('Invalid Timeline request')
        minute = validate_minute(payload['minute'])
        selected = paths.config / 'appearance.json'
        if not selected.exists() or read_object(selected).get('theme') != 'timeline':
            raise ConfigError('Select Timeline theme in settings first')
        # Validate both images/config before replacing the last saved position.
        assets()
        saved_minute(paths)
        selection = read_object(selected)
        if selection.get('colorsFromWallpaper', True):
            from .themes import apply_timeline_palette
            apply_timeline_palette(paths, minute, palette_for(minute), selection)
        else:
            atomic_json(paths.config / 'timeline.json', {'schemaVersion': 1, 'minute': minute})
        return {'saved': True, 'minute': minute}
