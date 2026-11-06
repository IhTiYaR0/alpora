"""Read-only, dependency-free ALPORA system card with a faceted mountain mark."""
import argparse
import os
from pathlib import Path
import platform
import pwd
import re
import select
import shutil
import signal
import sys
import termios
import time
import tty
import unicodedata

from ..core.state import ConfigError, Paths
from ..theming.themes import load_theme, resolve_appearance, validate_palette


def clean(value):
    """System/config strings must never inject terminal control sequences."""
    return ''.join(c for c in str(value) if not unicodedata.category(c).startswith('C'))


def cells(value):
    return sum(2 if unicodedata.east_asian_width(c) in ('W', 'F') else 1
               for c in value if not unicodedata.combining(c))


def fit(value, width):
    result = ''
    for char in clean(value):
        if cells(result + char) > width:
            break
        result += char
    return result + ' ' * (width - cells(result))


def system_rows(theme):
    try:
        os_name = platform.freedesktop_os_release().get('PRETTY_NAME', 'Linux')
    except OSError:
        os_name = 'Linux'
    try:
        mem = dict(re.findall(r'^(\w+):\s+(\d+)', Path('/proc/meminfo').read_text(), re.M))
        total = int(mem['MemTotal'])
        used = total - int(mem['MemAvailable'])
        memory = f'{used / 1048576:.1f} / {total / 1048576:.1f} GiB'
    except (OSError, KeyError, ValueError):
        memory = 'unavailable'
    try:
        minutes = int(float(Path('/proc/uptime').read_text().split()[0]) // 60)
        uptime = f'{minutes // 60}h {minutes % 60:02d}m'
    except (OSError, ValueError, IndexError):
        uptime = 'unavailable'
    desktop = os.environ.get('XDG_CURRENT_DESKTOP') or ('Hyprland' if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE') else 'unavailable')
    try:
        shell = Path(pwd.getpwuid(os.getuid()).pw_shell).name
    except KeyError:
        shell = Path(os.environ.get('SHELL', 'unknown')).name
    return [('OS', os_name), ('Kernel', platform.release()),
            ('Desktop', desktop), ('Shell', shell),
            ('Terminal', os.environ.get('TERM', 'unknown')),
            ('Theme', theme), ('Memory', memory), ('Uptime', uptime)]


def inside(x, y, triangle):
    signs = []
    for a, b in zip(triangle, triangle[1:] + triangle[:1]):
        signs.append((x - b[0]) * (a[1] - b[1]) - (a[0] - b[0]) * (y - b[1]))
    return not (min(signs) < 0 < max(signs))


def mountain(palette):
    """30x30 pixels, two vertical samples per terminal cell; no image protocol."""
    peak, left, right, ridge, split = (14, 2), (0, 27), (29, 27), (17, 16), (10, 16)
    facets = [(palette['cool'], [left, peak, split]),
              (palette['text'], [peak, split, ridge]),
              (palette['accent'], [left, split, (11, 27)]),
              (palette['accent'], [split, ridge, (11, 27)]),
              (palette['border'], [(11, 27), ridge, (20, 27)]),
              (palette['cool'], [peak, right, ridge]),
              (palette['surface'], [ridge, right, (20, 27)])]
    pixels = []
    for y in range(30):
        row = []
        for x in range(30):
            colour = palette['secondary'] if (x - 25)**2 + (y - 5)**2 <= 6 else None
            for fill, triangle in facets:
                if inside(x, y, triangle):
                    colour = fill
            row.append(colour)
        pixels.append(row)
    return pixels


def render(theme, palette, colour=True, width=88):
    reset = '\033[0m' if colour else ''
    def ink(role, bg=False):
        if not colour:
            return ''
        value = palette[role] if role in palette else role
        rgb = ';'.join(str(int(value[i:i+2], 16)) for i in (1, 3, 5))
        return f'\033[{48 if bg else 38};2;{rgb}m'
    def text(value, role='text'):
        return ink(role) + value + reset
    logo = []
    pixels = mountain(palette)
    for y in range(0, 30, 2):
        line = ''
        for x in range(30):
            top, bottom = pixels[y][x], pixels[y+1][x]
            if not colour:
                line += '#' if top or bottom else ' '
            elif top and bottom:
                line += ink(top) + ink(bottom, True) + '▀' + reset
            elif top:
                line += ink(top) + '▀' + reset
            elif bottom:
                line += ink(bottom) + '▄' + reset
            else:
                line += ' '
        logo.append(line)
    # 40 cells wide, including borders; values stay bounded even on custom themes.
    edge = lambda s: text(s, 'border')
    panel = [edge('╭' + '─' * 38 + '╮'),
             edge('│') + text(fit('  A L P O R A', 38), 'accent') + edge('│'),
             edge('│') + text(fit('  A different view.', 38), 'muted') + edge('│'),
             edge('├' + '─' * 38 + '┤')]
    for key, value in system_rows(theme):
        panel.append(edge('│') + '  ' + text(fit(key, 9), 'secondary') + text(fit(value, 26)) + ' ' + edge('│'))
    swatches = ''.join(ink(role, True) + '   ' + reset for role in ('surface', 'border', 'cool', 'accent', 'secondary', 'text')) if colour else fit('LANDSCAPES / COLOUR / MOTION', 36)
    panel += [edge('│') + ' ' * 38 + edge('│'),
              edge('│') + '  ' + swatches + ' ' * (18 if colour else 0) + edge('│'),
              edge('╰' + '─' * 38 + '╯')]
    if width >= 78:
        lines = ['  ' + left + '    ' + right for left, right in zip(logo, panel)]
        lines.append('  ' + text('       A L P O R A', 'accent'))
    else:
        lines = ['  ' + line for line in logo]
        lines += ['  ' + text('       A L P O R A', 'accent'), '']
        lines += ['  ' + line for line in panel]
    return '\n' + '\n'.join(lines) + '\n\n'


def card_appearance(paths, theme=None):
    doc = load_theme(paths, theme) if theme else resolve_appearance(paths)
    palette = validate_palette(doc.get('palette') or doc['themePalette'])
    label = doc.get('label', doc.get('id', 'Custom'))
    if not theme:
        label = doc.get('id', label).replace('-', ' ').title()
    return clean(label), palette


def watch(paths, theme, colour):
    """Follow the effective theme in the foreground; restore the terminal on exit."""
    fd = sys.stdin.fileno()
    saved_terminal = termios.tcgetattr(fd)
    previous_signal = signal.getsignal(signal.SIGTERM)
    def stop(_signal, _frame):
        raise KeyboardInterrupt
    try:
        signal.signal(signal.SIGTERM, stop)
        tty.setcbreak(fd)
        sys.stdout.write('\033[?1049h\033[?25l\033[2J')
        previous = None
        refresh_at = 0
        while True:
            size = shutil.get_terminal_size((88, 24))
            label, palette = card_appearance(paths, theme)
            current = (label, palette, size)
            now = time.monotonic()
            if current != previous or now >= refresh_at:
                frame = render(label, palette, colour, size.columns)
                # Clear only line tails and the unused remainder. No repeated
                # terminal clears, scrollback growth or animation between palettes.
                frame = '\033[K\n'.join(frame.split('\n'))
                sys.stdout.write('\033[H' + frame + '\033[J')
                sys.stdout.flush()
                previous = current
                refresh_at = now + 5
            readable, _, _ = select.select([fd], [], [], 0.5)
            if readable:
                key = os.read(fd, 32)
                if not key or any(c in key for c in (b'q', b'Q', b'\x1b', b'\x04')):
                    break
    except KeyboardInterrupt:
        pass
    finally:
        termios.tcsetattr(fd, termios.TCSANOW, saved_terminal)
        sys.stdout.write('\033[0m\033[?25h\033[?1049l')
        sys.stdout.flush()
        signal.signal(signal.SIGTERM, previous_signal)


def main(argv=None):
    parser = argparse.ArgumentParser(description='ALPORA system card. Read-only; no installation or background process.')
    parser.add_argument('--theme', help='Preview a named landscape instead of the active palette')
    parser.add_argument('--no-color', action='store_true', help='Print plain text')
    parser.add_argument('--once', action='store_true', help='Print once and exit instead of following theme changes')
    args = parser.parse_args(argv)
    paths = Paths.current()
    try:
        label, palette = card_appearance(paths, args.theme)
    except (ConfigError, OSError, KeyError, TypeError) as exc:
        parser.error(str(exc))
    colour = sys.stdout.isatty() and os.environ.get('TERM', '') not in ('', 'dumb', 'linux') and 'NO_COLOR' not in os.environ and not args.no_color
    interactive = sys.stdout.isatty() and sys.stdin.isatty() and os.environ.get('TERM', '') not in ('', 'dumb')
    if interactive and not args.once:
        watch(paths, args.theme, colour)
    else:
        print(render(label, palette, colour, shutil.get_terminal_size((88, 24)).columns), end='')
    return 0
