"""Persistence and rollback checks; these do not touch the real desktop."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from poly_shell.integration import BEGIN, END, managed_autostart, patch_autostart, restore_autostart
from poly_shell.state import ConfigError, Paths, atomic_json, defaults, read_object, update_session


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.paths = Paths(root / "config", root / "state", root / "runtime")

    def test_mode_survives_refresh_and_settings_remain_separate(self):
        update_session(self.paths)
        settings = self.paths.config / "settings.json"
        before = settings.read_bytes()
        update_session(self.paths, "vibe")
        self.assertEqual(update_session(self.paths)["mode"], "vibe")
        self.assertEqual(settings.read_bytes(), before)

    def test_visual_selection_survives_behavior_mode_switch(self):
        atomic_json(self.paths.config / "appearance.json", {"schemaVersion": 1, "theme": "alpine"})
        before = (self.paths.config / "appearance.json").read_bytes()
        work = update_session(self.paths, "work")
        vibe = update_session(self.paths, "vibe")
        self.assertEqual(work["appearance"], vibe["appearance"])
        self.assertEqual(vibe["appearance"]["iconTheme"], "Poly-Alpine")
        self.assertEqual((self.paths.config / "appearance.json").read_bytes(), before)
        self.assertNotEqual(work["profile"]["palette"], vibe["profile"]["palette"])

    def test_unknown_or_invalid_theme_keeps_working_fallback(self):
        for selection in ("missing-theme", "../../other", 42):
            atomic_json(self.paths.config / "appearance.json", {"theme": selection})
            self.assertEqual(update_session(self.paths)["appearance"]["id"], "alpine")

    def test_failed_write_keeps_previous_snapshot(self):
        update_session(self.paths)
        before = self.paths.session.read_bytes()
        with patch("poly_shell.state.os.replace", side_effect=OSError("disk failure")):
            with self.assertRaises(OSError):
                update_session(self.paths, "vibe")
        self.assertEqual(self.paths.session.read_bytes(), before)
        self.assertEqual(sorted(p.name for p in self.paths.state.iterdir()), ["session.json", "state.lock"])

    def test_invalid_settings_do_not_change_mode(self):
        update_session(self.paths)
        bad = defaults()
        bad["apps"]["terminal"] = "kitty; arbitrary shell command"
        atomic_json(self.paths.config / "settings.json", bad)
        before = self.paths.session.read_bytes()
        with self.assertRaises(ConfigError):
            update_session(self.paths, "vibe")
        self.assertEqual(self.paths.session.read_bytes(), before)

    def test_corrupt_saved_state_is_preserved(self):
        self.paths.state.mkdir()
        self.paths.session.write_text("broken JSON")
        with self.assertRaises(ConfigError):
            update_session(self.paths, "work")
        self.assertEqual(self.paths.session.read_text(), "broken JSON")

    def test_user_profile_overrides_only_selected_fields(self):
        atomic_json(self.paths.config / "profiles/vibe.json", {"motionMs": 0, "palette": {"accent": "#abcdef"}})
        result = update_session(self.paths, "vibe")
        self.assertEqual(result["profile"]["motionMs"], 0)
        self.assertEqual(result["profile"]["palette"]["accent"], "#abcdef")
        self.assertIn("background", result["profile"]["palette"])

    def test_unknown_mode_cannot_escape_profiles_directory(self):
        with self.assertRaises(ConfigError):
            update_session(self.paths, "../../other")
        self.assertFalse(self.paths.session.exists())

    def test_simultaneous_toggles_are_serialized(self):
        update_session(self.paths, "work")
        with ThreadPoolExecutor(max_workers=4) as executor:
            list(executor.map(lambda _: update_session(self.paths, "toggle"), range(10)))
        self.assertEqual(read_object(self.paths.session)["mode"], "work")
        json.loads(self.paths.session.read_text(encoding="utf-8"))


class AutostartTests(unittest.TestCase):
    def test_actual_backup_and_rollback_preserve_later_user_edits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = Paths(root / "config/poly-shell", root / "state", root / "runtime")
            target = root / "config/hypr/autostart.sh"
            target.parent.mkdir(parents=True)
            original = '#!/bin/bash\nwaybar -c "$config_dir/waybar.jsonc" &\nmako &\n'
            target.write_text(original)
            patch_autostart(paths)
            manifest = read_object(paths.state / "activation.json")
            self.assertEqual(Path(manifest["backup"]).read_text(), original)
            target.write_text(target.read_text() + "# later user edit\n")
            restore_autostart(paths)
            self.assertEqual(target.read_text(), original + "# later user edit\n")

    def test_rollback_preserves_a_manually_edited_managed_block(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = Paths(root / "config/poly-shell", root / "state", root / "runtime")
            target = root / "config/hypr/autostart.sh"
            target.parent.mkdir(parents=True)
            target.write_text("waybar &\n")
            patch_autostart(paths)
            edited = target.read_text().replace(" start;", " start --custom;")
            target.write_text(edited)
            with self.assertRaises(ConfigError):
                restore_autostart(paths)
            self.assertEqual(target.read_text(), edited)

    def test_handover_is_idempotent_and_leaves_services_alone(self):
        original = '#!/bin/bash\nwaybar -c "$config_dir/waybar.jsonc" &\nmako &\nhypridle &\n'
        modified = managed_autostart(original, Path("/home/a user/.local/bin/poly-shell"))
        self.assertEqual(managed_autostart(modified, Path("/unused")), modified)
        self.assertIn("mako &\nhypridle &", modified)
        self.assertIn("'/home/a user/.local/bin/poly-shell' start", modified)
        self.assertEqual(modified.count(BEGIN), 1)
        self.assertEqual(modified.count(END), 1)
        self.assertIn('    waybar -c "$config_dir/waybar.jsonc" &', modified)

    def test_ambiguous_autostart_is_rejected(self):
        for text in ("mako &\n", "waybar &\nwaybar -c second.json &\n", BEGIN + "\n"):
            with self.subTest(text=text), self.assertRaises(ConfigError):
                managed_autostart(text, Path("/some/launcher"))


if __name__ == "__main__":
    unittest.main()
