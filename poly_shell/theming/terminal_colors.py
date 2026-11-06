"""One terminal palette for saved configuration and existing emulator PTYs."""
import os
from pathlib import Path
import re
import stat


def colors(p):
    from .themes import mix, validate_palette
    p = validate_palette(p)
    # Keep ANSI error/warning roles recognizable in every wallpaper palette.
    regular = [p['background'], mix('#d18e82', p['secondary'], .18), p['accent'],
               mix('#d1b387', p['secondary'], .30), p['cool'], p['secondary'],
               mix(p['cool'], p['accent'], .30), p['text']]
    bright = [p['muted']] + [mix(color, p['text'], .20) for color in regular[1:7]] + [p['text']]
    return regular + bright


def config_files(config, p):
    ansi = colors(p)
    result = {}
    kitty = config / 'hypr/kitty.conf'
    if not kitty.exists(): kitty = config / 'kitty/kitty.conf'
    if kitty.is_symlink(): kitty = kitty.resolve()
    if kitty.exists():
        values = {'background': p['background'], 'foreground': p['text'], 'cursor': p['secondary'],
                  'cursor_text_color': p['background'], 'selection_background': p['surface'],
                  'selection_foreground': p['text'], 'url_color': p['accent'],
                  'active_tab_background': p['accent'], 'active_tab_foreground': p['background'],
                  'inactive_tab_background': p['surface'], 'inactive_tab_foreground': p['muted'],
                  'tab_bar_background': p['background']}
        values.update({'color'+str(i): color for i, color in enumerate(ansi)})
        text = kitty.read_text()
        # Append after includes so a previously included theme cannot override it.
        for key in values:
            text = re.sub(r'(?m)^'+re.escape(key)+r'\s+[^\n]*(?:\n|$)', '', text)
        result[kitty] = text.rstrip()+'\n'+''.join(key+' '+value+'\n' for key, value in values.items())
    foot = config / 'foot/foot.ini'
    if foot.is_symlink(): foot = foot.resolve()
    if foot.exists():
        from .themes import ini_settings
        values = {'background': p['background'][1:], 'foreground': p['text'][1:],
                  'selection-background': p['surface'][1:], 'selection-foreground': p['text'][1:],
                  'cursor': p['background'][1:]+' '+p['secondary'][1:]}
        values.update({('regular' if i < 8 else 'bright')+str(i % 8): color[1:]
                       for i, color in enumerate(ansi)})
        text = foot.read_text()
        sections = re.findall(r'(?m)^\[(colors(?:-dark|-light)?)\]\s*$', text)
        for section in sections or ['colors-dark']:
            # Reuse the section-preserving INI editor without touching alpha/font.
            text = ini_settings(text, values, section)
        result[foot] = text
    return result


def sequences(p):
    ansi = colors(p)
    pairs = [(4, str(i)+';'+color) for i, color in enumerate(ansi)]
    pairs += [(10, p['text']), (11, p['background']), (12, p['secondary']),
              (17, p['surface']), (19, p['text'])]
    return ''.join('\x1b]'+str(code)+';'+value+'\x1b\\' for code, value in pairs).encode('ascii')


def terminal_ptys(proc=Path('/proc')):
    """Discover only PTY masters held by this user's supported emulators."""
    found = set()
    current_uid = os.getuid() if hasattr(os, "getuid") else None
    for process in proc.iterdir():
        if not process.name.isdigit(): continue
        try:
            stat_info = process.stat()
            if current_uid is not None and getattr(stat_info, "st_uid", None) != current_uid: continue
            if (process / 'comm').read_text(encoding="utf-8").strip() not in ('foot', 'foot-server', 'kitty'): continue
            for info in (process / 'fdinfo').iterdir():
                match = re.search(r'(?m)^tty-index:\s*(\d+)\s*$', info.read_text(encoding="utf-8"))
                if match: found.add(Path('/dev/pts') / match[1])
        except (OSError, ValueError):
            continue  # Processes may exit during discovery.
    return sorted(found)


def refresh(p):
    payload = sequences(p)
    failed = []
    current_uid = os.getuid() if hasattr(os, "getuid") else None
    for terminal in terminal_ptys():
        try:
            fd = os.open(terminal, os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK | os.O_NOFOLLOW)
            try:
                info = os.fstat(fd)
                if current_uid is not None and getattr(info, "st_uid", None) != current_uid: continue
                if not stat.S_ISCHR(info.st_mode): continue
                if os.write(fd, payload) != len(payload): failed.append(str(terminal))
            finally:
                os.close(fd)
        except OSError:
            failed.append(str(terminal))
    return failed
