"""Pinned user-local icon/cursor installation with preserved user configuration."""
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import urllib.request

from ..core.state import ROOT, ConfigError, atomic_json, state_lock
from .appearance import atomic_text

RELEASES = {
    'bibata': {
        'url': 'https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz',
        'sha256': 'a68cae60c4dc706350e194ebc91c5fe48bc7bc9d59e119555834a2a7ee5078ef',
        'directory': 'Bibata-Modern-Ice', 'themes': ['Bibata-Modern-Ice'],
        'license': 'GPL-3.0', 'upstream': 'https://github.com/ful1e5/Bibata_Cursor',
    },
    'papirus': {
        'url': 'https://api.github.com/repos/PapirusDevelopmentTeam/papirus-icon-theme/tarball/20260801',
        'sha256': '7b22c819319b971b0d3f8d99bf3fd5dfa013290d8fb20943c04f6afab826ce39',
        'directory': 'PapirusDevelopmentTeam-papirus-icon-theme-1d991e9',
        'themes': ['Papirus', 'Papirus-Dark', 'Papirus-Light'],
        'license': 'GPL-3.0', 'upstream': 'https://github.com/PapirusDevelopmentTeam/papirus-icon-theme',
    },
}
CURSOR = 'Bibata-Modern-Ice'
SIZE = 24
BEGIN = '-- BEGIN ALPORA ICONS AND CURSOR'
END = '-- END ALPORA ICONS AND CURSOR'
LUA = '''-- BEGIN ALPORA ICONS AND CURSOR
-- Bibata provides XCursor assets, including animated cursors and resize variants.
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.config({ cursor = { enable_hyprcursor = false } })
-- END ALPORA ICONS AND CURSOR
'''


def data_root():
    return Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))


def download(spec, cache):
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / spec['sha256']
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == spec['sha256']:
        return target
    request = urllib.request.Request(spec['url'], headers={'User-Agent': 'ALPORA-desktop-assets/1'})
    temporary = target.with_suffix('.part')
    try:
        with urllib.request.urlopen(request, timeout=60) as source, temporary.open('wb') as output:
            size = 0
            while chunk := source.read(1024*1024):
                size += len(chunk)
                if size > 80*1024*1024: raise ConfigError('Theme download exceeds size limit')
                output.write(chunk)
        if hashlib.sha256(temporary.read_bytes()).hexdigest() != spec['sha256']:
            raise ConfigError('Theme checksum mismatch; nothing installed')
        os.replace(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)
    return target


def unpack(archive, destination):
    with tarfile.open(archive) as stream:
        members = stream.getmembers()
        if len(members) > 160000 or sum(m.size for m in members) > 300*1024*1024:
            raise ConfigError('Theme archive exceeds extraction limit')
        # data rejects escaping paths/links, special files and unsafe permissions.
        stream.extractall(destination, members=members, filter='data')


def link_plan(store, icons):
    links = {}
    for name, spec in RELEASES.items():
        base = store / (name+'-'+spec['sha256'][:12]) / spec['directory']
        for theme in spec['themes']:
            links[icons/theme] = base if name == 'bibata' else base/theme
    for index in (ROOT/'assets/desktop-themes').glob('*/Poly-*/index.theme'):
        if index.parent.name.endswith('-Cursors'): continue
        links[icons/index.parent.name] = index.parent
    return links


def install(paths):
    data = data_root(); store = data/'alpora/desktop-assets'; icons = data/'icons'
    links = link_plan(store, icons)
    with state_lock(paths):
        # Detect all collisions before downloading or changing any links.
        for target, source in links.items():
            if (target.exists() or target.is_symlink()) and not (target.is_symlink() and target.resolve() == source.resolve()):
                raise ConfigError('Preserving existing icon theme: '+str(target))
        cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home()/'.cache'))/'alpora/downloads'
        store.mkdir(parents=True, exist_ok=True)
        for name, spec in RELEASES.items():
            destination = store/(name+'-'+spec['sha256'][:12])
            marker = destination/'alpora-source.json'
            if marker.is_file() and json.loads(marker.read_text()).get('sha256') == spec['sha256']:
                continue
            if destination.exists(): raise ConfigError('Preserving incomplete theme directory: '+str(destination))
            archive = download(spec, cache)
            with tempfile.TemporaryDirectory(dir=store, prefix='.extract-') as directory:
                unpack(archive, directory)
                stage = Path(directory)
                for theme in spec['themes']:
                    base = stage/spec['directory']
                    if name != 'bibata': base = base/theme
                    if not (base/'index.theme').is_file(): raise ConfigError('Theme index missing: '+theme)
                atomic_json(stage/'alpora-source.json', spec)
                os.replace(stage, destination)
        icons.mkdir(parents=True, exist_ok=True)
        for target, source in links.items():
            if not target.is_symlink(): target.symlink_to(source, target_is_directory=True)
    return {'installed': True, 'cursor': CURSOR, 'icons': 'Papirus-Dark', 'location': str(store)}


def settings_files(paths):
    from .themes import ini_settings
    values = {'gtk-cursor-theme-name': CURSOR, 'gtk-cursor-theme-size': str(SIZE)}
    result = {}
    for version in ('3', '4'):
        target = paths.config.parent/('gtk-'+version+'.0')/'settings.ini'
        if target.is_symlink(): target = target.resolve()
        result[target] = ini_settings(target.read_text(encoding="utf-8") if target.exists() else '', values)
    hypr = paths.config.parent/'hypr/hyprland.lua'
    if not hypr.exists(): raise ConfigError('hyprland.lua not found; install a Lua Hyprland configuration first')
    if hypr.is_symlink(): hypr = hypr.resolve()
    text = hypr.read_text(encoding="utf-8")
    if BEGIN in text or END in text:
        if text.count(BEGIN)!=1 or text.count(END)!=1 or LUA.strip() not in text:
            raise ConfigError('Preserving manually edited ALPORA cursor block')
    else: result[hypr] = text.rstrip()+'\n\n'+LUA
    return result


def apply(paths):
    if not (data_root()/'icons'/CURSOR/'cursors/left_ptr').is_file():
        raise ConfigError('Install desktop assets before applying them')
    files = settings_files(paths)
    backup = paths.state/'backups'/('desktop-assets-'+datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    old = {path: path.read_bytes() if path.exists() else None for path in files}
    previous = {}
    schema = 'org.gnome.desktop.interface'
    from ..core.state import appearance_for
    from .themes import toolkit_theme_name
    appearance = appearance_for(paths)
    preferences = [('cursor-theme', CURSOR), ('cursor-size', str(SIZE)),
                   ('icon-theme', appearance.get('iconTheme', 'Poly-Alpine')),
                   ('gtk-theme', toolkit_theme_name(appearance.get('palette') or appearance['themePalette']))]
    for key, _ in preferences:
        r = subprocess.run(['gsettings','get',schema,key],capture_output=True,text=True,timeout=5)
        if r.returncode: raise ConfigError('Unable to read cursor preference: '+key)
        previous[key] = r.stdout.strip()
    with state_lock(paths):
        for i,(path,content) in enumerate(old.items()):
            if content is not None:
                destination = backup/str(i);destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(content)
        atomic_json(backup/'manifest.json',{'files':{str(p):str(backup/str(i)) if content is not None else None for i,(p,content) in enumerate(old.items())},'gsettings':previous})
        try:
            for path,text in files.items(): atomic_text(path,text)
            for key,value in preferences:
                subprocess.run(['gsettings','set',schema,key,value],check=True,capture_output=True,text=True,timeout=5)
            if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
                reply = subprocess.run(['hyprctl','eval','\n'.join(LUA.splitlines()[2:-1])],capture_output=True,text=True,timeout=5)
                if reply.returncode or reply.stdout.strip()!='ok': raise ConfigError('Hyprland rejected cursor configuration')
                subprocess.run(['hyprctl','setcursor',CURSOR,str(SIZE)],check=True,capture_output=True,text=True,timeout=5)
        except Exception:
            for path,content in old.items():
                if content is None: path.unlink(missing_ok=True)
                else: path.write_bytes(content)
            for key,value in previous.items():
                subprocess.run(['gsettings','set',schema,key,value],capture_output=True,timeout=5)
            # Re-read the restored config to restore compositor environment/options.
            if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
                subprocess.run(['hyprctl','reload'],capture_output=True,timeout=5)
            raise
    return {'applied': True, 'cursor': CURSOR, 'size': SIZE, 'backup': str(backup)}
