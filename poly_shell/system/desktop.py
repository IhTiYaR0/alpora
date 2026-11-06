"""Small adapters for desktop tools without QML service bindings."""
from concurrent import futures
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess
import time
import uuid
import json
import math

from ..adapters.base import SafeRunner
from ..core.state import ConfigError, ROOT, atomic_json, read_object, state_lock, settings_for, update_session
from .radios_power import power_status, radio_status, set_airplane, set_profile


ALLOWED_COMMAND_BINARIES = {
    'brightnessctl', 'bluetoothctl', 'rfkill', 'makoctl', 'hyprsunset',
    'hyprctl', 'nmcli', 'pgrep', 'swaybg', 'wpctl', 'powerprofilesctl',
    'systemctl', 'systemd-run', 'awww', 'swww', 'ip'
}


def command(args, *, check=True):
    if not isinstance(args, (list, tuple)) or not args:
        raise ConfigError("Invalid command arguments: must be non-empty sequence")
    binary = str(args[0])
    if binary not in ALLOWED_COMMAND_BINARIES:
        raise ConfigError(f"Unauthorized command binary: {binary}")
    clean_args = []
    for arg in args:
        s = str(arg)
        if "\x00" in s or "\r" in s or "\n" in s:
            raise ConfigError("Invalid control character in command argument")
        clean_args.append(s)
    result = SafeRunner.run(clean_args, timeout=5.0)
    if check and result.returncode:
        raise ConfigError((result.stderr or result.stdout).strip() or f"{binary} failed")
    return result


def backlight_device(root=Path('/sys/class/backlight')):
    for path in sorted(root.iterdir()) if root.exists() else []:
        try:
            maximum = int((path / 'max_brightness').read_text())
            current = int((path / 'brightness').read_text())
            if maximum > 0:
                return path.name, max(0, min(100, round(current / maximum * 100)))
        except (OSError, ValueError):
            continue
    return None, 0


def hotspot_config(paths):
    target = paths.config / 'hotspot.json'
    if target.exists():
        try:
            data = read_object(target)
            if isinstance(data, dict):
                return {
                    'ssid': str(data.get('ssid', 'Alpora-Hotspot')),
                    'password': str(data.get('password', 'alporapassword')),
                }
        except Exception:
            pass
    return {'ssid': 'Alpora-Hotspot', 'password': 'alporapassword'}


def hotspot_status(paths):
    if not shutil.which('nmcli'):
        return {
            'hotspotAvailable': False,
            'hotspot': False,
            'hotspotSsid': 'Alpora-Hotspot',
            'hotspotPassword': 'alporapassword',
            'hotspotClients': 0,
        }
    cfg = hotspot_config(paths)
    is_active = False
    active_device = None
    try:
        res = command(['nmcli', '-t', '-f', 'NAME,TYPE,DEVICE', 'connection', 'show', '--active'], check=False)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                parts = line.strip().split(':')
                if len(parts) >= 3 and parts[1] in ('802-11-wireless', 'wifi'):
                    cname = parts[0]
                    if cname in ('Hotspot', cfg['ssid']):
                        is_active = True
                        active_device = parts[2]
                        break
                    mode_res = command(['nmcli', '-t', '-f', '802-11-wireless.mode', 'connection', 'show', cname], check=False)
                    if mode_res.returncode == 0 and 'ap' in mode_res.stdout.lower():
                        is_active = True
                        active_device = parts[2]
                        break
    except Exception:
        pass

    clients = 0
    if is_active and active_device:
        try:
            neigh = command(['ip', 'neigh', 'show', 'dev', active_device], check=False)
            if neigh.returncode == 0:
                clients = len([l for l in neigh.stdout.splitlines() if any(k in l for k in ('REACHABLE', 'STALE', 'DELAY'))])
        except Exception:
            pass

    return {
        'hotspotAvailable': True,
        'hotspot': is_active,
        'hotspotSsid': cfg['ssid'],
        'hotspotPassword': cfg['password'],
        'hotspotClients': clients,
    }


def set_hotspot(paths, value):
    if not shutil.which('nmcli'):
        raise ConfigError('NetworkManager (nmcli) is required for Mobile Hotspot')
    cfg = hotspot_config(paths)

    if value and str(value).strip().startswith('{'):
        try:
            payload = json.loads(value)
            if not isinstance(payload, dict):
                raise ValueError
        except Exception as exc:
            raise ConfigError('Invalid hotspot configuration JSON') from exc

        if 'ssid' in payload:
            ssid = str(payload['ssid']).strip()
            if not ssid:
                raise ConfigError('Hotspot SSID cannot be empty')
            cfg['ssid'] = ssid
        if 'password' in payload:
            pwd = str(payload['password']).strip()
            if len(pwd) < 8:
                raise ConfigError('Hotspot password must be at least 8 characters')
            cfg['password'] = pwd
        atomic_json(paths.config / 'hotspot.json', cfg)
        if payload.get('active') is False:
            value = 'off'
        elif payload.get('active') is True:
            value = 'on'
        else:
            return

    current = hotspot_status(paths)
    if value in ('toggle', None, ''):
        value = 'off' if current['hotspot'] else 'on'

    if value not in ('on', 'off'):
        raise ConfigError("Hotspot value must be 'on', 'off', or configuration JSON")

    if value == 'on':
        command(['nmcli', 'radio', 'wifi', 'on'], check=False)
        chk = command(['nmcli', '-t', '-f', 'NAME', 'connection', 'show'], check=False)
        existing = [l.strip() for l in chk.stdout.splitlines() if l.strip()]
        if 'Hotspot' in existing:
            command(['nmcli', 'connection', 'modify', 'Hotspot',
                     '802-11-wireless.ssid', cfg['ssid'],
                     '802-11-wireless-security.key-mgmt', 'wpa-psk',
                     '802-11-wireless-security.psk', cfg['password'],
                     '802-11-wireless.mode', 'ap',
                     '802-11-wireless.band', 'bg',
                     'ipv4.method', 'shared'])
            command(['nmcli', 'connection', 'up', 'Hotspot'])
        else:
            try:
                command(['nmcli', 'device', 'wifi', 'hotspot', 'ssid', cfg['ssid'], 'password', cfg['password']])
            except ConfigError:
                command(['nmcli', 'connection', 'add', 'type', 'wifi', 'con-name', 'Hotspot',
                         'autoconnect', 'no', 'ssid', cfg['ssid'],
                         '802-11-wireless.mode', 'ap', '802-11-wireless.band', 'bg',
                         'ipv4.method', 'shared',
                         'wifi-sec.key-mgmt', 'wpa-psk', 'wifi-sec.psk', cfg['password']])
                command(['nmcli', 'connection', 'up', 'Hotspot'])
    elif value == 'off':
        chk = command(['nmcli', '-t', '-f', 'NAME,TYPE', 'connection', 'show', '--active'], check=False)
        if chk.returncode == 0:
            for l in chk.stdout.splitlines():
                parts = l.strip().split(':')
                if len(parts) >= 2 and parts[1] in ('802-11-wireless', 'wifi'):
                    cname = parts[0]
                    if cname in ('Hotspot', cfg['ssid']):
                        command(['nmcli', 'connection', 'down', cname], check=False)
                    else:
                        mode_res = command(['nmcli', '-t', '-f', '802-11-wireless.mode', 'connection', 'show', cname], check=False)
                        if mode_res.returncode == 0 and 'ap' in mode_res.stdout.lower():
                            command(['nmcli', 'connection', 'down', cname], check=False)


def connect_wifi(value):
    if not shutil.which('nmcli'):
        raise ConfigError('NetworkManager (nmcli) is required to connect to Wi-Fi')
    try:
        payload = json.loads(value) if isinstance(value, str) else value
        if not isinstance(payload, dict):
            raise ValueError
    except Exception as exc:
        raise ConfigError('Invalid Wi-Fi connect JSON payload') from exc

    ssid = payload.get('ssid')
    if not ssid or not isinstance(ssid, str):
        raise ConfigError('SSID is required')
    if ssid.startswith('-') or any(c in ssid for c in ('\x00', '\r', '\n')):
        raise ConfigError('Invalid characters in SSID')
    password = payload.get('password', '')
    identity = payload.get('identity')
    hidden = payload.get('hidden', False)

    if identity:
        chk = command(['nmcli', '-t', '-f', 'NAME', 'connection', 'show'], check=False)
        existing = [l.strip() for l in chk.stdout.splitlines() if l.strip()]
        if ssid in existing:
            command(['nmcli', 'connection', 'modify', ssid,
                     '802-1x.eap', 'peap',
                     '802-1x.phase2-auth', 'mschapv2',
                     '802-1x.identity', str(identity),
                     '802-1x.password', str(password)])
        else:
            args = ['nmcli', 'connection', 'add', 'type', 'wifi',
                    'con-name', ssid, 'ssid', ssid,
                    'wifi-sec.key-mgmt', 'wpa-eap',
                    '802-1x.eap', 'peap',
                    '802-1x.phase2-auth', 'mschapv2',
                    '802-1x.identity', str(identity),
                    '802-1x.password', str(password)]
            command(args)
        command(['nmcli', 'connection', 'up', ssid])
        return {'success': True, 'ssid': ssid}

    args = ['nmcli', 'device', 'wifi', 'connect', ssid]
    if password:
        args += ['password', str(password)]
    if hidden:
        args += ['hidden', 'yes']
    command(args)
    return {'success': True, 'ssid': ssid}


def status(paths):
    device, hw_brightness = backlight_device()
    dnd = command(['makoctl', 'mode'], check=False) if shutil.which('makoctl') else None
    preference = paths.state / 'desktop.json'
    saved = read_object(preference) if preference.exists() else {}
    has_hw = bool(device and shutil.which('brightnessctl'))
    sw_brightness = saved.get('softwareBrightness', saved.get('brightness', 100))
    brightness = hw_brightness if has_hw else sw_brightness
    return {
        'brightnessAvailable': True,
        'brightnessType': 'hardware' if has_hw else 'software',
        'brightness': brightness,
        'dndAvailable': bool(dnd and dnd.returncode == 0),
        'dnd': bool(dnd and 'do-not-disturb' in dnd.stdout.split()),
        'nightLightAvailable': bool(shutil.which('hyprsunset')),
        'nightLight': bool(saved.get('nightLight', False)),
        **power_status(command),
        **radio_status(),
        **hotspot_status(paths),
        'airplaneManaged': (paths.state / 'airplane-restore.json').exists(),
        'caffeineAvailable': True,
        'caffeine': (paths.state / 'caffeine.active').exists(),
        'gameMode': (paths.state / 'gamemode.active').exists(),
        'phoneAvailable': bool(shutil.which('kdeconnect-cli')),
        'locale': read_object(paths.config / 'settings.json').get('locale', 'en') if (paths.config / 'settings.json').exists() else 'en',
    }


def set_night_light(paths, enabled):
    if not shutil.which('hyprsunset'):
        raise ConfigError('Night Light requires hyprsunset')
    # The process starts with identity colors. Its IPC can then change temperature.
    alive = command(['pgrep', '-u', str(os.getuid()), '-x', 'hyprsunset'], check=False)
    if alive.returncode:
        paths.state.mkdir(parents=True, exist_ok=True)
        with (paths.state / 'hyprsunset.log').open('a') as log:
            subprocess.Popen(['hyprsunset', '--identity'], stdout=log, stderr=log, start_new_session=True)
        for _ in range(25):
            response = command(['hyprctl', 'hyprsunset', 'profile'], check=False)
            if response.returncode == 0 and 'error' not in response.stdout.lower():
                break
            time.sleep(.05)
    args = ['hyprctl', 'hyprsunset', 'temperature', '4500'] if enabled else ['hyprctl', 'hyprsunset', 'identity']
    response = command(args)
    if any(word in response.stdout.lower() for word in ('error', 'not found', "couldn't")):
        raise ConfigError(response.stdout.strip())
    atomic_json(paths.state / 'desktop.json', {'nightLight': enabled})



def set_caffeine(paths, enabled):
    active_marker = paths.state / 'caffeine.active'
    pid_file = paths.state / 'caffeine.pid'
    paths.state.mkdir(parents=True, exist_ok=True)
    if enabled:
        if not active_marker.exists():
            active_marker.touch()
        if shutil.which('systemd-inhibit'):
            try:
                proc = subprocess.Popen(
                    ['systemd-inhibit', '--what=idle:sleep', '--who=ALPORA', '--why=Caffeine active', 'sleep', 'infinity'],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True
                )
                pid_file.write_text(str(proc.pid))
            except Exception:
                pass
    else:
        if active_marker.exists():
            try:
                active_marker.unlink()
            except OSError:
                pass
        if pid_file.exists():
            try:
                pid = int(pid_file.read_text().strip())
                os.kill(pid, 15)
            except Exception:
                pass
            try:
                pid_file.unlink()
            except OSError:
                pass

def restore_desktop(paths):
    """Reapply our saved Night Light preference when the shell starts."""
    preference = paths.state / 'desktop.json'
    if preference.exists() and read_object(preference).get('nightLight') is True:
        with state_lock(paths):
            set_night_light(paths, True)


VALID_CONTROL_ACTIONS = {
    'status': 'status',
    'brightness': 'brightness',
    'bluetooth': 'bluetooth',
    'dnd': 'dnd',
    'nightlight': 'nightlight',
    'power-profile': 'power-profile',
    'airplane': 'airplane',
    'hotspot': 'hotspot',
    'wifi-connect': 'wifi-connect',
    'ui-scale': 'ui-scale',
    'touchpad': 'touchpad',
    'font': 'font',
    'caffeine': 'caffeine',
    'gamemode': 'gamemode',
    'phone': 'phone',
    'locale': 'locale'
}


def control(paths, action, value=None):
    safe_action = VALID_CONTROL_ACTIONS.get(str(action))
    if not safe_action:
        raise ConfigError(f'Unknown or unsupported control action: {action}')
    if safe_action == 'status':
        return status(paths)
    if safe_action == 'brightness':
        try:
            percentage = int(value)
        except (ValueError, TypeError) as exc:
            raise ConfigError('Brightness must be an integer') from exc
        if not 5 <= percentage <= 100:
            raise ConfigError('Brightness must be between 5 and 100')
        device, _ = backlight_device()
        if not device:
            raise ConfigError('No controllable display backlight found')
        clean_device = re.sub(r'[^a-zA-Z0-9_-]', '', str(device))
        if not clean_device or clean_device.startswith('-'):
            raise ConfigError('Invalid backlight device')
        command(['brightnessctl', '-d', clean_device, 'set', f'{percentage}%'])
        preference = paths.state / 'desktop.json'
        saved = read_object(preference) if preference.exists() else {}
        saved['softwareBrightness'] = percentage
        saved['brightness'] = percentage
        atomic_json(preference, saved)
        try:
            from .indicators import show_indicator
            show_indicator('brightness')
        except Exception:
            pass
        return {'success': True, 'brightness': percentage}
    elif safe_action == 'bluetooth':
        if value not in ('on', 'off'):
            raise ConfigError('Bluetooth state must be on or off')
        safe_val = 'on' if value == 'on' else 'off'
        if safe_val == 'on':
            command(['rfkill', 'unblock', 'bluetooth'])
        command(['bluetoothctl', '--timeout', '3', 'power', safe_val])
        if safe_val == 'off':
            command(['rfkill', 'block', 'bluetooth'])
    elif safe_action == 'dnd':
        command(['makoctl', 'mode', '-t', 'do-not-disturb'])
    elif safe_action == 'caffeine':
        with state_lock(paths):
            current = (paths.state / 'caffeine.active').exists()
            target = not current if value in (None, '', 'toggle') else (value in (True, 'true', 'on', '1'))
            set_caffeine(paths, target)
            return {'caffeine': target}
    elif safe_action == 'nightlight':
        with state_lock(paths):
            set_night_light(paths, not status(paths)['nightLight'])
    elif safe_action == 'power-profile':
        set_profile(value, command)
    elif safe_action == 'airplane':
        safe_val = 'on' if value == 'on' else 'off' if value == 'off' else None
        if not safe_val:
            raise ConfigError("Airplane mode: only 'on' and 'off' are supported")
        set_airplane(paths, safe_val, command)
    elif safe_action == 'hotspot':
        with state_lock(paths):
            set_hotspot(paths, value)
    elif safe_action == 'gamemode':
        from ..services.game_mode import GameModeService
        srv = GameModeService(paths)
        if value in ('on', 'true', '1'):
            srv.enable()
        elif value in ('off', 'false', '0'):
            srv.disable()
        else:
            srv.toggle()
        return {'gameMode': srv.get_state().enabled}
    elif safe_action == 'phone':
        from ..services.phone_service import PhoneService
        psrv = PhoneService(paths)
        if value == 'ring':
            return {'ring': psrv.ring_device()}
        elif value == 'ping':
            return {'ping': psrv.send_ping()}
        elif value == 'clip':
            return {'clip': psrv.share_clipboard()}
        return {'available': psrv.health_check(), 'devices': [d.to_dict() for d in psrv.get_devices()]}
    elif safe_action == 'wifi-connect':
        return connect_wifi(value)
    elif action == 'ui-scale':
        try:
            scale = round(float(value), 2)
        except (ValueError, TypeError) as exc:
            raise ConfigError('Scale must be a number') from exc
        if not 0.5 <= scale <= 3.0:
            raise ConfigError('Scale must be between 0.5 and 3.0')
        with state_lock(paths):
            data = settings_for(paths)
            data.setdefault('bar', {})['uiScale'] = scale
            atomic_json(paths.config / 'settings.json', data)
        update_session(paths)
    elif safe_action == 'touchpad':
        try:
            payload = json.loads(value) if isinstance(value, str) else dict(value)
        except Exception as exc:
            raise ConfigError('Touchpad config must be valid JSON') from exc
        with state_lock(paths):
            data = settings_for(paths)
            data.setdefault('input', {}).setdefault('touchpad', {}).update(payload)
            atomic_json(paths.config / 'settings.json', data)
        try:
            for k, v in payload.items():
                if k == 'tapToClick':
                    command(['hyprctl', 'keyword', 'input:touchpad:tap-to-click', '1' if v else '0'], check=False)
                elif k == 'naturalScroll':
                    command(['hyprctl', 'keyword', 'input:touchpad:natural_scroll', '1' if v else '0'], check=False)
                elif k == 'disableWhileTyping':
                    command(['hyprctl', 'keyword', 'input:touchpad:disable_while_typing', '1' if v else '0'], check=False)
                elif k == 'sensitivity':
                    val = max(-1.0, min(1.0, float(v)))
                    command(['hyprctl', 'keyword', 'input:sensitivity', f"{val:.2f}"], check=False)
                elif k == 'scrollFactor':
                    val = max(0.1, min(10.0, float(v)))
                    command(['hyprctl', 'keyword', 'input:touchpad:scroll_factor', f"{val:.2f}"], check=False)
        except Exception:
            pass
        update_session(paths)
    elif safe_action == 'font':
        font_name = str(value).strip()
        if not font_name:
            raise ConfigError('Font name cannot be empty')
        with state_lock(paths):
            data = settings_for(paths)
            data.setdefault('bar', {})['fontFamily'] = font_name
            atomic_json(paths.config / 'settings.json', data)
        update_session(paths)
    elif safe_action == 'locale':
        from ..core.i18n import supported_locales
        new_locale = str(value).strip().lower()
        if new_locale not in supported_locales():
            raise ConfigError(f'Unsupported locale: {new_locale}. Supported: {supported_locales()}')
        with state_lock(paths):
            data = settings_for(paths)
            data['locale'] = new_locale
            atomic_json(paths.config / 'settings.json', data)
        update_session(paths)
    else:
        raise ConfigError('Unsupported desktop action')
    return status(paths)


def wallpaper(paths, image=None, *, reset=False):
    with state_lock(paths):
        return _wallpaper(paths, image, reset=reset)


def validate_transition(value):
    if value is None:
        return None
    if value == 'fade' or (isinstance(value, dict) and value.get('type') == 'fade'):
        return {'type': 'fade'}
    if not isinstance(value, dict) or set(value) != {'x', 'y'}:
        raise ConfigError('Invalid wallpaper origin point')
    for coordinate in value.values():
        if type(coordinate) not in (int, float) or not math.isfinite(coordinate) or not 0 <= coordinate <= 1:
            raise ConfigError('Wallpaper origin point must be inside screen')
    return value


def _animated_wallpaper(paths, image, saved, transition, seed=None):
    def executable(name):
        local = Path.home() / '.local/bin' / name
        return shutil.which(name) or (str(local) if local.is_file() else None)
    client = executable('awww') or executable('swww')
    daemon = executable('awww-daemon') or executable('swww-daemon')
    if not client or not daemon:
        raise ConfigError('awww (or swww) required for wallpaper animation')
    def send(image_path, origin=None):
        transition_type = 'none'
        if origin:
            if isinstance(origin, dict) and origin.get('type') == 'fade':
                transition_type = 'fade'
            elif isinstance(origin, dict) and 'x' in origin:
                transition_type = 'grow'
        args = [client, 'img', str(image_path), '--resize', 'crop',
                '--transition-type', transition_type]
        if transition_type == 'grow':
            # Explicit decimals distinguish relative coordinates from pixel values.
            args += ['--transition-pos', f"{origin['x']:.6f},{origin['y']:.6f}", '--invert-y',
                     '--transition-duration', '1.4', '--transition-fps', '60',
                     '--transition-bezier', '0.22,0.8,0.22,1']
        elif transition_type == 'fade':
            args += ['--transition-duration', '0.25', '--transition-fps', '60']
        command(args)
    started = False
    if command([client, 'query'], check=False).returncode:
        launch = ['systemd-run', '--user', '--quiet', '--collect',
                  '--unit=poly-shell-animated-wallpaper', '--service-type=exec']
        for name in ('WAYLAND_DISPLAY', 'DISPLAY', 'XDG_RUNTIME_DIR'):
            if os.environ.get(name):
                launch.append('--setenv=' + name + '=' + os.environ[name])
        command(launch + [daemon, '--no-cache'])
        started = True
        for _ in range(40):
            if not command([client, 'query'], check=False).returncode:
                break
            time.sleep(.05)
        else:
            command(['systemctl', '--user', 'stop', 'poly-shell-animated-wallpaper'], check=False)
            raise ConfigError('Failed to start wallpaper animation')
    old_image = seed or saved.get('image')
    uid_str = str(os.getuid()) if hasattr(os, 'getuid') else '1000'
    previous = command(['pgrep', '-u', uid_str, '-x', 'swaybg'], check=False)
    try:
        if (started or seed is not None) and old_image and Path(old_image).is_file():
            send(old_image)
        send(image, transition)
        atomic_json(paths.config / 'wallpaper.json', {'image': str(image), 'renderer': 'animated'})
    except Exception:
        if started:
            command(['systemctl', '--user', 'stop', 'poly-shell-animated-wallpaper'], check=False)
        elif old_image and Path(old_image).is_file():
            send(old_image)
        raise
    for value in previous.stdout.split():
        try:
            os.kill(int(value), signal.SIGTERM)
        except ProcessLookupError:
            pass


def _wallpaper(paths, image=None, *, reset=False, quiet=False, transition=None, seed=None):
    transition = validate_transition(transition)
    preference = paths.config / 'wallpaper.json'
    previous_saved = read_object(preference) if preference.exists() else {}
    saved = read_object(preference) if preference.exists() and not reset and image is None else {}
    image = Path(image or saved.get('image') or ROOT / 'assets/wallpapers/alpine-dawn.png').expanduser().resolve()
    if image.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp') or not image.is_file():
        raise ConfigError('Select an existing PNG, JPG, or WebP image')
    if not image.exists():
        raise ConfigError(f'Wallpaper is missing: {image}')
    if transition is not None or previous_saved.get('renderer') == 'animated':
        from ..core.state import settings_for
        if settings_for(paths).get('reducedMotion'):
            transition = None
        try:
            _animated_wallpaper(paths, image, previous_saved, transition, seed)
            return
        except ConfigError:
            # Fallback to static wallpaper when animated renderer (awww/swww) is not available
            pass
    uid_str = str(os.getuid()) if hasattr(os, 'getuid') else '1000'
    previous = command(['pgrep', '-u', uid_str, '-x', 'swaybg'], check=False)
    # A detached child still belongs to the settings service's cgroup. Give the
    # renderer its own user unit so closing/restarting settings cannot kill it.
    unit = 'poly-shell-wallpaper-' + uuid.uuid4().hex
    launch = ['systemd-run', '--user', '--quiet', '--collect',
              '--unit=' + unit, '--service-type=exec',
              '--description=Poly Shell Wallpaper']
    for name in ('WAYLAND_DISPLAY', 'DISPLAY', 'XDG_RUNTIME_DIR'):
        if os.environ.get(name):
            launch.append('--setenv=' + name + '=' + os.environ[name])
    launch += ['swaybg', '-i', str(image), '-m', 'fill']
    command(launch)
    try:
        time.sleep(.25)
        active = command(['systemctl', '--user', 'is-active', '--quiet', unit], check=False)
        if active.returncode:
            raise ConfigError('Failed to start wallpaper; previous background preserved. '
                              'Details: journalctl --user -u ' + unit)
        atomic_json(preference, {'image': str(image)})
    except Exception:
        command(['systemctl', '--user', 'stop', unit], check=False)
        raise
    for value in previous.stdout.split():
        try:
            os.kill(int(value), signal.SIGTERM)
        except ProcessLookupError:
            pass
    if not quiet: print(f'Static wallpaper: {image}')
