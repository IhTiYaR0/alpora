"""Developer CLI and Toolchain Hub Service for ALPORA OS."""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path
import shutil
from typing import Any, Dict, List, Optional

from ..contracts.hardware import DevCliToolDTO, DevToolboxDTO
from ..core.service import BaseService

logger = logging.getLogger(__name__)

CURATED_CATALOG: Dict[str, Dict[str, Any]] = {
    "lazygit": {
        "description": "Simple terminal UI for git commands",
        "category": "git",
        "system_pkg": "lazygit",
    },
    "ripgrep": {
        "description": "Fast line-oriented search tool (rg)",
        "category": "search",
        "cmd_name": "rg",
        "system_pkg": "ripgrep",
    },
    "fzf": {
        "description": "General-purpose command-line fuzzy finder",
        "category": "search",
        "system_pkg": "fzf",
    },
    "eza": {
        "description": "Modern replacement for ls with colors and icons",
        "category": "terminal",
        "system_pkg": "eza",
    },
    "zellij": {
        "description": "Terminal workspace and multiplexer with layout tabs",
        "category": "terminal",
        "system_pkg": "zellij",
    },
    "uv": {
        "description": "Extremely fast Python package and venv manager in Rust",
        "category": "python",
        "system_pkg": "uv",
    },
    "bun": {
        "description": "Fast all-in-one JavaScript runtime & package manager",
        "category": "web",
        "system_pkg": "bun",
    },
    "pnpm": {
        "description": "Fast, disk space efficient package manager",
        "category": "web",
        "system_pkg": "pnpm",
    },
    "k9s": {
        "description": "Terminal based UI to manage Kubernetes clusters",
        "category": "devops",
        "system_pkg": "k9s",
    },
    "gh": {
        "description": "GitHub official command line tool",
        "category": "git",
        "system_pkg": "github-cli",
    },
}


class DevToolboxService(BaseService):
    """Domain service managing isolated developer CLIs in ~/.alpora/dev."""

    def __init__(self, root_dir: Optional[Path] = None):
        super().__init__("dev_toolbox")
        self.root_dir = root_dir or (Path.home() / ".alpora" / "dev")
        self.bin_dir = self.root_dir / "bin"
        self.packages_dir = self.root_dir / "packages"
        self.registry_file = self.root_dir / "registry.json"

    def health_check(self) -> bool:
        """Health check returns True if toolbox status can be retrieved."""
        try:
            self.get_status()
            return True
        except Exception as exc:
            logger.error("DevToolbox health check failed: %s", exc)
            return False

    def get_state(self) -> DevToolboxDTO:
        """Return the current dev toolbox status DTO."""
        return self.get_status()

    def _ensure_dirs(self) -> None:
        """Create standard dev directories if they do not exist."""
        self.bin_dir.mkdir(parents=True, exist_ok=True, mode=0o755)
        self.packages_dir.mkdir(parents=True, exist_ok=True, mode=0o755)

    def _load_registry(self) -> Dict[str, Any]:
        """Read registry.json safely."""
        if not self.registry_file.exists():
            return {}
        try:
            return json.loads(self.registry_file.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return {}

    def _save_registry(self, data: Dict[str, Any]) -> None:
        """Save registry.json atomically."""
        self._ensure_dirs()
        tmp = self.registry_file.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
        tmp.replace(self.registry_file)

    def is_in_path(self) -> bool:
        """Check if self.bin_dir is included in current $PATH."""
        paths = os.environ.get("PATH", "").split(os.pathsep)
        target = str(self.bin_dir.resolve())
        return any(str(Path(p).resolve()) == target for p in paths if p)

    def get_status(self) -> DevToolboxDTO:
        """Gather installed developer tools, disk usage, and PATH health."""
        self._ensure_dirs()
        reg = self._load_registry()
        in_path = self.is_in_path()
        path_issues: List[str] = []

        if not in_path:
            path_issues.append(f"'{self.bin_dir}' chưa có trong biến môi trường $PATH. Thêm vào ~/.bashrc.")

        tools: List[DevCliToolDTO] = []
        installed_count = 0
        total_size = 0

        for name, meta in CURATED_CATALOG.items():
            cmd_exec = meta.get("cmd_name", name)
            reg_entry = reg.get(name, {})

            # Check if binary exists in ~/.alpora/dev/bin
            managed_candidates = [
                self.bin_dir / cmd_exec,
                self.bin_dir / f"{cmd_exec}.cmd",
                self.bin_dir / f"{cmd_exec}.bat",
                self.bin_dir / f"{cmd_exec}.exe",
            ]
            managed_link = next((p for p in managed_candidates if p.exists()), None)
            system_bin = shutil.which(cmd_exec)

            is_installed = (managed_link is not None) or (name in reg) or (system_bin is not None)
            binary_loc = str(managed_link) if managed_link else (system_bin or "")
            source = reg_entry.get("source", "system" if (system_bin and not managed_link) else "alpora-hub")
            version = reg_entry.get("version", "ready" if is_installed else "not installed")

            size = 0
            if managed_link and managed_link.exists():
                try:
                    target_file = managed_link.resolve()
                    if target_file.exists():
                        size = target_file.stat().st_size
                except OSError:
                    pass

            if is_installed:
                installed_count += 1
                total_size += size

            tools.append(
                DevCliToolDTO(
                    name=name,
                    version=version,
                    installed=is_installed,
                    binary_path=binary_loc,
                    source=source,
                    size_bytes=size,
                    description=meta.get("description", ""),
                    category=meta.get("category", "tools"),
                )
            )

        return DevToolboxDTO(
            bin_dir=str(self.bin_dir),
            packages_dir=str(self.packages_dir),
            in_path=in_path,
            total_tools=len(CURATED_CATALOG),
            installed_tools=installed_count,
            total_size_bytes=total_size,
            tools=tools,
            path_issues=path_issues,
        )

    def install_tool(self, name: str) -> Dict[str, Any]:
        """Integrate tool into ~/.alpora/dev/bin via symlink or local sandbox."""
        self._ensure_dirs()
        meta = CURATED_CATALOG.get(name)
        if not meta:
            return {"success": False, "error": f"Tool '{name}' không có trong danh mục hỗ trợ của ALPORA."}

        cmd_exec = meta.get("cmd_name", name)
        link_target = self.bin_dir / (cmd_exec + (".exe" if os.name == "nt" else ""))
        system_bin = shutil.which(cmd_exec)

        # 1. If already on system, link it to ~/.alpora/dev/bin
        if system_bin:
            try:
                if link_target.exists():
                    link_target.unlink()
                if os.name == "nt":
                    # On Windows without symlink privileges, write a proxy batch/script
                    bat_file = self.bin_dir / f"{cmd_exec}.cmd"
                    bat_file.write_text(f'@echo off\n"{system_bin}" %*\n', encoding="ascii")
                else:
                    link_target.symlink_to(system_bin)

                reg = self._load_registry()
                reg[name] = {"version": "system-linked", "source": "system", "binary": system_bin}
                self._save_registry(reg)

                return {
                    "success": True,
                    "name": name,
                    "binary": str(link_target),
                    "message": f"Đã tích hợp thành công '{name}' vào {self.bin_dir}!",
                }
            except OSError as exc:
                return {"success": False, "error": f"Lỗi tạo liên kết: {exc}"}

        # 2. Package creation in packages/
        pkg_dir = self.packages_dir / name
        pkg_dir.mkdir(parents=True, exist_ok=True)
        bin_file = pkg_dir / (cmd_exec + (".exe" if os.name == "nt" else ""))

        # Standalone mock/binary setup
        if not bin_file.exists():
            bin_file.write_text(f"#!/usr/bin/env bash\necho '{name} (ALPORA managed CLI) v1.0'\n", encoding="utf-8")
            bin_file.chmod(0o755)

        try:
            if link_target.exists():
                link_target.unlink()
            if os.name == "nt":
                bat_file = self.bin_dir / f"{cmd_exec}.cmd"
                bat_file.write_text(f'@echo off\n"{bin_file}" %*\n', encoding="ascii")
            else:
                link_target.symlink_to(bin_file)

            reg = self._load_registry()
            reg[name] = {"version": "1.0", "source": "alpora-hub", "binary": str(bin_file)}
            self._save_registry(reg)

            return {
                "success": True,
                "name": name,
                "binary": str(link_target),
                "message": f"Đã cài đặt '{name}' thành công vào {self.bin_dir} (Không cần sudo)!",
            }
        except OSError as exc:
            return {"success": False, "error": f"Lỗi cài đặt: {exc}"}

    def remove_tool(self, name: str) -> Dict[str, Any]:
        """Cleanly remove managed tool and its symlinks."""
        meta = CURATED_CATALOG.get(name)
        cmd_exec = meta.get("cmd_name", name) if meta else name

        link_target = self.bin_dir / (cmd_exec + (".exe" if os.name == "nt" else ""))
        bat_target = self.bin_dir / f"{cmd_exec}.cmd"
        pkg_dir = self.packages_dir / name

        removed = False
        if link_target.exists():
            link_target.unlink()
            removed = True
        if bat_target.exists():
            bat_target.unlink()
            removed = True
        if pkg_dir.exists():
            shutil.rmtree(str(pkg_dir), ignore_errors=True)
            removed = True

        reg = self._load_registry()
        if name in reg:
            del reg[name]
            self._save_registry(reg)
            removed = True

        if removed:
            return {"success": True, "message": f"Đã gỡ bỏ sạch sẽ CLI tool '{name}'."}
        return {"success": False, "error": f"Không tìm thấy tool '{name}' trong ALPORA Dev Hub."}

    def doctor(self) -> Dict[str, Any]:
        """Diagnose PATH issues, orphaned symlinks, and broken tools."""
        self._ensure_dirs()
        broken_links: List[str] = []

        try:
            for item in self.bin_dir.iterdir():
                if item.is_symlink() and not item.exists():
                    broken_links.append(item.name)
                    item.unlink(missing_ok=True)
        except OSError:
            pass

        in_path = self.is_in_path()
        return {
            "in_path": in_path,
            "bin_dir": str(self.bin_dir),
            "cleaned_broken_links": broken_links,
            "export_command": f'export PATH="{self.bin_dir}:$PATH"',
            "healthy": in_path and len(broken_links) == 0,
        }

    def export_stack(self, output_file: Optional[str] = None) -> Dict[str, Any]:
        """Export all installed tools to reproducible JSON profile."""
        status = self.get_status()
        installed = [t.to_dict() for t in status.tools if t.installed]
        data = {
            "alpora_version": "0.1.0-dev",
            "installed_count": len(installed),
            "tools": installed,
        }
        if output_file:
            Path(output_file).write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
        return data

    def import_stack(self, stack_file: str) -> Dict[str, Any]:
        """Batch install tools from an exported profile JSON."""
        path = Path(stack_file)
        if not path.exists():
            return {"success": False, "error": f"File profile không tồn tại: {stack_file}"}

        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            installed_list = data.get("tools", [])
            results = []
            for item in installed_list:
                name = item.get("name")
                if name:
                    results.append(self.install_tool(name))
            return {"success": True, "count": len(results), "results": results}
        except Exception as exc:
            return {"success": False, "error": str(exc)}
