"""Command handler for system diagnostics and preflight checks."""
import json
from pathlib import Path
from ..system.diagnostics import collect_diagnostic_bundle
from ..system.preflight import run_preflight, format_preflight_report


def handle_doctor(paths, args) -> int:
    if getattr(args, "bundle", False):
        out = Path(args.output) if getattr(args, "output", None) else None
        archive = collect_diagnostic_bundle(paths, output_dir=out)
        print(f"Diagnostic bundle written to: {archive}")
        return 0
    from ..system.programs import inventory
    items = inventory()
    print(json.dumps(items, indent=2, ensure_ascii=False))
    has_missing_required = any(item.get("required") and not item.get("available") for item in items)
    return 1 if has_missing_required else 0


def handle_preflight(paths, args) -> int:
    report = run_preflight(paths)
    if getattr(args, "json", False):
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        print(format_preflight_report(report))
    return 0 if report.get("ready") else 1
