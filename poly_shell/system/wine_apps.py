"""Windows .EXE compatibility suite and application manager for ALPORA.

Enables running, downloading, and installing Windows applications (such as Zalo,
UltraViewer, Notepad++) on Linux under Hyprland using Wine, with automated
Vietnamese font fixes and XDG .desktop application menu registration.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Dict, List, Optional
import urllib.request
import urllib.error

# Official / verified presets for popular Windows applications needed on Linux
KNOWN_PRESETS: Dict[str, Dict[str, Any]] = {
    "zalo": {
        "name": "Zalo",
        "description": "Zalo Messaging & Video Calls",
        "url": "https://res-zalo.zadn.vn/download/ZaloSetup.exe",
        "search_patterns": [
            "drive_c/users/*/AppData/Local/Programs/Zalo/Zalo.exe",
            "drive_c/Program Files*/Zalo/Zalo.exe",
        ],
        "categories": "Network;InstantMessaging;Chat;",
        "icon": "zalo",
        "aur_package": "zalo-native-bin",
    },
    "ultraviewer": {
        "name": "UltraViewer",
        "description": "UltraViewer Remote Desktop Support",
        "url": "https://www.ultraviewer.net/en/UltraViewer_setup.exe",
        "search_patterns": [
            "drive_c/Program Files*/UltraViewer/UltraViewer.exe",
        ],
        "categories": "Network;RemoteAccess;",
        "icon": "preferences-desktop-remote-desktop",
        "aur_package": None,
    },
    "notepadpp": {
        "name": "Notepad++",
        "description": "Notepad++ Source Code & Text Editor",
        "url": "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.6.9/npp.8.6.9.Installer.x64.exe",
        "search_patterns": [
            "drive_c/Program Files*/Notepad++/notepad++.exe",
        ],
        "categories": "Development;TextEditor;",
        "icon": "accessories-text-editor",
        "aur_package": "notepad-plus-plus",
    },
}


def get_wine_base_dir() -> Path:
    """Returns the base directory for ALPORA managed Wine prefixes."""
    xdg_data = os.environ.get("XDG_DATA_HOME")
    if xdg_data:
        base = Path(xdg_data) / "alpora" / "wine-prefixes"
    else:
        base = Path.home() / ".local" / "share" / "alpora" / "wine-prefixes"
    base.mkdir(parents=True, exist_ok=True)
    return base


def get_wine_prefix(app_name: str) -> Path:
    """Returns the dedicated Wine prefix for a given application."""
    safe_name = "".join(c for c in app_name.lower() if c.isalnum() or c in ("-", "_")) or "default"
    prefix = get_wine_base_dir() / safe_name
    prefix.mkdir(parents=True, exist_ok=True)
    return prefix


def get_applications_dir() -> Path:
    """Returns XDG applications directory for .desktop files."""
    xdg_data = os.environ.get("XDG_DATA_HOME")
    if xdg_data:
        apps = Path(xdg_data) / "applications"
    else:
        apps = Path.home() / ".local" / "share" / "applications"
    apps.mkdir(parents=True, exist_ok=True)
    return apps


def is_wine_available() -> bool:
    """Checks if wine binary is installed and executable in PATH."""
    return shutil.which("wine") is not None


def download_file(url: str, destination: Path, chunk_size: int = 65536) -> Path:
    """Downloads a file from URL with chunked stream."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) ALPORA-Shell/1.0"}
    )
    with urllib.request.urlopen(req, timeout=30) as response, open(destination, "wb") as out_file:
        while True:
            chunk = response.read(chunk_size)
            if not chunk:
                break
            out_file.write(chunk)
    return destination


def generate_vietnamese_font_reg() -> str:
    """Generates registry script to alias Windows fonts to Linux Unicode fonts.
    
    Prevents Vietnamese characters (tiếng Việt có dấu) from appearing as square boxes
    or question marks in Wine applications like Zalo.
    """
    return (
        "Windows Registry Editor Version 5.00\r\n\r\n"
        "[HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements]\r\n"
        '"Segoe UI"="Noto Sans"\r\n'
        '"Tahoma"="Noto Sans"\r\n'
        '"Arial"="Liberation Sans"\r\n'
        '"MS Sans Serif"="Noto Sans"\r\n'
        '"Microsoft Sans Serif"="Noto Sans"\r\n\r\n'
        "[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes]\r\n"
        '"MS Shell Dlg"="Noto Sans"\r\n'
        '"MS Shell Dlg 2"="Noto Sans"\r\n'
        '"Tahoma"="Noto Sans"\r\n'
    )


def apply_font_fixes(prefix: Path) -> bool:
    """Applies Vietnamese font substitutions to the specified Wine prefix."""
    if not is_wine_available():
        return False
    reg_content = generate_vietnamese_font_reg()
    with tempfile.NamedTemporaryFile("w", suffix=".reg", delete=False) as f:
        f.write(reg_content)
        temp_reg = f.name
    try:
        env = os.environ.copy()
        env["WINEPREFIX"] = str(prefix)
        env["WINEDEBUG"] = "-all"
        subprocess.run(
            ["wine", "regedit", temp_reg],
            env=env,
            capture_output=True,
            timeout=15,
            check=False
        )
        return True
    except (subprocess.SubprocessError, OSError):
        return False
    finally:
        try:
            os.unlink(temp_reg)
        except OSError:
            pass


def create_desktop_entry(
    name: str,
    exec_cmd: str,
    icon: str = "application-x-ms-dos-executable",
    categories: str = "Utility;",
    comment: str = "Windows Application on ALPORA",
    filename: Optional[str] = None
) -> Path:
    """Creates an XDG .desktop entry so the app appears immediately in ALPORA Launcher."""
    apps_dir = get_applications_dir()
    safe_name = filename or f"alpora-wine-{name.lower().replace(' ', '-')}.desktop"
    target = apps_dir / safe_name

    desktop_content = (
        "[Desktop Entry]\n"
        "Type=Application\n"
        f"Name={name}\n"
        f"Comment={comment}\n"
        f"Exec={exec_cmd}\n"
        f"Icon={icon}\n"
        f"Categories={categories}\n"
        "Terminal=false\n"
        "StartupNotify=true\n"
        "StartupWMClass=wine\n"
    )

    target.write_text(desktop_content, encoding="utf-8")

    # Notify desktop environment if update-desktop-database is available
    if shutil.which("update-desktop-database"):
        subprocess.run(["update-desktop-database", str(apps_dir)], capture_output=True, check=False)

    return target


def register_exe_mime_handler() -> Optional[Path]:
    """Registers ALPORA EXE runner as default handler for .exe files."""
    desktop_file = create_desktop_entry(
        name="ALPORA Windows App Runner",
        exec_cmd="poly-shell exe run %f",
        icon="application-x-ms-dos-executable",
        categories="System;Utility;",
        comment="Run Windows .EXE applications seamlessly with Wine",
        filename="alpora-exe-runner.desktop"
    )
    if shutil.which("xdg-mime"):
        for mime in ("application/x-ms-dos-executable", "application/x-msdownload", "application/vnd.microsoft.portable-executable"):
            subprocess.run(["xdg-mime", "default", "alpora-exe-runner.desktop", mime], capture_output=True, check=False)
    return desktop_file


def run_exe_file(
    exe_path: Path,
    prefix: Optional[Path] = None,
    args: Optional[List[str]] = None,
    wait: bool = True
) -> int:
    """Executes a Windows .exe file under Wine with font and DPI environment."""
    if not is_wine_available():
        print(
            "Lỗi: Chưa cài đặt Wine trên hệ thống.\n"
            "Hãy cài đặt Wine bằng lệnh: sudo pacman -S wine wine-gecko wine-mono winetricks",
            file=sys.stderr
        )
        return 127

    target_prefix = prefix or get_wine_prefix("default")
    env = os.environ.copy()
    env["WINEPREFIX"] = str(target_prefix)
    env["WINEDEBUG"] = "-all"
    # Ensure UTF-8 locale for Vietnamese support
    env["LANG"] = "vi_VN.UTF-8" if "vi_VN" in os.environ.get("LANG", "") else "en_US.UTF-8"

    cmd = ["wine", str(exe_path)] + (args or [])
    if wait:
        res = subprocess.run(cmd, env=env, check=False)
        return res.returncode
    else:
        subprocess.Popen(cmd, env=env, start_new_session=True)
        return 0


def find_installed_exe(prefix: Path, patterns: List[str]) -> Optional[Path]:
    """Finds the main installed .exe inside a Wine prefix matching search glob patterns."""
    for pattern in patterns:
        matches = list(prefix.glob(pattern))
        if matches:
            # Return first executable match
            for m in matches:
                if m.is_file():
                    return m
    return None
