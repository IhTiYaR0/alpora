"""CLI subcommand handlers for ALPORA Command Pattern."""
from .screen_cmd import handle_screen
from .wellbeing_cmd import handle_wellbeing
from .doctor_cmd import handle_doctor, handle_preflight
from .exe_cmd import handle_exe
from .pip_cmd import handle_pip
from .tasks_cmd import handle_tasks, handle_task_manager, open_task_manager
from .shortcuts_cmd import handle_shortcuts
from .organizer_cmd import handle_organizer
from .desktop_cmd import (
    handle_control,
    handle_wallpaper,
    handle_project,
    handle_dotfiles,
    handle_windows_drives,
    handle_osd,
    handle_lock_date,
    handle_lock_media,
)
from .demo_cmd import handle_demo
from .game_cmd import handle_game
from .phone_cmd import handle_phone
from .panel_cmd import (
    handle_launcher,
    handle_quick_settings,
    handle_notifications,
    handle_clipboard,
    handle_overview,
    handle_power_menu,
    handle_toggle_mode,
    handle_display_project,
    handle_welcome,
    open_welcome,
)
from .theme_cmd import (
    handle_theme,
    handle_timeline,
    handle_widgets,
    handle_appearance,
    handle_palette_extract,
    handle_assets,
    handle_toolkit_refresh,
)

__all__ = [
    "handle_screen",
    "handle_wellbeing",
    "handle_doctor",
    "handle_preflight",
    "handle_exe",
    "handle_pip",
    "handle_tasks",
    "handle_task_manager",
    "open_task_manager",
    "handle_shortcuts",
    "handle_organizer",
    "handle_control",
    "handle_wallpaper",
    "handle_project",
    "handle_dotfiles",
    "handle_windows_drives",
    "handle_osd",
    "handle_lock_date",
    "handle_lock_media",
    "handle_theme",
    "handle_timeline",
    "handle_widgets",
    "handle_appearance",
    "handle_palette_extract",
    "handle_assets",
    "handle_toolkit_refresh",
    "handle_demo",
    "handle_game",
    "handle_phone",
    "handle_launcher",
    "handle_quick_settings",
    "handle_notifications",
    "handle_clipboard",
    "handle_overview",
    "handle_power_menu",
    "handle_toggle_mode",
    "handle_display_project",
    "handle_welcome",
    "open_welcome",
]
