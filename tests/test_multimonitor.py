"""Tests for multi-monitor layouts, fractional scaling, and hotplug edge cases."""
import math
import unittest


def widget_bounds(setting, width, height, top, natural_w, natural_h):
    """Python model of shell/logic/WidgetGeometry.js boundsForSize."""
    safe_setting = setting or {"x": 50, "y": 50}
    scale = max(0.25, min(1.0, width / 1000.0, height / 800.0)) if width > 0 and height > 0 else 0.25
    margin = 20.0 * scale
    w = min(natural_w * scale, max(1.0, width - margin * 2))
    h = min(natural_h * scale, max(1.0, height - top - margin))
    origin = min(top, max(0.0, height - h - margin))
    x_pos = margin + max(0.0, width - margin * 2 - w) * safe_setting.get("x", 50) / 100.0
    y_pos = origin + max(0.0, min(safe_setting.get("y", 50) * scale, height - origin - margin - h))
    return {
        "x": x_pos,
        "y": y_pos,
        "width": w,
        "height": h,
        "scale": scale,
        "margin": margin,
        "top": origin,
    }


def landscape_layout(width, height):
    """Python model of shell/logic/LandscapeGeometry.js layout scaling."""
    scale = max(0.72, min(1.35, min(width / 1920.0, height / 1080.0))) if width > 0 and height > 0 else 0.72
    return {"scale": scale}


class MultiMonitorTests(unittest.TestCase):
    def test_standard_fhd_1080p(self):
        b = widget_bounds({"x": 50, "y": 100}, 1920, 1080, 48, 460, 200)
        self.assertAlmostEqual(b["scale"], 1.0)
        self.assertEqual(b["width"], 460)
        self.assertEqual(b["height"], 200)
        self.assertGreater(b["x"], 0)
        self.assertLess(b["x"] + b["width"], 1920)

    def test_fractional_scaling_display_resolutions(self):
        # 1080p at 1.25x effective viewport: 1536 x 864
        # 1440p at 1.25x effective viewport: 2048 x 1152
        # 4K at 1.5x effective viewport: 2560 x 1440
        # 4K at 1.75x effective viewport: 2194 x 1234
        resolutions = [
            (1536, 864),
            (2048, 1152),
            (2560, 1440),
            (2194, 1234),
        ]
        for w, h in resolutions:
            with self.subTest(width=w, height=h):
                b = widget_bounds({"x": 50, "y": 50}, w, h, 48, 460, 200)
                self.assertGreater(b["scale"], 0)
                self.assertLessEqual(b["scale"], 1.0)
                self.assertGreater(b["x"], 0)
                self.assertLessEqual(b["x"] + b["width"], w)
                self.assertLessEqual(b["y"] + b["height"], h)

    def test_ultrawide_aspect_ratio_21_9(self):
        # 3440 x 1440 ultrawide
        b = widget_bounds({"x": 0, "y": 0}, 3440, 1440, 48, 410, 206)
        self.assertEqual(b["x"], b["margin"])
        self.assertLess(b["width"], 3440)
        ls = landscape_layout(3440, 1440)
        self.assertLessEqual(ls["scale"], 1.35)

    def test_portrait_mode_9_16(self):
        # 1080 x 1920 vertical monitor
        b = widget_bounds({"x": 50, "y": 50}, 1080, 1920, 48, 390, 360)
        self.assertGreater(b["x"], 0)
        self.assertLess(b["x"] + b["width"], 1080)
        self.assertLess(b["y"] + b["height"], 1920)

    def test_hotplug_zero_sized_screen_does_not_crash_or_divide_by_zero(self):
        # When a secondary monitor is unplugged, Wayland may temporarily report 0x0
        b = widget_bounds({"x": 50, "y": 50}, 0, 0, 48, 460, 200)
        self.assertEqual(b["scale"], 0.25)
        self.assertGreaterEqual(b["width"], 1.0)
        self.assertGreaterEqual(b["height"], 1.0)

    def test_null_or_missing_setting_uses_safe_fallback(self):
        b = widget_bounds(None, 1920, 1080, 48, 460, 200)
        self.assertGreater(b["width"], 0)
        self.assertGreater(b["height"], 0)


if __name__ == "__main__":
    unittest.main()
