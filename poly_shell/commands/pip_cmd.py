"""Command handler for ALPORA Floating Video PiP (Picture-in-Picture) player.

Supports launching isolated, borderless, floating video windows for:
- TikTok (vertical 9:16)
- YouTube Shorts (vertical 9:16)
- YouTube (landscape 16:9)
- Custom video URLs or streams
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import List, Optional

PRESET_URLS = {
    "tiktok": "https://www.tiktok.com",
    "shorts": "https://www.youtube.com/shorts",
    "youtube": "https://www.youtube.com",
}

DEFAULT_SIZES = {
    "vertical": (360, 640),
    "landscape": (540, 304),
}


def _safe_print(*args, file=None, **kwargs):
    """Prints message safely even in environments with restricted encodings (e.g. cp1252 on Windows)."""
    target = file or sys.stdout
    msg = " ".join(str(a) for a in args)
    try:
        print(msg, file=target, **kwargs)
    except UnicodeEncodeError:
        try:
            target.buffer.write((msg + "\n").encode("utf-8", errors="replace"))
        except Exception:
            print(msg.encode("ascii", errors="replace").decode("ascii"), file=target, **kwargs)


def detect_browser() -> Optional[str]:
    """Finds an installed browser supporting app/kiosk mode."""
    candidates = [
        "chromium",
        "google-chrome-stable",
        "google-chrome",
        "brave",
        "brave-browser",
        "microsoft-edge-stable",
        "microsoft-edge",
        "vivaldi",
        "zen-browser",
        "firefox",
    ]
    for b in candidates:
        found = shutil.which(b)
        if found:
            return found
    return None


def launch_video_pip(
    target: str = "tiktok",
    mode: Optional[str] = None,
    width: Optional[int] = None,
    height: Optional[int] = None
) -> int:
    """Launches floating PiP browser window tailored for TikTok / Shorts / YouTube."""
    target_key = target.lower().strip()
    url = PRESET_URLS.get(target_key, target)
    if not url.startswith("http://") and not url.startswith("https://"):
        url = "https://" + url

    # Infer mode if not explicitly passed
    if not mode:
        if target_key in ("tiktok", "shorts") or "shorts" in url or "tiktok.com" in url:
            mode = "vertical"
        else:
            mode = "landscape"

    def_w, def_h = DEFAULT_SIZES[mode]
    win_w = width or def_w
    win_h = height or def_h

    browser = detect_browser()
    if not browser:
        _safe_print("Lỗi: Không tìm thấy trình duyệt phù hợp (Chromium, Chrome, Brave, Firefox) trên hệ thống.", file=sys.stderr)
        return 1

    browser_name = Path(browser).name.lower()
    win_class = f"alpora-pip-{mode}"

    # Build command based on browser type
    if any(k in browser_name for k in ("chrom", "brave", "edge", "vivaldi")):
        # Chromium-based browsers support --app= and custom window sizing
        user_data = Path.home() / ".local" / "state" / "alpora" / "pip-profile"
        user_data.mkdir(parents=True, exist_ok=True)
        cmd = [
            browser,
            f"--app={url}",
            f"--class={win_class}",
            f"--window-size={win_w},{win_h}",
            f"--user-data-dir={user_data}",
            "--no-first-run",
            "--disable-features=Translate",
        ]
    else:
        # Firefox / Zen
        cmd = [
            browser,
            "--new-window",
            url,
            "--class",
            win_class,
        ]

    try:
        subprocess.Popen(cmd, start_new_session=True)
        _safe_print(f"Đã mở Video PiP [{target_key}] ({mode}: {win_w}x{win_h}) bằng {browser_name}")
        return 0
    except Exception as e:
        _safe_print(f"Lỗi khi khởi chạy Video PiP: {e}", file=sys.stderr)
        return 1


def handle_pip(args: argparse.Namespace) -> int:
    """Dispatches `poly-shell pip` CLI action."""
    action = getattr(args, "target", "tiktok")
    mode = getattr(args, "mode", None)
    w = getattr(args, "width", None)
    h = getattr(args, "height", None)

    return launch_video_pip(target=action, mode=mode, width=w, height=h)
