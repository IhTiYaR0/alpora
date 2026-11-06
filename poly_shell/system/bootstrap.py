"""Arch session setup with explicit config replacement, backups and no live reload."""
import argparse
from datetime import datetime
import os
from pathlib import Path
import shutil
import subprocess
import sys

from ..core.state import ROOT, Paths, ConfigError, atomic_json, update_session
from ..theming.appearance import atomic_text, install_hook
from .integration import install
from ..theming import desktop_assets
from .installer_ui import InstallerUI

MARKER = '-- ALPORA managed session v1'
MAIN = '''-- ALPORA managed session v1
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
dofile(config .. "/hypr/alpora-session.lua")
'''


def seed_reference_preferences(paths):
    """Install reviewed public appearance only; never copy personal state."""
    from ..core.state import read_object
    from ..theming.visual import validate as validate_visual
    from .widgets import validate as validate_widgets
    preset=read_object(ROOT/'assets/profiles/desktop.json')
    if preset.get('version')!=1: raise ConfigError('Unsupported desktop preset')
    validate_visual(preset['visual']['values'])
    validate_widgets(preset['widgets']['values'])
    values={paths.config/(name+'.json'):preset[name] for name in
            ('settings','visual','widgets','companion','landscape')}
    created=[]
    try:
        for path,value in values.items():
            if path.exists() or path.is_symlink(): continue
            atomic_json(path,value);created.append(path)
    except Exception:
        for path in created:path.unlink(missing_ok=True)
        raise
    return [str(path) for path in created]


def verify_prepared_desktop(paths):
    """Check the actual next-login files, without touching the running session."""
    from ..core.state import read_object
    from ..theming.visual import visual_for
    from .widgets import values_for
    snapshot=read_object(paths.session)
    visual_for(paths);values_for(paths)
    expected=[paths.config.parent/'hypr'/name for name in
              ('hyprland.lua','alpora-session.lua','alpora-overview.lua','hyprlock.conf',
               'alpora-hypridle.conf','poly-shell-appearance.lua','screenshot.sh')]
    expected += [paths.state/'mako-theme.conf',paths.state/'hyprlock-theme.conf']
    expected += [Path.home()/'.local/bin'/name for name in ('poly-shell','alpora-fetch')]
    expected += [paths.config.parent/'systemd/user/poly-shell.service',
                 paths.config.parent/'quickshell/poly-shell/shell.qml',
                 ROOT/'poly_shell/system/fetch.py']
    for path in expected:
        if not path.is_file() or not path.stat().st_size: raise ConfigError('Incomplete installation: '+str(path))
    wallpaper=Path(read_object(paths.config/'wallpaper.json')['image'])
    if not wallpaper.is_file():raise ConfigError('Prepared wallpaper missing')
    return {'theme':snapshot['appearance']['id'],'mode':snapshot['mode'],'checks':len(expected)+3}


def configuration_plan(paths, replace=False):
    root=paths.config.parent/'hypr'
    if root.is_symlink(): raise ConfigError('Preserving symlinked Hyprland directory; install in a regular configuration directory')
    files={root/'hyprland.lua':MAIN,
           root/'alpora-session.lua':(ROOT/'dotfiles/hypr/.config/hypr/alpora-session.lua').read_text(),
           root/'alpora-hypridle.conf':(ROOT/'dotfiles/hypr/.config/hypr/alpora-hypridle.conf').read_text(),
           root/'alpora-overview.lua':(ROOT/'dotfiles/hypr/.config/hypr/hyprland-overview.lua').read_text(),
           root/'screenshot.sh':(ROOT/'scripts/screenshot.sh').read_text()}
    lock=root/'hyprlock.conf'
    # The palette sync creates this generated file before the next login.
    # Keep an existing personal lock config unless replacing the whole session.
    if not lock.exists() or replace:
        for path in (paths.state, ROOT):
            if any(c in str(path) for c in '\n\r\0$#'):
                raise ConfigError('Unsupported special character in lockscreen path')
        files[lock]=('# ALPORA managed lockscreen\nsource = '+(paths.state/'hyprlock-theme.conf').as_posix()+
                     '\nsource = '+(ROOT/'assets/lockscreen/layout.conf').as_posix()+'\n')
    main=root/'hyprland.lua';legacy=root/'hyprland.conf'
    for path in (main,legacy):
        if path.exists() and not replace:
            text=path.read_text(encoding="utf-8")
            if not text.startswith(MARKER):
                raise ConfigError('Existing Hyprland config requires explicit consent: '+str(path))
    if not replace:
        for path,text in files.items():
            if path.exists() and path.name not in ('hyprland.lua','hyprlock.conf') and path.read_text(encoding="utf-8")!=text:
                raise ConfigError('Preserving modified session file: '+str(path))
    # Do not silently discard manually added settings in an already installed main.
    if main.exists() and main.read_text(encoding="utf-8").startswith(MARKER) and not replace:
        files[main]=main.read_text(encoding="utf-8")
    return files


def backup_session(paths):
    root=paths.config.parent/'hypr'
    if root.is_symlink():raise ConfigError('Preserving symlinked Hyprland directory')
    backup=paths.state/'backups'/('arch-install-'+datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    if root.exists():
        shutil.copytree(root,backup/'hypr',symlinks=True)
    else:backup.mkdir(parents=True)
    atomic_json(backup/'manifest.json',{'config':str(root),'backup':str(backup/'hypr')})
    return backup


def configure(paths, replace=False, backup=None):
    files=configuration_plan(paths,replace)
    root=paths.config.parent/'hypr'
    backup=backup or backup_session(paths)
    old={path:(path.read_bytes() if path.exists() else None) for path in files}
    legacy=root/'hyprland.conf';legacy_old=legacy.read_bytes() if legacy.exists() else None
    try:
        # Replace symlinks themselves, never edit their external target.
        for path,text in files.items():atomic_text(path,text)
        (root/'screenshot.sh').chmod(0o755)
        # Lua is the installed entry point; legacy config remains in the backup.
        if replace and legacy.exists():legacy.unlink()
        install_hook(paths)
        atomic_json(paths.state/'arch-install.json',{'version':1,'backup':str(backup),'configured':True})
    except Exception:
        # Preserve symlink identities using the full directory backup on failure.
        if (backup/'hypr').exists():
            if root.exists():shutil.rmtree(root)
            shutil.copytree(backup/'hypr',root,symlinks=True)
        else:
            for path,content in old.items():
                if content is None:path.unlink(missing_ok=True)
                else:atomic_text(path,content.decode())
            if legacy_old is not None:legacy.write_bytes(legacy_old)
        raise
    return {'backup':str(backup),'config':str(root/'hyprland.lua')}


def enable_services():
    results=[]
    for unit in ('NetworkManager.service','bluetooth.service'):
        active=subprocess.run(['systemctl','is-active','--quiet',unit],capture_output=True).returncode==0
        enabled=subprocess.run(['systemctl','is-enabled','--quiet',unit],capture_output=True).returncode==0
        if not active:
            subprocess.run(['sudo','systemctl','enable','--now',unit],check=True)
        elif not enabled:
            # An active unit can have been started manually just for this boot.
            # Enable it without restarting a user's current connection.
            subprocess.run(['sudo','systemctl','enable',unit],check=True)
        results.append(unit)
    # Do not replace an existing power-management policy such as TLP.
    tlp=subprocess.run(['systemctl','is-enabled','--quiet','tlp.service'],capture_output=True).returncode==0
    if not tlp:
        subprocess.run(['sudo','systemctl','enable','--now','power-profiles-daemon.service'],check=True)
    for unit in ('pipewire.socket','pipewire-pulse.socket','wireplumber.service'):
        subprocess.run(['systemctl','--user','enable','--now',unit],check=True)
    subprocess.run(['systemctl','--user','daemon-reload'],check=True)
    return results


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--replace-config',action='store_true')
    parser.add_argument('--ui-only',action='store_true',help='Install standalone UI shell only without modifying Hyprland session configs')
    parser.add_argument('--print-packages',action='store_true',help='Print required package list')
    parser.add_argument('--optional',action='store_true',help='Print optional packages instead')
    from ..theming.themes import IDS
    parser.add_argument('--theme',choices=IDS)
    args=parser.parse_args(argv)
    if args.print_packages:
        from .programs import PROGRAMS
        seen = set()
        for _, pkg, _, _, req in PROGRAMS:
            if ((not args.optional and req) or (args.optional and not req)) and pkg not in seen:
                print(pkg)
                seen.add(pkg)
        return 0
    paths=Paths.current()
    ui=InstallerUI()
    try:
        from ..cli import runtime_check
        runtime_check()
        if args.ui_only:
            if not shutil.which('quickshell'):
                ui.line('    [Notice] quickshell not detected in PATH. Install Quickshell (0.3+) to run the UI.')
        else:
            for program in ('hyprctl','gsettings','systemctl','foot','mako','hyprlock'):
                if not shutil.which(program): raise ConfigError('Required program missing: '+program)
        
        if args.ui_only:
            with ui.stage(2,'Icons & cursor · Papirus / Bibata'):
                try: desktop_assets.install(paths)
                except Exception: pass
            with ui.stage(3,'Build your ALPORA desktop UI'):
                seeded=seed_reference_preferences(paths)
                install(paths)
                ui.line('    Installed user links: ~/.local/bin/poly-shell, ~/.config/quickshell/poly-shell')
            signature=os.environ.pop('HYPRLAND_INSTANCE_SIGNATURE',None)
            try:
                with ui.stage(4,'Bring the landscape together'):
                    from ..theming.themes import catalog, apply_theme
                    selected=catalog(paths)
                    theme=args.theme or selected['selected']
                    apply_theme(paths,theme,True if args.theme else selected['colorsFromWallpaper'],activate=False)
                    try: desktop_assets.apply(paths)
                    except Exception: pass
            finally:
                if signature is not None:os.environ['HYPRLAND_INSTANCE_SIGNATURE']=signature
            ui.line('\n  ALPORA standalone UI shell is ready!')
            ui.line('  Landscape: '+str(theme))
            ui.line('  To run in your current Hyprland session:')
            ui.line('    poly-shell run')
            ui.line('  To launch automatically with your existing Hyprland config, add:')
            ui.line('    exec-once = poly-shell run')
            ui.line('  System card: ~/.local/bin/alpora-fetch · q to exit')
            if ui.log_path:ui.line('  Installation log: '+ui.log_path)
            return 0

        replace=args.replace_config
        try:configuration_plan(paths,replace)
        except ConfigError:
            if replace:raise
            if not sys.stdin.isatty():raise ConfigError('Existing configuration preserved. Use --replace-config only after reviewing the replacement.')
            print('ALPORA needs its own session configuration. Your current Hyprland directory will be backed up.')
            if input('Install the ALPORA session instead? [y/N] ').strip().lower() not in ('y','yes'):return 1
            replace=True
        # Downloads and validation happen before replacing the session config.
        with ui.stage(2,'Icons & cursor · Papirus / Bibata'):
            desktop_assets.install(paths)
        with ui.stage(3,'Preserve your session'):
            configuration_plan(paths,replace)
            backup=backup_session(paths)
            ui.line('    Backup saved: '+str(backup))
        with ui.stage(4,'Build your ALPORA desktop'):
            seeded=seed_reference_preferences(paths)
            install(paths)
            result=configure(paths,replace,backup=backup)
            ui.line('    Session backup: '+result['backup'])
        # Do not reload a running desktop: existing applications remain untouched.
        # Temporarily suppress live Hyprland IPC when preparing the next session.
        signature=os.environ.pop('HYPRLAND_INSTANCE_SIGNATURE',None)
        try:
            with ui.stage(5,'Bring the landscape together'):
                from ..theming.themes import catalog, apply_theme
                selected=catalog(paths)
                theme=args.theme or selected['selected']
                apply_theme(paths,theme,True if args.theme else selected['colorsFromWallpaper'],activate=False)
                desktop_assets.apply(paths)
        finally:
            if signature is not None:os.environ['HYPRLAND_INSTANCE_SIGNATURE']=signature
        with ui.stage(6,'Check the next login'):
            enable_services()
            verification=verify_prepared_desktop(paths)
            atomic_json(paths.state/'arch-install.json',{'version':1,'backup':result['backup'],
                        'configured':True,'referencePreset':1,'seededFiles':seeded,'verification':verification})
        ui.line('\n  ALPORA is ready for its first login.')
        ui.line('  Landscape: '+verification['theme']+' · Icons: Papirus · Cursor: Bibata Modern Ice')
        ui.line('  Reference appearance: new preferences seeded; existing preferences preserved.')
        ui.line('  Configuration backup: '+result['backup'])
        ui.line('  Log out and select Hyprland, or run Hyprland from a TTY.')
        ui.line('  Super+Return terminal · Super+I controls · Super+Tab overview')
        ui.line('  System card: ~/.local/bin/alpora-fetch · q to exit')
        if ui.log_path:ui.line('  Installation log: '+ui.log_path)
        return 0
    except (ConfigError,OSError,ValueError,subprocess.SubprocessError) as exc:
        ui.record('Installation stopped: '+str(exc))
        print('ALPORA installation stopped: '+str(exc),file=sys.stderr)
        print('Completed package/theme installations remain installed; configuration backups are under '+str(paths.state/'backups'),file=sys.stderr)
        return 1
