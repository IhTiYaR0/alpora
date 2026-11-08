"""User-local installation and a reversible handover from the existing Waybar."""
import datetime
import os
from pathlib import Path
import shutil
import subprocess

from .state import ConfigError, ROOT, atomic_json, read_object

BEGIN = "# BEGIN poly-shell managed panel"
END = "# END poly-shell managed panel"


def unit_text(launcher):
    escaped = str(launcher).replace("%", "%%").replace("\\", "\\\\").replace('"', '\\"')
    return f'''[Unit]
Description=Poly Shell desktop panel
PartOf=graphical-session.target
After=graphical-session.target
StartLimitIntervalSec=30
StartLimitBurst=3

[Service]
Type=simple
Slice=session.slice
ExecStart="{escaped}" run
Restart=on-failure
RestartSec=2
TimeoutStopSec=5
KillMode=control-group
StandardOutput=journal
StandardError=journal
SyslogIdentifier=poly-shell
'''


def previous_unit_texts(launcher):
    # Units written by earlier releases are safe to replace; anything else was edited by hand.
    return (unit_text(launcher).replace("Slice=session.slice\n", "", 1),)


def install(paths):
    # Existing files with these names are never overwritten by the installer.
    links = {
        Path.home() / ".local/bin/poly-shell": ROOT / "bin/poly-shell",
        Path.home() / ".local/bin/alpora-fetch": ROOT / "bin/alpora-fetch",
        paths.config.parent / "quickshell/poly-shell": ROOT / "shell",
    }
    for target, source in links.items():
        if (target.exists() or target.is_symlink()) and target.resolve() != source.resolve():
            raise ConfigError(f"Refusing to overwrite existing {target}")
    unit = paths.config.parent / "systemd/user/poly-shell.service"
    launcher = Path.home() / ".local/bin/poly-shell"
    text = unit_text(launcher)
    if unit.exists() and unit.read_text() not in (text, *previous_unit_texts(launcher)):
        raise ConfigError(f"Existing service differs; inspect {unit} before replacing it")
    # Validate every owned target before creating even the first command link.
    settings_desktop_plan()
    for target, source in links.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.is_symlink():
            target.symlink_to(source, target_is_directory=source.is_dir())
    unit.parent.mkdir(parents=True, exist_ok=True)
    unit.write_text(text)
    install_settings_desktop()
    print(f"Installed user-local links and {unit}")


def settings_desktop_plan():
    def quote(value):
        return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"').replace("`", "\\`").replace("$", "\\$").replace("%", "%%") + '"'
    # A separate desktop ID gives the normal settings window its own icon.
    target = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "applications/poly-shell-settings.desktop"
    text = ("[Desktop Entry]\nType=Application\nName=Настройки Poly\n"
            "GenericName=Настройки рабочего стола\nComment=Внешний вид рабочего стола Poly Shell\n"
            f"Exec={quote(ROOT / 'bin/poly-shell')} settings\n"
            f"Icon={ROOT / 'assets/settings-app.svg'}\n"
            "Terminal=false\nCategories=Settings;DesktopSettings;\n"
            "Keywords=Poly;Alpine;appearance;blur;theme;настройки;оформление;\n"
            "StartupWMClass=poly-shell-settings\nStartupNotify=false\n")
    if target.exists() and target.read_text() != text:
        raise ConfigError(f"Existing settings launcher differs; preserved: {target}")
    return target, text


def install_settings_desktop():
    target, text = settings_desktop_plan()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text)


def managed_autostart(text, launcher):
    if BEGIN in text or END in text:
        if text.count(BEGIN) != 1 or text.count(END) != 1:
            raise ConfigError("Malformed managed panel block in autostart")
        return text
    lines = text.splitlines(keepends=True)
    matches = [i for i, line in enumerate(lines) if line.lstrip().startswith("waybar ")]
    if len(matches) != 1:
        raise ConfigError("Expected exactly one Waybar launch in Hyprland autostart; no changes made")
    index = matches[0]
    original = lines[index].rstrip("\n")
    import shlex
    lines[index] = (
        f"{BEGIN}\n"
        f"if ! {shlex.quote(str(launcher))} start; then\n"
        f"    {original}\n"
        f"fi\n{END}\n"
    )
    return "".join(lines)


def patch_autostart(paths):
    target = paths.config.parent / "hypr/autostart.sh"
    original = target.read_text()
    modified = managed_autostart(original, Path.home() / ".local/bin/poly-shell")
    if original == modified:
        return
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup = paths.state / "backups" / stamp / "autostart.sh"
    backup.parent.mkdir(parents=True)
    shutil.copy2(target, backup)
    # Record the exact owned block, so rollback preserves unrelated user edits.
    start = modified.index(BEGIN)
    stop = modified.index(END, start) + len(END) + 1
    original_line = next(line for line in original.splitlines(keepends=True) if line.lstrip().startswith("waybar "))
    atomic_json(paths.state / "activation.json", {
        "backup": str(backup), "block": modified[start:stop], "original": original_line,
    })
    temporary = target.with_name(".autostart.poly-shell.tmp")
    try:
        temporary.write_text(modified)
        shutil.copymode(target, temporary)
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"Autostart backup: {backup}")


def restore_autostart(paths):
    target = paths.config.parent / "hypr/autostart.sh"
    if not target.exists() or BEGIN not in target.read_text():
        return
    manifest = read_object(paths.state / "activation.json")
    text = target.read_text()
    block = manifest["block"]
    if block not in text:
        raise ConfigError("Managed autostart block was edited; inspect it and the backup before restoring")
    target.write_text(text.replace(block, manifest["original"], 1))


def fallback_panel(paths):
    check = subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "waybar"], capture_output=True)
    if check.returncode == 0:
        return
    hypr = paths.config.parent / "hypr"
    command = ["waybar"]
    if (hypr / "waybar.jsonc").exists():
        command += ["-c", str(hypr / "waybar.jsonc")]
    if (hypr / "waybar.css").exists():
        command += ["-s", str(hypr / "waybar.css")]
    paths.state.mkdir(parents=True, exist_ok=True)
    with (paths.state / "waybar-fallback.log").open("a") as stream:
        subprocess.Popen(command, stdout=stream, stderr=stream, start_new_session=True)
