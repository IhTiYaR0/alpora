"""Command handler for Digital Wellbeing queries."""
import json
from ..services.wellbeing import WellbeingTracker


def handle_wellbeing(paths, args) -> int:
    tracker = WellbeingTracker(paths)
    summary = tracker.get_summary(args.date or "")
    if getattr(args, "json", False):
        print(json.dumps(summary, indent=2, ensure_ascii=False))
    else:
        mins = summary.get("total_minutes", 0)
        hrs = int(mins // 60)
        rem_mins = int(mins % 60)
        print(f"ALPORA Digital Wellbeing [{summary.get('date')}]: {hrs}h {rem_mins}m total screen time")
        for app in summary.get("apps", []):
            app_mins = app.get("minutes", 0)
            print(f"  • {app['name']}: {app_mins:.1f}m")
    return 0

