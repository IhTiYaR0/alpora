"""Poly Shell: a workspace-oriented Hyprland shell, currently a foundation preview."""
from __future__ import annotations

import importlib
import sys
import types

__version__ = "1.0.0"

# Mapping of legacy flat root module names to their clean domain subpackages
_DOMAIN_MODULES = {
    # Core Runtime
    "state": "poly_shell.core.state",
    "i18n": "poly_shell.core.i18n",
    "daemon": "poly_shell.core.daemon",
    "ipc_server": "poly_shell.core.ipc_server",
    "resilience": "poly_shell.core.resilience",
    "service": "poly_shell.core.service",
    "watchdog": "poly_shell.core.watchdog",
    # Domain Services
    "organizer": "poly_shell.services.organizer",
    "shortcuts": "poly_shell.services.shortcuts",
    "task_manager": "poly_shell.services.task_manager",
    "wellbeing": "poly_shell.services.wellbeing",
    "developer_metrics": "poly_shell.services.developer_metrics",
    "clipboard": "poly_shell.services.clipboard",
    # Theming & Visuals
    "appearance": "poly_shell.theming.appearance",
    "themes": "poly_shell.theming.themes",
    "timeline": "poly_shell.theming.timeline",
    "visual": "poly_shell.theming.visual",
    "landscapes": "poly_shell.theming.landscapes",
    "terminal_colors": "poly_shell.theming.terminal_colors",
    "desktop_assets": "poly_shell.theming.desktop_assets",
    "toolkit_refresh": "poly_shell.theming.toolkit_refresh",
    # System & OS Integration
    "desktop": "poly_shell.system.desktop",
    "bootstrap": "poly_shell.system.bootstrap",
    "diagnostics": "poly_shell.system.diagnostics",
    "fetch": "poly_shell.system.fetch",
    "hardware": "poly_shell.system.hardware",
    "indicators": "poly_shell.system.indicators",
    "installer_ui": "poly_shell.system.installer_ui",
    "integration": "poly_shell.system.integration",
    "lockscreen": "poly_shell.system.lockscreen",
    "lock_media": "poly_shell.system.lock_media",
    "preflight": "poly_shell.system.preflight",
    "programs": "poly_shell.system.programs",
    "radios_power": "poly_shell.system.radios_power",
    "running_apps": "poly_shell.system.running_apps",
    "widgets": "poly_shell.system.widgets",
    "windows_fs": "poly_shell.system.windows_fs",
    "wine_apps": "poly_shell.system.wine_apps",
    "demo_server": "poly_shell.system.demo_server",
}


class _LazyModule(types.ModuleType):
    """Dynamic proxy delegating to relocated domain submodules for 100% backward compatibility."""

    def __init__(self, alias: str, target_pkg: str):
        super().__init__(f"poly_shell.{alias}")
        self.__package__ = "poly_shell"
        self._alias = alias
        self._target_pkg = target_pkg
        self._real: types.ModuleType | None = None

    def _resolve(self) -> types.ModuleType:
        if self._real is None:
            self._real = importlib.import_module(self._target_pkg)
            sys.modules[f"poly_shell.{self._alias}"] = self._real
            globals()[self._alias] = self._real
        return self._real

    def __getattr__(self, attr):
        return getattr(self._resolve(), attr)

    def __setattr__(self, attr, value):
        if attr in ("__name__", "__package__", "_alias", "_target_pkg", "_real"):
            super().__setattr__(attr, value)
        else:
            setattr(self._resolve(), attr, value)

    def __delattr__(self, attr):
        delattr(self._resolve(), attr)


for _alias, _target in _DOMAIN_MODULES.items():
    _proxy = _LazyModule(_alias, _target)
    sys.modules[f"poly_shell.{_alias}"] = _proxy
    globals()[_alias] = _proxy


def __getattr__(name: str):
    if name in _DOMAIN_MODULES:
        return _DOMAIN_MODULES[name]
    raise AttributeError(f"module 'poly_shell' has no attribute '{name}'")


from .core.watchdog import CrashReporter

# Automatically install non-invasive telemetry and crash reporting
CrashReporter.install()
