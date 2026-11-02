"""Lightweight Linux system metrics for the ALPORA developer widget."""
from __future__ import annotations

import csv
import os
from pathlib import Path
import shutil
import subprocess
import time


def _read_cpu_times():
    try:
        fields = Path("/proc/stat").read_text(encoding="ascii").splitlines()[0].split()[1:]
        values = [int(value) for value in fields[:8]]
        if len(values) < 5:
            return None
        total = sum(values)
        idle = values[3] + (values[4] if len(values) > 4 else 0)
        return total, idle
    except (OSError, ValueError, IndexError):
        return None


_last_cpu_times = None
_last_cpu_percent = 0.0


def _cpu_percent():
    global _last_cpu_times, _last_cpu_percent
    current = _read_cpu_times()
    if current is None:
        return None
    if _last_cpu_times is None:
        _last_cpu_times = current
        return 0.0
    total = current[0] - _last_cpu_times[0]
    idle = current[1] - _last_cpu_times[1]
    _last_cpu_times = current
    if total <= 0:
        return _last_cpu_percent
    _last_cpu_percent = round(max(0.0, min(100.0, 100.0 * (total - idle) / total)), 1)
    return _last_cpu_percent


_cached_cpu_model = None


def _cpu_model():
    global _cached_cpu_model
    if _cached_cpu_model is not None:
        return _cached_cpu_model
    try:
        for line in Path("/proc/cpuinfo").read_text(encoding="utf-8", errors="replace").splitlines():
            if line.lower().startswith(("model name", "hardware")) and ":" in line:
                _cached_cpu_model = line.split(":", 1)[1].strip()
                return _cached_cpu_model
    except OSError:
        pass
    _cached_cpu_model = "CPU"
    return _cached_cpu_model


def _memory():
    values = {}
    try:
        for line in Path("/proc/meminfo").read_text(encoding="ascii").splitlines():
            key, _, rest = line.partition(":")
            if rest.strip():
                values[key] = int(rest.split()[0])  # Linux reports kB here.
    except (OSError, ValueError, IndexError):
        pass
    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable", values.get("MemFree", 0))
    used = max(0, total - available)
    swap_total = values.get("SwapTotal", 0)
    swap_free = values.get("SwapFree", 0)
    return {
        "total_mb": round(total / 1024, 1),
        "used_mb": round(used / 1024, 1),
        "available_mb": round(available / 1024, 1),
        "percent": round(100 * used / total, 1) if total else None,
        "swap_total_mb": round(swap_total / 1024, 1),
        "swap_used_mb": round(max(0, swap_total - swap_free) / 1024, 1),
        "swap_percent": round(100 * (swap_total - swap_free) / swap_total, 1) if swap_total else 0.0,
    }


def _cpu_temperature():
    """Best-effort CPU temperature from hwmon; null when the sensor is unavailable."""
    root = Path("/sys/class/hwmon")
    preferred = []
    try:
        for hwmon in root.glob("hwmon*"):
            try:
                name = (hwmon / "name").read_text(encoding="ascii", errors="replace").strip().lower()
            except OSError:
                name = ""
            for input_path in hwmon.glob("temp*_input"):
                try:
                    milli = int(input_path.read_text(encoding="ascii").strip())
                    celsius = milli / 1000.0
                    if not -20 <= celsius <= 150:
                        continue
                    label_path = input_path.with_name(input_path.name.replace("_input", "_label"))
                    try:
                        label = label_path.read_text(encoding="utf-8", errors="replace").strip().lower()
                    except OSError:
                        label = ""
                    value = round(celsius, 1)
                    if any(token in name for token in ("k10temp", "zenpower", "coretemp", "cpu_thermal")) or any(
                        token in label for token in ("tctl", "tdie", "cpu", "package")
                    ):
                        preferred.append((0 if any(t in label for t in ("tctl", "tdie", "package")) else 1, value))
                except (OSError, ValueError):
                    continue
    except OSError:
        return None
    if preferred:
        preferred.sort(key=lambda item: item[0])
        return preferred[0][1]
    return None


def _number(value):
    try:
        value = str(value).strip()
        if not value or value.lower() in {"n/a", "[not supported]", "not supported", "[n/a]"}:
            return None
        result = float(value)
        return round(result, 1) if result >= 0 else None
    except (TypeError, ValueError):
        return None


_nvidia_smi_path = None
_nvidia_smi_checked = False
_gpu_cache = None
_gpu_cache_time = 0.0


def _gpu():
    global _nvidia_smi_path, _nvidia_smi_checked, _gpu_cache, _gpu_cache_time
    now = time.monotonic()
    if _gpu_cache is not None and (now - _gpu_cache_time) < 4.0:
        return _gpu_cache

    def memory_percent(used, total):
        if used is None or total is None or total <= 0:
            return None
        return round(100.0 * used / total, 1)

    if not _nvidia_smi_checked:
        _nvidia_smi_path = shutil.which("nvidia-smi")
        _nvidia_smi_checked = True
    nvidia_smi = _nvidia_smi_path
    if nvidia_smi:
        try:
            result = subprocess.run(
                [nvidia_smi,
                 "--query-gpu=name,memory.used,memory.total,temperature.gpu,power.draw",
                 "--format=csv,noheader,nounits"],
                capture_output=True, text=True, timeout=2, check=True,
            )
            row = next(csv.reader(result.stdout.splitlines(), skipinitialspace=True), None)
            if row and len(row) >= 5:
                used = _number(row[1])
                total = _number(row[2])
                _gpu_cache = {
                    "available": True,
                    "provider": "NVIDIA",
                    "name": row[0].strip(),
                    "utilization_percent": memory_percent(used, total),
                    "vram_used_mb": used,
                    "vram_total_mb": total,
                    "temperature_c": _number(row[3]),
                    "power_w": _number(row[4]),
                }
                _gpu_cache_time = now
                return _gpu_cache
        except (OSError, subprocess.SubprocessError, csv.Error):
            pass

    # Generic DRM sysfs fallback for AMD/Intel drivers exposing usage counters.
    try:
        for device in sorted(Path("/sys/class/drm").glob("card[0-9]*/device")):
            busy = device / "gpu_busy_percent"
            if not busy.is_file():
                continue

            def read_first(names):
                for name in names:
                    try:
                        return _number((device / name).read_text(encoding="ascii"))
                    except OSError:
                        continue
                return None

            used = read_first(("mem_info_vram_used", "mem_info_gtt_used"))
            total = read_first(("mem_info_vram_total", "mem_info_gtt_total"))

            try:
                name = (device / "product_name").read_text(
                    encoding="utf-8", errors="replace"
                ).strip()
            except OSError:
                name = "DRM Graphics Adapter"

            _gpu_cache = {
                "available": True,
                "provider": "DRM",
                "name": name,
                "utilization_percent": memory_percent(used, total),
                "vram_used_mb": round(used / 1048576, 1) if used is not None else None,
                "vram_total_mb": round(total / 1048576, 1) if total is not None else None,
                "temperature_c": None,
                "power_w": None,
            }
            _gpu_cache_time = now
            return _gpu_cache
    except OSError:
        pass

    _gpu_cache = {
        "available": False,
        "provider": "",
        "name": "",
        "utilization_percent": None,
        "vram_used_mb": None,
        "vram_total_mb": None,
        "temperature_c": None,
        "power_w": None,
    }
    _gpu_cache_time = now
    return _gpu_cache
def _network():
    interface = ""
    # Prefer the interface used by the IPv4 default route to avoid counting virtual bridges.
    try:
        rows = Path("/proc/net/route").read_text(encoding="ascii").splitlines()[1:]
        for row in rows:
            fields = row.split()
            if len(fields) >= 4 and fields[1] == "00000000" and int(fields[3], 16) & 1:
                interface = fields[0]
                break
    except (OSError, ValueError, IndexError):
        pass
    if not interface:
        try:
            for path in sorted(Path("/sys/class/net").iterdir()):
                if path.name == "lo" or path.name.startswith(("docker", "veth", "br-", "virbr")):
                    continue
                try:
                    state = (path / "operstate").read_text(encoding="ascii").strip()
                except OSError:
                    state = ""
                if state == "up":
                    interface = path.name
                    break
        except OSError:
            pass
    try:
        base = Path("/sys/class/net") / interface / "statistics"
        rx = int((base / "rx_bytes").read_text(encoding="ascii"))
        tx = int((base / "tx_bytes").read_text(encoding="ascii"))
        return {"interface": interface, "rx_bytes": rx, "tx_bytes": tx}
    except (OSError, ValueError):
        return {"interface": interface or None, "rx_bytes": 0, "tx_bytes": 0}


_processes_cache = ([], [])
_processes_cache_time = 0.0


def _processes():
    global _processes_cache, _processes_cache_time
    now = time.monotonic()
    if (now - _processes_cache_time) < 4.0 and _processes_cache != ([], []):
        return _processes_cache
    try:
        result = subprocess.run(
            ["ps", "-eo", "pid=,comm=,%cpu=,%mem=", "--sort=-%cpu"],
            capture_output=True, text=True, timeout=1.5, check=True,
        )
    except (OSError, subprocess.SubprocessError):
        return _processes_cache
    parsed = []
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        try:
            parsed.append({"pid": int(parts[0]), "name": parts[1][:40],
                           "cpu_percent": float(parts[-2]), "memory_percent": float(parts[-1])})
        except (ValueError, IndexError):
            continue
    _processes_cache = (parsed[:5], sorted(parsed, key=lambda item: item["memory_percent"], reverse=True)[:5])
    _processes_cache_time = now
    return _processes_cache


def snapshot():
    """Return one JSON-serializable snapshot; unavailable sensors use null values."""
    try:
        load = list(os.getloadavg())
    except (OSError, AttributeError):
        load = [None, None, None]
    try:
        uptime = float(Path("/proc/uptime").read_text(encoding="ascii").split()[0])
    except (OSError, ValueError, IndexError):
        uptime = 0.0
    try:
        disk_usage = shutil.disk_usage("/")
        gib = float(1024 ** 3)
        disk = {"mount": "/", "total_gb": round(disk_usage.total / gib, 1),
                "used_gb": round(disk_usage.used / gib, 1), "free_gb": round(disk_usage.free / gib, 1),
                "percent": round(100 * disk_usage.used / disk_usage.total, 1) if disk_usage.total else None}
    except OSError:
        disk = {"mount": "/", "total_gb": None, "used_gb": None, "free_gb": None, "percent": None}
    cpu = {"percent": _cpu_percent(), "model": _cpu_model(), "cores": os.cpu_count() or 0,
           "temperature_c": _cpu_temperature(), "load1": load[0], "load5": load[1], "load15": load[2]}
    cpu_top, memory_top = _processes()
    import platform
    hostname = os.uname().nodename if hasattr(os, "uname") else platform.node()
    return {
        "sampled_at": time.time(), "hostname": hostname,
        "cpu": cpu, "memory": _memory(), "gpu": _gpu(), "network": _network(),
        "disk": disk, "uptime_seconds": int(uptime),
        "processes_cpu": cpu_top, "processes_memory": memory_top,
    }
