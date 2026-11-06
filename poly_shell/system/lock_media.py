"""Hyprlock lockscreen media widget helper (album art, metadata, control bar)."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.parse
import urllib.request

TRANSPARENT_1X1_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\rIDATx\x9cc`\x00\x00\x00"
    b"\x02\x00\x01H\xaf\xa4q\x00\x00\x00\x00IEND\xaeB`\x82"
)


def _default_art_path() -> Path:
    # Use private user runtime directory (e.g. /run/user/<uid>/) if available
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if runtime and os.path.isdir(runtime):
        p = Path(runtime) / "alpora" / "alpora-lock-art.png"
        p.parent.mkdir(parents=True, exist_ok=True)
        return p
    # Fallback to tempfile in user-scoped directory
    uid_str = str(os.getuid()) if hasattr(os, "getuid") else "user"
    user_temp = Path(tempfile.gettempdir()) / f"alpora-lock-art-{uid_str}.png"
    return user_temp


def get_status() -> str:
    """Return 'Playing', 'Paused', or empty string."""
    try:
        proc = subprocess.run(
            ["playerctl", "status"],
            capture_output=True,
            text=True,
            timeout=1.5,
        )
        if proc.returncode == 0:
            return proc.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pass
    return ""


def get_title(max_len: int = 36) -> str:
    """Return formatted track title or empty string if no playback."""
    status = get_status()
    if not status or status not in ("Playing", "Paused"):
        return ""
    try:
        proc = subprocess.run(
            ["playerctl", "metadata", "--format", "{{title}}"],
            capture_output=True,
            text=True,
            timeout=1.5,
        )
        if proc.returncode == 0:
            title = proc.stdout.strip()
            if len(title) > max_len:
                return title[: max_len - 1] + "…"
            return title
    except (OSError, subprocess.SubprocessError):
        pass
    return ""


def get_artist(max_len: int = 36) -> str:
    """Return formatted artist name or empty string if no playback."""
    status = get_status()
    if not status or status not in ("Playing", "Paused"):
        return ""
    try:
        proc = subprocess.run(
            ["playerctl", "metadata", "--format", "{{artist}}"],
            capture_output=True,
            text=True,
            timeout=1.5,
        )
        if proc.returncode == 0:
            artist = proc.stdout.strip()
            if len(artist) > max_len:
                return artist[: max_len - 1] + "…"
            return artist
    except (OSError, subprocess.SubprocessError):
        pass
    return ""


def get_controls() -> str:
    """Return media control glyph bar or empty string if no playback."""
    status = get_status()
    if status == "Playing":
        return "󰒮   󰏤   󰒭"
    if status == "Paused":
        return "󰒮   󰐊   󰒭"
    return ""


def get_art(target_path: Path | None = None) -> str:
    """Ensure album artwork or transparent placeholder exists at target_path and return path."""
    dest = target_path or _default_art_path()
    status = get_status()

    if status not in ("Playing", "Paused"):
        try:
            dest.write_bytes(TRANSPARENT_1X1_PNG)
        except OSError:
            pass
        return str(dest)

    try:
        proc = subprocess.run(
            ["playerctl", "metadata", "mpris:artUrl"],
            capture_output=True,
            text=True,
            timeout=1.5,
        )
        url = proc.stdout.strip() if proc.returncode == 0 else ""
        if url.startswith("file://"):
            local_path = Path(urllib.parse.unquote(url[7:]))
            if local_path.is_file():
                shutil.copyfile(local_path, dest)
                return str(dest)
        elif url.startswith(("http://", "https://")):
            req = urllib.request.Request(url, headers={"User-Agent": "Alpora-Lockscreen/1.0"})
            with urllib.request.urlopen(req, timeout=2.0) as response:
                dest.write_bytes(response.read())
            return str(dest)
    except Exception:
        pass

    try:
        dest.write_bytes(TRANSPARENT_1X1_PNG)
    except OSError:
        pass
    return str(dest)


def handle_cli(subcommand: str) -> None:
    """CLI dispatcher for poly-shell lock-media."""
    if subcommand == "title":
        print(get_title())
    elif subcommand == "artist":
        print(get_artist())
    elif subcommand == "controls":
        print(get_controls())
    elif subcommand == "status":
        print(get_status())
    elif subcommand == "art":
        print(get_art())
    else:
        # Default prints one-line summary
        t = get_title()
        a = get_artist()
        if t and a:
            print(f"{t} · {a}")
        elif t:
            print(t)
        else:
            print("")
