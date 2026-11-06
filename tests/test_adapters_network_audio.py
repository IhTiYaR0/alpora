import subprocess
import unittest
from unittest.mock import patch

from poly_shell.adapters.audio import AudioAdapter
from poly_shell.adapters.network import NetworkAdapter


class TestAudioAndNetworkAdapters(unittest.TestCase):
    @patch("poly_shell.adapters.base.SafeRunner.is_available", return_value=True)
    @patch("poly_shell.adapters.base.SafeRunner.run")
    def test_audio_get_volume_success(self, mock_run, mock_avail):
        mock_run.return_value = subprocess.CompletedProcess(
            args=["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
            returncode=0,
            stdout="Volume: 0.72\n",
            stderr="",
        )
        vol = AudioAdapter.get_volume()
        self.assertAlmostEqual(vol, 0.72)

    @patch("poly_shell.adapters.base.SafeRunner.is_available", return_value=False)
    def test_audio_get_volume_unavailable(self, mock_avail):
        vol = AudioAdapter.get_volume()
        self.assertEqual(vol, 0.0)

    @patch("poly_shell.adapters.base.SafeRunner.run")
    def test_audio_set_volume(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        success = AudioAdapter.set_volume(85)
        self.assertTrue(success)
        mock_run.assert_called_with(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "85%"], timeout=3.0)

    @patch("poly_shell.adapters.base.SafeRunner.run")
    def test_audio_player_control_security(self, mock_run):
        # Invalid / unauthorized action should be rejected immediately
        self.assertFalse(AudioAdapter.player_control("malicious_command; rm -rf"))
        mock_run.assert_not_called()

        # Valid action allowed
        mock_run.return_value = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        self.assertTrue(AudioAdapter.player_control("play-pause"))

    @patch("poly_shell.adapters.base.SafeRunner.is_available", return_value=True)
    @patch("poly_shell.adapters.base.SafeRunner.run")
    def test_network_get_radio_status(self, mock_run, mock_avail):
        mock_run.return_value = subprocess.CompletedProcess(
            args=["nmcli", "-t", "-f", "WIFI,WWAN", "radio"],
            returncode=0,
            stdout="enabled:disabled\n",
            stderr="",
        )
        status = NetworkAdapter.get_radio_status()
        self.assertEqual(status, {"wifi": True, "wwan": False})

    @patch("poly_shell.adapters.base.SafeRunner.run")
    def test_network_set_wifi(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        self.assertTrue(NetworkAdapter.set_wifi_enabled(True))
        mock_run.assert_called_with(["nmcli", "radio", "wifi", "on"], timeout=4.0)

    @patch("poly_shell.adapters.base.SafeRunner.run")
    def test_network_block_rfkill(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        self.assertTrue(NetworkAdapter.block_rfkill("wlan", True))
        mock_run.assert_called_with(["rfkill", "block", "wlan"], timeout=4.0)


if __name__ == "__main__":
    unittest.main()
