"""Appearance validation, concurrent edits, runtime confirmation and rollback."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from poly_shell import appearance
from poly_shell.state import ConfigError, Paths, atomic_json, read_object, update_session
from poly_shell.visual import DEFAULTS, validate, visual_for, lua_for


class AppearanceTests(unittest.TestCase):
    def test_old_geometry_and_launcher_rounding_migrate_without_reset(self):
        settings = read_object(self.paths.config / "settings.json")
        settings["bar"].update(height=72, top=60, margin=3)
        atomic_json(self.paths.config / "settings.json", settings)
        atomic_json(self.paths.config / "visual.json", {"schemaVersion": 1, "values": {"panelRadius": 27}})
        values = visual_for(self.paths)
        self.assertEqual((values["barHeight"], values["barTop"], values["barMargin"], values["launcherRadius"]), (72, 60, 3, 27))
        self.assertEqual((values["barLeft"], values["barRight"], values["barBottom"]), (3, 3, 8))
        appearance.apply(self.paths, values, expected=values)
        self.assertEqual(visual_for(self.paths), values)

    def test_new_controls_reject_bad_types_and_ranges_before_mutation(self):
        before = self.paths.session.read_bytes()
        for values in ({"widgetAnimations": 1}, {"panelBorder": 4}, {"panelPadding": 100},
                       {"launcherCloseMs": -1}, {"widgetOpacity": "50"}, {"barTop": 65},
                       {"notificationShadow": 101}, {"widgetFadeMs": True},
                       {"windowGap": -1}, {"windowMargin": 129}, {"barLeft": 129},
                       {"barRight": True}, {"barBottom": 129}):
            with self.subTest(values=values), self.assertRaises(ConfigError):
                appearance.apply(self.paths, values)
        self.apply_runtime.assert_not_called()
        self.assertEqual(self.paths.session.read_bytes(), before)

    def test_element_controls_survive_reload_and_modes(self):
        patch_values = {"panelPadding": 24, "panelBorder": 0, "widgetOpacity": 65,
                        "widgetAnimations": False, "launcherRadius": 9, "launcherOpenMs": 0,
                        "notificationRadius": 22, "barHeight": 56,
                        "barLeft": 0, "barRight": 47, "barBottom": 26,
                        "windowGap": 0, "windowMargin": 38}
        appearance.apply(self.paths, patch_values)
        for mode in ("work", "vibe"):
            snapshot = update_session(self.paths, mode)
            self.assertEqual({key: snapshot["visual"][key] for key in patch_values}, patch_values)

    def test_notification_style_saved_with_appearance_and_rolled_back(self):
        appearance.apply(self.paths, {"notificationOpacity": 80, "notificationPadding": 22, "notificationRadius": 9})
        style = self.paths.state / "mako-theme.conf"
        original = style.read_bytes()
        self.assertIn(b"border-radius=9", original)
        self.assertIn(b"padding=22", original)
        self.assertTrue(b"cc\ntext-color=" in original or b"cc\r\ntext-color=" in original)
        files = [style, self.paths.config / "visual.json", appearance.generated_path(self.paths), self.paths.session]
        before = {path: path.read_bytes() for path in files}
        original_write = appearance.atomic_json
        def fail_publication(path, value):
            if path == self.paths.session:
                raise OSError("publication failed")
            original_write(path, value)
        with patch.object(appearance, "atomic_json", side_effect=fail_publication):
            with self.assertRaises(ConfigError):
                appearance.apply(self.paths, {"notificationPadding": 6})
        self.assertEqual({path: path.read_bytes() for path in files}, before)

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.paths = Paths(root / "config/poly-shell", root / "state", root / "runtime")
        update_session(self.paths)
        self.runtime = patch("poly_shell.appearance.runtime_apply")
        self.apply_runtime = self.runtime.start()
        self.addCleanup(self.runtime.stop)

    def test_invalid_values_never_touch_runtime_or_saved_state(self):
        before = self.paths.session.read_bytes()
        for values in ({"windowRadius": -1}, {"barRadius": 21}, {"panelOpacity": 0},
                       {"blurPasses": 3}, {"blurSize": True}, {"blurSize": 2.5},
                       {"blurEnabled": 1}, {"blurSize": "1); os.execute('bad')"},
                       {"unknown": 1}, None, []):
            with self.subTest(values=values), self.assertRaises(ConfigError):
                appearance.apply(self.paths, values)
        self.apply_runtime.assert_not_called()
        self.assertEqual(self.paths.session.read_bytes(), before)

    def test_apply_refresh_and_modes_keep_visual_values_and_unrelated_settings(self):
        settings_file = self.paths.config / "settings.json"
        before = settings_file.read_bytes()
        appearance.apply(self.paths, {"windowRadius": 24, "blurEnabled": False})
        for mode in ("work", "vibe", "work"):
            snapshot = update_session(self.paths, mode)
            self.assertEqual(snapshot["visual"]["windowRadius"], 24)
            self.assertFalse(snapshot["visual"]["blurEnabled"])
        self.assertEqual(settings_file.read_bytes(), before)
        self.assertIn("rounding = 24", appearance.generated_path(self.paths).read_text())

    def test_stale_draft_is_rejected_instead_of_overwriting_another_window(self):
        appearance.apply(self.paths, {"barOpacity": 90}, expected=dict(DEFAULTS))
        with self.assertRaisesRegex(ConfigError, "другом окне"):
            appearance.apply(self.paths, {"windowRadius": 20}, expected=dict(DEFAULTS))
        self.assertEqual(visual_for(self.paths)["barOpacity"], 90)

    def test_reset_is_a_real_apply_and_does_not_change_mode(self):
        update_session(self.paths, "vibe")
        appearance.apply(self.paths, {"panelOpacity": 90})
        result = appearance.appearance_control(self.paths, "reset", {})
        self.assertEqual(result["values"], DEFAULTS)
        self.assertEqual(read_object(self.paths.session)["mode"], "vibe")

    def test_runtime_rejection_restores_original_files_and_runtime(self):
        appearance.apply(self.paths, {"barOpacity": 85})
        files = [self.paths.session, self.paths.config / "visual.json", appearance.generated_path(self.paths)]
        before = {p: p.read_bytes() for p in files}
        old = visual_for(self.paths)
        self.apply_runtime.side_effect = [ConfigError("runtime failed"), None]
        with self.assertRaisesRegex(ConfigError, "не сохранены"):
            appearance.apply(self.paths, {"windowRadius": 30})
        self.assertEqual({p: p.read_bytes() for p in files}, before)
        self.assertEqual(self.apply_runtime.call_args.args[0], old)

    def test_failure_at_each_persist_step_restores_all_files(self):
        appearance.apply(self.paths, {"windowRadius": 23})
        files = [self.paths.session, self.paths.config / "visual.json", appearance.generated_path(self.paths)]
        original_json, original_text = appearance.atomic_json, appearance.atomic_text
        before = {p: p.read_bytes() for p in files}
        for fail_path in files:
            def write_json(path, value):
                if path == fail_path:
                    raise OSError("disk failure")
                original_json(path, value)
            def write_text(path, value):
                if path == fail_path and "rounding = 30" in value:
                    raise OSError("disk failure")
                original_text(path, value)
            with self.subTest(path=fail_path), patch.object(appearance, "atomic_json", side_effect=write_json), patch.object(appearance, "atomic_text", side_effect=write_text):
                with self.assertRaisesRegex(ConfigError, "disk failure"):
                    appearance.apply(self.paths, {"windowRadius": 30})
            self.assertEqual({p: p.read_bytes() for p in files}, before)

    def test_first_apply_failure_removes_new_files(self):
        before = self.paths.session.read_bytes()
        with patch.object(appearance, "atomic_json", side_effect=OSError("disk full")):
            with self.assertRaises(ConfigError):
                appearance.apply(self.paths, {"windowRadius": 30})
        self.assertFalse((self.paths.config / "visual.json").exists())
        self.assertFalse(appearance.generated_path(self.paths).exists())
        self.assertEqual(self.paths.session.read_bytes(), before)

    def test_corrupt_controls_do_not_replace_valid_session(self):
        before = self.paths.session.read_bytes()
        atomic_json(self.paths.config / "visual.json", {"schemaVersion": 1, "values": {"blurSize": 1000}})
        with self.assertRaises(ConfigError):
            update_session(self.paths)
        self.assertEqual(self.paths.session.read_bytes(), before)

    def test_hook_install_is_idempotent_preserves_config_and_backs_up(self):
        config = self.paths.config.parent / "hypr/hyprland.lua"
        config.parent.mkdir(parents=True)
        original = "-- user config\nhl.config({ decoration = { rounding = 16 } })\n"
        config.write_text(original)
        result = appearance.install_hook(self.paths)
        self.assertEqual(Path(result["backup"]).read_text(), original)
        self.assertTrue(config.read_text().startswith(original))
        appearance.install_hook(self.paths)
        self.assertEqual(config.read_text().count(appearance.HOOK_BEGIN), 1)
        config.write_text(config.read_text().replace("dofile(file)", "dofile(other)"))
        edited = config.read_bytes()
        with self.assertRaises(ConfigError):
            appearance.install_hook(self.paths)
        self.assertEqual(config.read_bytes(), edited)

    def test_settings_rule_upgrade_locks_size_and_preserves_other_config(self):
        config = self.paths.config.parent / "hypr/hyprland.lua"
        config.parent.mkdir(parents=True)
        original = "-- personal bindings\n" + appearance.HOOK + "\n" + appearance.LEGACY_SETTINGS_RULE
        config.write_text(original)
        result = appearance.install_hook(self.paths)
        self.assertEqual(Path(result["backup"]).read_text(), original)
        updated = config.read_text()
        self.assertTrue(updated.startswith("-- personal bindings\n"))
        self.assertIn(appearance.SETTINGS_RULE, updated)
        self.assertIn('min_size = { 1100, 800 }', updated)
        self.assertIn('max_size = { 1100, 800 }', updated)
        self.assertIn('suppress_event = "maximize fullscreen fullscreenoutput"', updated)
        appearance.install_hook(self.paths)
        self.assertEqual(config.read_text(), updated)

    def test_formatted_hook_is_preserved_while_cached_blur_is_upgraded(self):
        config = self.paths.config.parent / "hypr/hyprland.lua"
        config.parent.mkdir(parents=True)
        formatted = appearance.HOOK.replace('    ', '\t').replace('then handle:close(); dofile(file) end', 'then\n\t\thandle:close()\n\t\tdofile(file)\n\tend')
        # The formatter removes the optional separator between statements.
        config.write_text(formatted + appearance.CACHED_PANEL_RULE)
        appearance.install_hook(self.paths)
        self.assertIn(formatted, config.read_text())
        self.assertIn(appearance.PANEL_RULE, config.read_text())

    def test_panel_blur_upgrade_preserves_config_and_is_idempotent(self):
        config = self.paths.config.parent / "hypr/hyprland.lua"
        config.parent.mkdir(parents=True)
        original = "-- personal bindings\n" + appearance.HOOK + appearance.LEGACY_PANEL_RULE
        config.write_text(original)
        result = appearance.install_hook(self.paths)
        self.assertEqual(Path(result["backup"]).read_text(), original)
        updated = config.read_text()
        self.assertTrue(updated.startswith("-- personal bindings\n"))
        self.assertIn(appearance.PANEL_RULE, updated)
        self.assertNotIn(appearance.LEGACY_PANEL_RULE, updated)
        appearance.install_hook(self.paths)
        self.assertEqual(config.read_text(), updated)

    def test_cached_blur_rules_upgrade_to_natural_blur_preserves_config_and_backup(self):
        config = self.paths.config.parent / "hypr/hyprland.lua"
        config.parent.mkdir(parents=True)
        original = "-- personal bindings\n" + appearance.HOOK + appearance.CACHED_PANEL_RULE
        config.write_text(original)
        result = appearance.install_hook(self.paths)
        self.assertEqual(Path(result["backup"]).read_text(), original)
        updated = config.read_text()
        self.assertTrue(updated.startswith("-- personal bindings\n"))
        self.assertIn(appearance.PANEL_RULE, updated)
        self.assertEqual(updated.count("ignore_alpha = 0.05, xray = false"), 3)
        appearance.install_hook(self.paths)
        self.assertEqual(config.read_text(), updated)

    def test_runtime_confirmation_checks_actual_compositor_values(self):
        self.runtime.stop()
        def reply(*args):
            if args[0] == "eval": return "ok\n"
            if args[-1] == "decoration:rounding": return json.dumps({"int": 7})
            raise AssertionError("Should fail on first readback mismatch")
        with patch.object(appearance, "hypr", side_effect=reply), patch.dict("os.environ", {"HYPRLAND_INSTANCE_SIGNATURE": "fake"}):
            with self.assertRaisesRegex(ConfigError, "не подтвердил"):
                appearance.runtime_apply(deepcopy(DEFAULTS))

    def test_native_ipc_accepts_boolean_float_and_integer_reply_shapes(self):
        self.runtime.stop()
        replies = {
            "decoration:rounding": {"int": 16},
            "decoration:active_opacity": {"float": 1.0},
            "decoration:inactive_opacity": {"float": 1.0},
            "decoration:blur:enabled": {"bool": True},
            "decoration:blur:size": {"int": 3},
            "decoration:blur:passes": {"int": 1},
            "render:new_render_scheduling": {"bool": True},
            "general:gaps_in": {"css": "5 5 5 5"},
            "general:gaps_out": {"css": "12 12 12 12"},
        }
        def reply(*args):
            if args[0] == "eval":
                self.assertFalse(args[1].startswith("--"), "hyprctl parses this as a CLI flag")
                return "ok\n"
            return json.dumps(replies[args[-1]])
        with patch.object(appearance, "hypr", side_effect=reply), patch.dict("os.environ", {"HYPRLAND_INSTANCE_SIGNATURE": "fake"}):
            appearance.runtime_apply(deepcopy(DEFAULTS))

    def test_gap_readback_mismatch_is_not_reported_as_saved(self):
        self.runtime.stop()
        def reply(*args):
            if args[0] == "eval": return "ok\n"
            if args[-1] == "general:gaps_in": return json.dumps({"css": "5 9 5 9"})
            if args[-1] == "general:gaps_out": return json.dumps({"css": "12"})
            if args[-1] == "render:new_render_scheduling": return json.dumps({"bool": True})
            mapping = {"decoration:rounding": 16, "decoration:active_opacity": 1,
                       "decoration:inactive_opacity": 1, "decoration:blur:enabled": 1,
                       "decoration:blur:size": 3, "decoration:blur:passes": 1}
            return json.dumps({"int": mapping[args[-1]]})
        with patch.object(appearance, "hypr", side_effect=reply), patch.dict("os.environ", {"HYPRLAND_INSTANCE_SIGNATURE": "fake"}):
            with self.assertRaisesRegex(ConfigError, "general:gaps_in"):
                appearance.runtime_apply(dict(DEFAULTS))

    def test_gap_changes_are_persistent_and_rollback_on_publication_failure(self):
        appearance.apply(self.paths, {"windowGap": 17, "windowMargin": 33})
        self.assertIn("gaps_in = 17, gaps_out = 33", appearance.generated_path(self.paths).read_text())
        before = visual_for(self.paths)
        original = appearance.atomic_json
        def fail(path, value):
            if path == self.paths.session: raise OSError("publication failed")
            original(path, value)
        with patch.object(appearance, "atomic_json", side_effect=fail):
            with self.assertRaises(ConfigError):
                appearance.apply(self.paths, {"windowGap": 0, "windowMargin": 0})
        self.assertEqual(visual_for(self.paths), before)
        self.assertEqual(self.apply_runtime.call_args.args[0], before)
        self.assertIn("gaps_in = 0, gaps_out = 0", lua_for(dict(DEFAULTS, windowGap=0, windowMargin=0)))
