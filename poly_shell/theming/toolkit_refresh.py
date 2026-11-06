"""One-shot refresh for the file manager, which caches libadwaita user CSS."""
import ast
import hashlib
import re
import subprocess
import time

from ..core.state import ROOT, Paths, atomic_json, read_object, state_lock


def schedule(paths):
    if paths.config != Paths.current().config:
        return
    result = subprocess.run([
        'systemd-run', '--user', '--quiet', '--collect',
        '--unit=poly-shell-toolkit-refresh', '--on-active=2s',
        '--timer-property=AccuracySec=100ms', str(ROOT / 'bin/poly-shell'), 'toolkit-refresh',
    ], capture_output=True, timeout=4, check=False)
    if result.returncode:
        # Re-arm a pending timer so rapid palette changes cause one refresh.
        subprocess.run(['systemctl', '--user', 'restart', 'poly-shell-toolkit-refresh.timer'],
                       capture_output=True, timeout=4, check=False)


def refresh(paths):
    with state_lock(paths):
        return _refresh(paths)


def _refresh(paths):
    css = paths.config.parent / 'gtk-4.0/poly-palette.css'
    if not css.exists():
        return {'refreshed': False}
    digest = hashlib.sha256(css.read_bytes()).hexdigest()
    marker = paths.state / 'toolkit-refresh.json'
    if marker.exists() and read_object(marker).get('gtk4') == digest:
        return {'refreshed': False}
    owner = subprocess.run([
        'gdbus', 'call', '--session', '--dest', 'org.freedesktop.DBus',
        '--object-path', '/org/freedesktop/DBus', '--method',
        'org.freedesktop.DBus.NameHasOwner', 'org.gnome.Nautilus',
    ], capture_output=True, text=True, timeout=3, check=False)
    if owner.returncode or owner.stdout.strip() not in ('(true,)', '(false,)'):
        return {'refreshed': False, 'deferred': True}
    if owner.returncode == 0 and owner.stdout.strip() == '(false,)':
        atomic_json(marker, {'gtk4': digest})
        return {'refreshed': False}
    def get_property(interface, name):
        return subprocess.run([
            'gdbus', 'call', '--session', '--dest', 'org.gnome.Nautilus',
            '--object-path', '/org/gnome/Nautilus' if interface == 'org.gtk.Application' else '/org/freedesktop/FileManager1',
            '--method', 'org.freedesktop.DBus.Properties.Get', interface, name,
        ], capture_output=True, text=True, timeout=3, check=False)
    busy = get_property('org.gtk.Application', 'Busy')
    locations = []
    if busy.returncode == 0:
        # Never interrupt a copy/move operation or quit an unknown busy state.
        if busy.stdout.strip() != '(<false>,)':
            return {'refreshed': False, 'deferred': True, 'busy': busy.stdout.strip() == '(<true>,)'}
        answer = get_property('org.freedesktop.FileManager1', 'OpenLocations')
        match = re.search(r'<(\[.*\])>', answer.stdout)
        if not match:
            return {'refreshed': False, 'deferred': True}
        locations = ast.literal_eval(match[1])
        if not isinstance(locations, list) or any(not isinstance(uri, str) for uri in locations):
            return {'refreshed': False, 'deferred': True}
        if locations:
            # Nautilus may return 255 when its remote owner exits before replying.
            subprocess.run(['nautilus', '--quit'], capture_output=True, timeout=5, check=False)
            time.sleep(.3)
            subprocess.Popen(['nautilus', '--new-window', '--', *locations],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    atomic_json(marker, {'gtk4': digest})
    return {'refreshed': bool(locations), 'locations': len(locations)}
