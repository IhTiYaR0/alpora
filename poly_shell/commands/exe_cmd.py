"""CLI command handler for Windows .EXE compatibility and app installers."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Optional

from ..system.wine_apps import (
    KNOWN_PRESETS,
    apply_font_fixes,
    create_desktop_entry,
    download_file,
    find_installed_exe,
    get_wine_prefix,
    is_wine_available,
    register_exe_mime_handler,
    run_exe_file,
)


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


def handle_exe(args: argparse.Namespace) -> int:
    """Dispatches `poly-shell exe <subcommand>`."""
    action = getattr(args, "exe_action", None)

    if action == "list":
        _safe_print("ALPORA Windows App Presets:")
        for key, info in KNOWN_PRESETS.items():
            aur_info = f" (AUR: {info['aur_package']})" if info.get('aur_package') else ""
            _safe_print(f"  - {key:<12} : {info['description']}{aur_info}")
        return 0

    elif action == "register-mime":
        desktop_entry = register_exe_mime_handler()
        _safe_print(f"Đã đăng ký ALPORA Windows App Runner cho file .exe ({desktop_entry})")
        return 0

    elif action == "download":
        target = args.target.lower()
        preset = KNOWN_PRESETS.get(target)
        url = preset["url"] if preset else args.target

        out_dir = Path(args.output) if args.output else Path.home() / "Downloads"
        out_dir.mkdir(parents=True, exist_ok=True)
        filename = (preset["name"] + "Setup.exe") if preset else Path(url.split("?")[0]).name
        dest = out_dir / (filename if filename.endswith(".exe") else filename + ".exe")

        _safe_print(f"Đang tải {url} -> {dest} ...")
        try:
            download_file(url, dest)
            _safe_print(f"Tải thành công: {dest}")
            _safe_print(f"Để cài đặt, hãy chạy: poly-shell exe install \"{dest}\"")
            return 0
        except Exception as e:
            _safe_print(f"Lỗi khi tải file: {e}", file=sys.stderr)
            return 1

    elif action == "run":
        exe_path = Path(args.path).expanduser().resolve()
        if not exe_path.exists():
            _safe_print(f"Lỗi: Không tìm thấy file {exe_path}", file=sys.stderr)
            return 1

        prefix = Path(args.prefix).expanduser().resolve() if getattr(args, "prefix", None) else None
        return run_exe_file(exe_path, prefix=prefix, args=getattr(args, "extra_args", []))

    elif action == "install":
        target = args.target
        preset_key = target.lower() if target.lower() in KNOWN_PRESETS else None
        preset = KNOWN_PRESETS.get(preset_key) if preset_key else None

        app_name = args.name or (preset["name"] if preset else Path(target).stem)
        prefix = get_wine_prefix(app_name)

        # 1. Obtain installer exe path
        installer_path: Path
        if preset and not Path(target).exists():
            _safe_print(f"Đang tải bộ cài cho {preset['name']}...")
            downloads_dir = Path.home() / "Downloads"
            downloads_dir.mkdir(parents=True, exist_ok=True)
            installer_path = downloads_dir / f"{preset['name']}Setup.exe"
            try:
                download_file(preset["url"], installer_path)
            except Exception as e:
                _safe_print(f"Không thể tải file: {e}", file=sys.stderr)
                return 1
        else:
            installer_path = Path(target).expanduser().resolve()
            if not installer_path.exists():
                _safe_print(f"Lỗi: Không tìm thấy file {installer_path}", file=sys.stderr)
                return 1

        # 2. Check Wine
        if not is_wine_available():
            _safe_print(
                "Lỗi: Wine chưa được cài đặt. Vui lòng cài đặt bằng lệnh:\n"
                "sudo pacman -S wine wine-gecko wine-mono winetricks\n",
                file=sys.stderr
            )
            return 127

        # 3. Setup Vietnamese fonts fix
        _safe_print("Đang áp dụng font Unicode / Noto Sans tiếng Việt cho Wine...")
        apply_font_fixes(prefix)

        # 4. Run installer
        _safe_print(f"Đang khởi chạy trình cài đặt {app_name} trong prefix {prefix} ...")
        res = run_exe_file(installer_path, prefix=prefix, wait=True)
        if res != 0:
            _safe_print(f"Cảnh báo: Trình cài đặt thoát với mã {res}")

        # 5. Locate installed binary or use search patterns
        patterns = preset["search_patterns"] if preset else [
            f"drive_c/Program Files*/{app_name}*/*.exe",
            f"drive_c/users/*/AppData/Local/Programs/{app_name}*/*.exe",
        ]
        installed_exe = find_installed_exe(prefix, patterns)

        if installed_exe:
            exec_cmd = f"poly-shell exe run \"{installed_exe}\" --prefix \"{prefix}\""
            icon = preset["icon"] if preset else "application-x-ms-dos-executable"
            categories = preset["categories"] if preset else "Utility;"
            desktop_file = create_desktop_entry(
                name=app_name,
                exec_cmd=exec_cmd,
                icon=icon,
                categories=categories,
                comment=f"{app_name} (Windows via ALPORA Wine)"
            )
            _safe_print(f"Thành công! Đã tạo shortcut ứng dụng: {desktop_file}")
            _safe_print(f"Ứng dụng {app_name} đã sẵn sàng trong ALPORA Launcher (Super + Space).")
        else:
            _safe_print(f"Đã hoàn thành cài đặt trong {prefix}. Nếu chưa thấy icon trong launcher, hãy kiểm tra thư mục cài đặt.")

        return 0

    elif action == "zalo":
        # Dedicated 1-command installer for Zalo
        _safe_print("=== Cài đặt Zalo trên ALPORA Linux ===")

        # Option A: Check for AUR helper if requested or available
        prefer_aur = getattr(args, "aur", False)
        aur_helper = shutil.which("yay") or shutil.which("paru")

        if prefer_aur and aur_helper:
            _safe_print(f"Đang cài đặt Zalo từ AUR bằng {aur_helper}...")
            return subprocess.run([aur_helper, "-S", "--noconfirm", "zalo-native-bin"]).returncode

        # Option B: Automated Wine Installer with Vietnamese font optimization
        _safe_print("Tiến hành cài đặt Zalo PC (phiên bản Windows tối ưu qua Wine)...")
        args.target = "zalo"
        args.name = "Zalo"
        return handle_exe(argparse.Namespace(
            exe_action="install",
            target="zalo",
            name="Zalo",
            output=None,
            prefix=None
        ))

    else:
        _safe_print(f"Hành động không hợp lệ: {action}", file=sys.stderr)
        return 1
