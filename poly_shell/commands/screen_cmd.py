"""Command handler for screen tools (screenshot, record, OCR, QR)."""
from ..adapters.base import SafeRunner
from ..core.state import ROOT


def handle_screen(args) -> int:
    action_map = {
        "region": "screenshot-region",
        "full": "screenshot-full",
        "window": "screenshot-window",
        "satty": "screenshot-satty",
        "ocr": "ocr",
        "qr": "qr",
        "record": "record-start",
        "stop-record": "record-stop",
    }
    cmd = [str(ROOT / "scripts" / "screen-tools.sh"), action_map.get(args.action, "screenshot-region")]
    if getattr(args, "with_audio", False):
        cmd.append("--with-audio")
    res = SafeRunner.run(cmd, timeout=30.0)
    return res.returncode

