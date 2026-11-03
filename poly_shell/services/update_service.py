"""Update service for ALPORA OS: checks GitHub releases, manages semver updates, and applies OTA patches."""
from __future__ import annotations

import json
import logging
from pathlib import Path
import re
import subprocess
import time
from typing import Any, Dict, Optional
import urllib.request
import urllib.error

from ..core.service import BaseService
from ..core.state import Paths, ROOT
from ..contracts.base import BaseDTO

logger = logging.getLogger(__name__)


def parse_semver(v_str: str) -> tuple[int, ...]:
    """Parses a version string like 'v1.2.3' or '1.2.0-dev' into comparable integer tuple."""
    clean = re.sub(r"^[vV]", "", v_str.strip())
    # Extract leading numbers
    parts = []
    for p in re.split(r"[-+.]", clean):
        if p.isdigit():
            parts.append(int(p))
        else:
            break
    return tuple(parts) if parts else (0, 0, 0)


class UpdateService(BaseService):
    """Encapsulates OTA updates, GitHub release tracking, and automated patch application."""

    CACHE_TTL_SECONDS = 3600  # 1 hour cache between GitHub API queries

    def __init__(self, paths: Optional[Paths] = None, repo_slug: str = "pnam-it309/alpora"):
        super().__init__("update")
        self.paths = paths or Paths.current()
        self.repo_slug = repo_slug

    def health_check(self) -> bool:
        return True

    def get_current_version(self) -> str:
        try:
            from .. import __version__
            return __version__
        except Exception:
            return "1.0.0"

    def get_state(self) -> BaseDTO:
        # Wrapper for BaseService contract
        return BaseDTO()

    def _cache_path(self) -> Path:
        return self.paths.state / "update_cache.json"

    def check_update(self, force: bool = False) -> Dict[str, Any]:
        """Queries GitHub Releases API to see if a newer version of ALPORA is available."""
        current_ver = self.get_current_version()
        cache_file = self._cache_path()
        now = time.time()

        if not force and cache_file.exists():
            try:
                cached = json.loads(cache_file.read_text(encoding="utf-8"))
                if (now - cached.get("checked_at", 0)) < self.CACHE_TTL_SECONDS:
                    return cached["data"]
            except Exception:
                pass

        url = f"https://api.github.com/repos/{self.repo_slug}/releases/latest"
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": f"ALPORA-OS/{current_ver}",
                "Accept": "application/vnd.github.v3+json",
            },
        )

        result: Dict[str, Any] = {
            "has_update": False,
            "current_version": current_ver,
            "latest_version": current_ver,
            "release_title": "Up to date",
            "release_notes": "",
            "published_at": "",
            "html_url": f"https://github.com/{self.repo_slug}",
            "iso_download_url": None,
        }

        try:
            with urllib.request.urlopen(req, timeout=4.0) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode("utf-8"))
                    tag_name = data.get("tag_name", "").lstrip("v")
                    latest_sem = parse_semver(tag_name)
                    current_sem = parse_semver(current_ver)

                    has_update = latest_sem > current_sem
                    iso_url = None
                    for asset in data.get("assets", []):
                        if asset.get("name", "").endswith(".iso"):
                            iso_url = asset.get("browser_download_url")
                            break

                    result = {
                        "has_update": has_update,
                        "current_version": current_ver,
                        "latest_version": data.get("tag_name", current_ver),
                        "release_title": data.get("name", f"ALPORA {data.get('tag_name', '')}"),
                        "release_notes": data.get("body", ""),
                        "published_at": data.get("published_at", ""),
                        "html_url": data.get("html_url", ""),
                        "iso_download_url": iso_url,
                    }
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            logger.debug("Failed to check GitHub releases: %s", exc)

        # Cache result
        try:
            self.paths.state.mkdir(parents=True, exist_ok=True)
            cache_file.write_text(
                json.dumps({"checked_at": now, "data": result}, ensure_ascii=False),
                encoding="utf-8",
            )
        except OSError:
            pass

        return result

    def apply_update(self, branch: str = "main") -> Dict[str, Any]:
        """Applies latest update to ALPORA repository and refreshes running desktop components."""
        target_dir = ROOT

        # 1. Check if ROOT is a Git repository
        git_dir = target_dir / ".git"
        if not git_dir.exists():
            return {
                "success": False,
                "error": f"Directory {target_dir} is not a Git checkout. Please update via package manager.",
            }

        try:
            # 2. Backup state and configurations before updating
            backup_dir = self.paths.state / "backups" / f"pre-update-{time.strftime('%Y%m%d-%H%M%S')}"
            backup_dir.mkdir(parents=True, exist_ok=True)
            if (self.paths.config / "settings.json").exists():
                import shutil
                shutil.copy2(self.paths.config / "settings.json", backup_dir / "settings.json")

            # 3. Pull latest changes cleanly
            fetch_cmd = subprocess.run(
                ["git", "-C", str(target_dir), "fetch", "origin", branch, "--depth=1"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if fetch_cmd.returncode != 0:
                return {
                    "success": False,
                    "error": f"Git fetch failed: {fetch_cmd.stderr.strip()}",
                }

            pull_cmd = subprocess.run(
                ["git", "-C", str(target_dir), "reset", "--hard", f"origin/{branch}"],
                capture_output=True,
                text=True,
                timeout=15,
            )
            if pull_cmd.returncode != 0:
                return {
                    "success": False,
                    "error": f"Git update failed: {pull_cmd.stderr.strip()}",
                }

            # 4. Notify Desktop of successful update
            if subprocess.run(["which", "notify-send"], capture_output=True).returncode == 0:
                subprocess.Popen(
                    [
                        "notify-send",
                        "-a", "ALPORA Update",
                        "-i", "system-software-update",
                        "ALPORA OS Updated",
                        f"Successfully updated to latest version on branch '{branch}'.",
                    ],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )

            # Invalidate update check cache
            if self._cache_path().exists():
                try:
                    self._cache_path().unlink()
                except OSError:
                    pass

            return {
                "success": True,
                "message": f"ALPORA updated successfully to latest {branch} commit.",
                "backup_path": str(backup_dir),
            }

        except Exception as exc:
            logger.error("Error during ALPORA update: %s", exc)
            return {"success": False, "error": str(exc)}

