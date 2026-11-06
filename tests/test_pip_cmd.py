import argparse
import unittest
from unittest.mock import patch, MagicMock

from poly_shell.commands.pip_cmd import (
    PRESET_URLS,
    DEFAULT_SIZES,
    detect_browser,
    launch_video_pip,
    handle_pip,
)


class TestPipCmd(unittest.TestCase):
    def test_presets_and_sizes(self):
        self.assertIn("tiktok", PRESET_URLS)
        self.assertIn("shorts", PRESET_URLS)
        self.assertIn("youtube", PRESET_URLS)

        self.assertEqual(DEFAULT_SIZES["vertical"], (360, 640))
        self.assertEqual(DEFAULT_SIZES["landscape"], (540, 304))

    @patch("shutil.which")
    def test_detect_browser_found(self, mock_which):
        mock_which.side_effect = lambda cmd: "/usr/bin/chromium" if cmd == "chromium" else None
        browser = detect_browser()
        self.assertEqual(browser, "/usr/bin/chromium")

    @patch("shutil.which")
    def test_detect_browser_none(self, mock_which):
        mock_which.return_value = None
        browser = detect_browser()
        self.assertIsNone(browser)

    @patch("poly_shell.commands.pip_cmd.detect_browser")
    @patch("subprocess.Popen")
    def test_launch_video_pip_vertical_tiktok(self, mock_popen, mock_detect):
        mock_detect.return_value = "/usr/bin/chromium"
        res = launch_video_pip("tiktok")
        self.assertEqual(res, 0)
        mock_popen.assert_called_once()
        cmd = mock_popen.call_args[0][0]
        self.assertIn("/usr/bin/chromium", cmd)
        self.assertTrue(any("--app=https://www.tiktok.com" in arg for arg in cmd))
        self.assertTrue(any("--class=alpora-pip-vertical" in arg for arg in cmd))
        self.assertTrue(any("--window-size=360,640" in arg for arg in cmd))

    @patch("poly_shell.commands.pip_cmd.detect_browser")
    @patch("subprocess.Popen")
    def test_launch_video_pip_landscape_youtube(self, mock_popen, mock_detect):
        mock_detect.return_value = "/usr/bin/chromium"
        res = launch_video_pip("youtube")
        self.assertEqual(res, 0)
        mock_popen.assert_called_once()
        cmd = mock_popen.call_args[0][0]
        self.assertTrue(any("--class=alpora-pip-landscape" in arg for arg in cmd))
        self.assertTrue(any("--window-size=540,304" in arg for arg in cmd))

    @patch("poly_shell.commands.pip_cmd.launch_video_pip")
    def test_handle_pip_cli(self, mock_launch):
        mock_launch.return_value = 0
        args = argparse.Namespace(
            target="shorts",
            mode="vertical",
            width=400,
            height=700
        )
        res = handle_pip(args)
        self.assertEqual(res, 0)
        mock_launch.assert_called_once_with(target="shorts", mode="vertical", width=400, height=700)


if __name__ == "__main__":
    unittest.main()

