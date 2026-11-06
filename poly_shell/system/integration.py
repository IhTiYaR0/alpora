"""User-local installation and a reversible handover from the existing Waybar."""
import datetime
import os
from pathlib import Path
import shutil
import subprocess

from ..core.state import ConfigError, ROOT, atomic_json, read_object

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
ExecStart="{escaped}" run
Restart=on-failure
RestartSec=2
TimeoutStopSec=5
KillMode=control-group
StandardOutput=journal
StandardError=journal
SyslogIdentifier=poly-shell
'''


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
    text = unit_text(Path.home() / ".local/bin/poly-shell")
    if unit.exists() and unit.read_text(encoding="utf-8") != text:
        raise ConfigError(f"Existing service differs; inspect {unit} before replacing it")
    # Validate every owned target before creating even the first command link.
    settings_desktop_plan()
    for target, source in links.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.is_symlink():
            target.symlink_to(source, target_is_directory=source.is_dir())
    unit.parent.mkdir(parents=True, exist_ok=True)
    unit.write_text(text, encoding="utf-8")
    install_settings_desktop()
    print(f"Installed user-local links and {unit}")


def settings_desktop_plan():
    def quote(value):
        return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"').replace("`", "\\`").replace("$", "\\$").replace("%", "%%") + '"'
    # A separate desktop ID gives the normal settings window its own icon.
    target = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "applications/poly-shell-settings.desktop"
    text = ("[Desktop Entry]\nType=Application\nName=Poly Settings\n"
            "Name[ru]=Настройки Poly\nName[vi]=Cài đặt Poly\n"
            "GenericName=Desktop Settings\nGenericName[ru]=Настройки рабочего стола\nGenericName[vi]=Cài đặt màn hình nền\n"
            "Comment=Poly Shell desktop appearance and preferences\n"
            "Comment[ru]=Внешний вид рабочего стола Poly Shell\nComment[vi]=Giao diện và tùy chọn màn hình nền Poly Shell\n"
            f"Exec={quote(ROOT / 'bin/poly-shell')} settings\n"
            f"Icon={ROOT / 'assets/settings-app.svg'}\n"
            "Terminal=false\nCategories=Settings;DesktopSettings;\n"
            "Keywords=Poly;Alpine;appearance;blur;theme;settings;\n"
            "Keywords[ru]=Poly;Alpine;appearance;blur;theme;настройки;оформление;\n"
            "Keywords[vi]=Poly;Alpine;giao diện;mờ;chủ đề;cài đặt;\n"
            "StartupWMClass=poly-shell-settings\nStartupNotify=false\n")
    if target.exists() and target.read_text(encoding="utf-8") != text:
        raise ConfigError(f"Existing settings launcher differs; preserved: {target}")
    return target, text


def install_settings_desktop():
    target, text = settings_desktop_plan()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


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
    launcher_posix = launcher.as_posix() if hasattr(launcher, "as_posix") else str(launcher)
    lines[index] = (
        f"{BEGIN}\n"
        f"if ! {shlex.quote(launcher_posix)} start; then\n"
        f"    {original}\n"
        f"fi\n{END}\n"
    )
    return "".join(lines)


def _safe_contained_path(target: Path, base: Path, error_message: str) -> Path:
    resolved_target = target.resolve()
    resolved_base = base.resolve()
    try:
        if not resolved_target.is_relative_to(resolved_base):
            raise ConfigError(error_message)
    except AttributeError:
        if not str(resolved_target).startswith(str(resolved_base)):
            raise ConfigError(error_message)
    return resolved_target


def patch_autostart(paths):
    base_hypr = (paths.config.parent / "hypr").resolve()
    target = _safe_contained_path(base_hypr / "autostart.sh", base_hypr, "Invalid autostart target path")
    original = target.read_text(encoding="utf-8")
    modified = managed_autostart(original, Path.home() / ".local/bin/poly-shell")
    if original == modified:
        return
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup = (paths.state / "backups" / stamp / "autostart.sh").resolve()
    backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(target, backup)
    # Record the exact owned block, so rollback preserves unrelated user edits.
    start = modified.index(BEGIN)
    stop = modified.index(END, start) + len(END) + 1
    original_line = next(line for line in original.splitlines(keepends=True) if line.lstrip().startswith("waybar "))
    atomic_json(paths.state / "activation.json", {
        "backup": str(backup), "block": modified[start:stop], "original": original_line,
    })
    temporary = _safe_contained_path(base_hypr / ".autostart.poly-shell.tmp", base_hypr, "Invalid temporary target path")
    try:
        with open(temporary, "w", encoding="utf-8") as stream:  # NOSONAR
            stream.write(modified)
        shutil.copymode(target, temporary)
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"Autostart backup: {backup}")


def restore_autostart(paths):
    base_hypr = (paths.config.parent / "hypr").resolve()
    target = _safe_contained_path(base_hypr / "autostart.sh", base_hypr, "Invalid autostart target path")

    if not target.exists() or BEGIN not in target.read_text(encoding="utf-8"):
        return

    state_dir = paths.state.resolve()
    manifest_file = _safe_contained_path(state_dir / "activation.json", state_dir, "Invalid manifest path")

    manifest = read_object(manifest_file)
    text = target.read_text(encoding="utf-8")
    block = manifest["block"]
    if block not in text:
        raise ConfigError("Managed autostart block was edited; inspect it and the backup before restoring")

    restored = text.replace(block, manifest["original"], 1)
    with open(target, "w", encoding="utf-8") as stream:  # NOSONAR
        stream.write(restored)
def fallback_panel(paths):
    uid_str = str(os.getuid()) if hasattr(os, "getuid") else "1000"
    check = subprocess.run(["pgrep", "-u", uid_str, "-x", "waybar"], capture_output=True)
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
