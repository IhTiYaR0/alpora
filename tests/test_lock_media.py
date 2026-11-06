"""Unit tests for poly_shell.lock_media."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import MagicMock, patch

from poly_shell.lock_media import (
    TRANSPARENT_1X1_PNG,
    get_art,
    get_artist,
    get_controls,
    get_status,
    get_title,
    handle_cli,
)


class LockMediaTests(unittest.TestCase):
    def test_transparent_png_bytes(self):
        self.assertTrue(TRANSPARENT_1X1_PNG.startswith(b"\x89PNG\r\n\x1a\n"))

    @patch("poly_shell.lock_media.get_status", return_value="Playing")
    @patch("poly_shell.lock_media.subprocess.run")
    def test_get_title_playing(self, mock_run, mock_status):
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_proc.stdout = "Starboy (feat. Daft Punk)\n"
        mock_run.return_value = mock_proc
        self.assertEqual(get_title(), "Starboy (feat. Daft Punk)")

    @patch("poly_shell.lock_media.get_status", return_value="Playing")
    @patch("poly_shell.lock_media.subprocess.run")
    def test_get_title_truncated(self, mock_run, mock_status):
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_proc.stdout = "A" * 50 + "\n"
        mock_run.return_value = mock_proc
        title = get_title(max_len=20)
        self.assertEqual(len(title), 20)
        self.assertTrue(title.endswith("…"))

    @patch("poly_shell.lock_media.get_status", return_value="")
    def test_get_title_stopped_empty(self, mock_status):
        self.assertEqual(get_title(), "")

    @patch("poly_shell.lock_media.get_status", return_value="Playing")
    @patch("poly_shell.lock_media.subprocess.run")
    def test_get_artist_playing(self, mock_run, mock_status):
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_proc.stdout = "The Weeknd\n"
        mock_run.return_value = mock_proc
        self.assertEqual(get_artist(), "The Weeknd")

    @patch("poly_shell.lock_media.get_status")
    def test_get_controls(self, mock_status):
        mock_status.return_value = "Playing"
        self.assertIn("󰏤", get_controls())

        mock_status.return_value = "Paused"
        self.assertIn("󰐊", get_controls())

        mock_status.return_value = "Stopped"
        self.assertEqual(get_controls(), "")

        mock_status.return_value = ""
        self.assertEqual(get_controls(), "")

    def test_get_art_fallback_transparent(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            target = Path(tmpdir) / "lock-art.png"
            with patch("poly_shell.lock_media.get_status", return_value=""):
                path_str = get_art(target)
                self.assertEqual(path_str, str(target))
                self.assertTrue(target.is_file())
                self.assertEqual(target.read_bytes(), TRANSPARENT_1X1_PNG)

    def test_get_art_local_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            sample_art = Path(tmpdir) / "sample_cover.jpg"
            sample_art.write_bytes(b"FAKE_IMAGE_DATA_12345")
            target = Path(tmpdir) / "lock-art.png"

            with patch("poly_shell.lock_media.get_status", return_value="Playing"):
                with patch("poly_shell.lock_media.subprocess.run") as mock_run:
                    mock_proc = MagicMock()
                    mock_proc.returncode = 0
                    mock_proc.stdout = f"file://{sample_art.as_posix()}\n"
                    mock_run.return_value = mock_proc

                    path_str = get_art(target)
                    self.assertEqual(path_str, str(target))
                    self.assertEqual(target.read_bytes(), b"FAKE_IMAGE_DATA_12345")


if __name__ == "__main__":
    unittest.main()
