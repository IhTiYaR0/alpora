"""Durable desktop layout and bounded, cached Open-Meteo requests."""
from copy import deepcopy
import json
import math
import time
from urllib.parse import urlencode
from urllib.request import urlopen

from ..core.state import ConfigError, atomic_json, read_object, state_lock
from ..services.developer_metrics import snapshot as developer_metrics_snapshot

DEFAULTS = {
    "animations": True,
    "screen": "",
    "clock": {"enabled": True, "x": 0, "y": 0},
    "weather": {"enabled": True, "x": 100, "y": 0},
    "music": {"enabled": True, "x": 100, "y": 238},
    "developer": {"enabled": True, "x": 0, "y": 220},
    "apps": {"enabled": True, "x": 50, "y": 430},
    "location": {"name": "Almaty", "latitude": 43.25, "longitude": 76.95},
}


def validate(value):
    # Existing layouts gain motion and new widgets without changing their positions or city.
    if isinstance(value, dict):
        if 'animations' not in value:
            value = value | {'animations': True}
        if 'developer' not in value:
            value = value | {'developer': deepcopy(DEFAULTS['developer'])}
        if 'apps' not in value:
            value = value | {'apps': deepcopy(DEFAULTS['apps'])}
    if not isinstance(value, dict) or set(value) != set(DEFAULTS):
        raise ConfigError("Invalid widget settings")
    if type(value['animations']) is not bool:
        raise ConfigError("Invalid animation settings")
    if not isinstance(value['screen'], str) or len(value['screen']) > 128 or '\0' in value['screen']:
        raise ConfigError("Invalid monitor")
    for key in ('clock', 'weather', 'music', 'developer', 'apps'):
        item = value[key]
        if not isinstance(item, dict) or set(item) != {'enabled', 'x', 'y'} or type(item['enabled']) is not bool:
            raise ConfigError("Invalid widget parameters: " + key)
        for axis, limit in (('x', 100), ('y', 8192)):
            if type(item[axis]) is not int or not 0 <= item[axis] <= limit:
                raise ConfigError("Widget coordinates out of bounds: " + key)
    loc = value['location']
    if not isinstance(loc, dict) or set(loc) != {'name', 'latitude', 'longitude'}:
        raise ConfigError("Invalid city")
    if not isinstance(loc['name'], str) or not loc['name'].strip() or len(loc['name']) > 160:
        raise ConfigError("Specify city name")
    for key, limit in (('latitude', 90), ('longitude', 180)):
        if type(loc[key]) not in (int, float) or not math.isfinite(loc[key]) or abs(loc[key]) > limit:
            raise ConfigError("Invalid city coordinates")
    return deepcopy(value)


def values_for(paths):
    target = paths.config / 'widgets.json'
    if not target.exists():
        return deepcopy(DEFAULTS)
    saved = read_object(target)
    if saved.get('schemaVersion') != 1:
        raise ConfigError("Unknown widget settings schema")
    return validate(saved.get('values'))


def request_json(base, params):
    try:
        with urlopen(base + '?' + urlencode(params), timeout=8) as response:
            data = json.loads(response.read(1024 * 1024))
        if not isinstance(data, dict) or data.get('error'):
            raise ValueError('invalid response')
        return data
    except (OSError, ValueError) as exc:
        raise ConfigError("Weather service unreachable. Try again later.") from exc


def search(city):
    if not isinstance(city, str) or not 2 <= len(city.strip()) <= 100:
        raise ConfigError("Enter city name (at least 2 letters)")
    data = request_json('https://geocoding-api.open-meteo.com/v1/search',
                        {'name': city.strip(), 'count': 5, 'language': 'ru', 'format': 'json'})
    return {'results': [{'name': item['name'], 'latitude': item['latitude'],
                         'longitude': item['longitude'], 'description': ', '.join(
                             str(item[k]) for k in ('admin1', 'country') if item.get(k))}
                        for item in data.get('results', [])]}


def weather(paths):
    location = values_for(paths)['location']
    key = [location['latitude'], location['longitude']]
    cache_path = paths.state / 'weather.json'
    cached = {}
    if cache_path.exists():
        try:
            cached = read_object(cache_path)
            if (cached.get('coordinates') != key or not isinstance(cached.get('current'), dict)
                    or type(cached.get('fetchedAt')) not in (int, float)
                    or not math.isfinite(cached['fetchedAt'])
                    or not isinstance(cached.get('forecast'), list)
                    or type(cached['current'].get('temperature_2m')) not in (int, float)):
                cached = {}
        except ConfigError:
            pass
    now = time.time()
    if cached and 0 <= now - cached.get('fetchedAt', 0) < 1800:
        return cached | {'location': location['name'], 'stale': False, 'error': ''}
    try:
        data = request_json('https://api.open-meteo.com/v1/forecast', {
            'latitude': key[0], 'longitude': key[1], 'timezone': 'auto', 'forecast_days': 3,
            'current': 'temperature_2m,weather_code,is_day',
            'daily': 'weather_code,temperature_2m_max,temperature_2m_min'})
        current, daily = data['current'], data['daily']
        numbers = [current['temperature_2m'], current['weather_code'], current['is_day']]
        forecast = []
        for index, day in enumerate(daily['time'][:3]):
            high, low, code = (daily[k][index] for k in ('temperature_2m_max', 'temperature_2m_min', 'weather_code'))
            numbers.extend([high, low, code])
            forecast.append({'day': day, 'high': high, 'low': low, 'code': code})
        if len(forecast) != 3 or any(type(n) not in (int, float) or not math.isfinite(n) for n in numbers):
            raise ValueError('invalid weather')
        result = {'coordinates': key, 'fetchedAt': now, 'current': current, 'forecast': forecast}
        atomic_json(cache_path, result)
        return result | {'location': location['name'], 'stale': False, 'error': ''}
    except (ConfigError, KeyError, IndexError, TypeError, ValueError, OSError):
        return cached | {'location': location['name'], 'stale': bool(cached),
                         'error': 'Weather unavailable · check connection'}


def widgets_control(paths, action, payload):
    if action == 'metrics':
        sock_path = paths.runtime / 'ipc.sock'
        if sock_path.exists():
            try:
                import socket as _socket
                if hasattr(_socket, 'AF_UNIX'):
                    with _socket.socket(_socket.AF_UNIX, _socket.SOCK_STREAM) as s:
                        s.settimeout(0.8)
                        s.connect(str(sock_path))
                        s.sendall(b'{"id":"cli","action":"metrics.snapshot","params":{}}\n')
                        line = s.makefile('r', encoding='utf-8').readline()
                        if line:
                            resp = json.loads(line)
                            if resp.get('success') and resp.get('data'):
                                return resp['data']
            except Exception:
                pass
        return developer_metrics_snapshot()
    if action == 'weather':
        return weather(paths)
    if action == 'search':
        return search(payload.get('city'))
    with state_lock(paths):
        current = values_for(paths)
        if action == 'get':
            return {'values': current, 'defaults': deepcopy(DEFAULTS)}
        if not isinstance(payload, dict) or set(payload) - {'values', 'expected'}:
            raise ConfigError("Invalid widgets request")
        if 'expected' in payload and validate(payload['expected']) != current:
            raise ConfigError("Settings have changed. Discard changes and try again.")
        value = validate(payload.get('values'))
        atomic_json(paths.config / 'widgets.json', {'schemaVersion': 1, 'values': value})
        return {'saved': True, 'values': value}
