"""Tests for Windows filesystem and drive management integration."""
import json
import unittest
from unittest.mock import patch, MagicMock

from poly_shell import windows_fs
from poly_shell.state import ConfigError


MOCK_LSBLK_JSON = json.dumps({
    "blockdevices": [
        {
            "name": "nvme0n1",
            "fstype": None,
            "label": None,
            "mountpoint": None,
            "size": "500G",
            "uuid": None,
            "children": [
                {
                    "name": "nvme0n1p1",
                    "fstype": "vfat",
                    "label": "SYSTEM_EFI",
                    "mountpoint": "/boot",
                    "size": "512M",
                    "uuid": "1234-ABCD"
                },
                {
                    "name": "nvme0n1p2",
                    "fstype": "ntfs",
                    "label": "Windows-C",
                    "mountpoint": None,
                    "size": "200G",
                    "uuid": "E0123456789"
                },
                {
                    "name": "nvme0n1p3",
                    "fstype": "ext4",
                    "label": "ArchLinux",
                    "mountpoint": "/",
                    "size": "100G",
                    "uuid": "A0123456789"
                },
                {
                    "name": "nvme0n1p4",
                    "fstype": "exfat",
                    "label": "SharedData",
                    "mountpoint": "/run/media/nick/SharedData",
                    "size": "199.5G",
                    "uuid": "F0123456789"
                }
            ]
        }
    ]
})


class WindowsFsTests(unittest.TestCase):
    def test_normalize_windows_path(self):
        self.assertEqual(windows_fs.normalize_windows_path(r"D:\Projects\alpora"), "/mnt/d/Projects/alpora")
        self.assertEqual(windows_fs.normalize_windows_path(r"C:\Windows\System32"), "/mnt/c/Windows/System32")
        self.assertEqual(windows_fs.normalize_windows_path(r"images\wallpapers\mountains.png"), "images/wallpapers/mountains.png")
        self.assertEqual(windows_fs.normalize_windows_path(""), "")
        self.assertEqual(windows_fs.normalize_windows_path(None), "")

    def test_detect_windows_drives_filters_ntfs_vfat_exfat(self):
        drives = windows_fs.detect_windows_drives(mock_json=MOCK_LSBLK_JSON)
        # Should include: vfat (nvme0n1p1), ntfs (nvme0n1p2), exfat (nvme0n1p4); exclude ext4 (nvme0n1p3)
        self.assertEqual(len(drives), 3)
        names = [d["name"] for d in drives]
        self.assertIn("nvme0n1p1", names)
        self.assertIn("nvme0n1p2", names)
        self.assertIn("nvme0n1p4", names)
        self.assertNotIn("nvme0n1p3", names)

        # Check ntfs properties
        ntfs_drive = next(d for d in drives if d["name"] == "nvme0n1p2")
        self.assertEqual(ntfs_drive["device"], "/dev/nvme0n1p2")
        self.assertEqual(ntfs_drive["fstype"], "ntfs")
        self.assertEqual(ntfs_drive["label"], "Windows-C")
        self.assertEqual(ntfs_drive["size"], "200G")
        self.assertFalse(ntfs_drive["mounted"])

        # Check mounted exfat
        exfat_drive = next(d for d in drives if d["name"] == "nvme0n1p4")
        self.assertTrue(exfat_drive["mounted"])
        self.assertEqual(exfat_drive["mountpoint"], "/run/media/nick/SharedData")

    def test_detect_windows_drives_empty_on_corrupt_json(self):
        self.assertEqual(windows_fs.detect_windows_drives(mock_json="not json"), [])

    def test_mount_invalid_device_raises_config_error(self):
        with self.assertRaises(ConfigError):
            windows_fs.mount_drive("sda1; rm -rf /")
        with self.assertRaises(ConfigError):
            windows_fs.mount_drive("")

    @patch("shutil.which", return_value="/usr/bin/udisksctl")
    @patch("subprocess.run")
    def test_mount_drive_success(self, mock_run, mock_which):
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_proc.stdout = "Mounted /dev/nvme0n1p2 at /run/media/user/Windows-C."
        mock_run.return_value = mock_proc

        mountpoint = windows_fs.mount_drive("/dev/nvme0n1p2")
        self.assertEqual(mountpoint, "/run/media/user/Windows-C")
        mock_run.assert_called_once_with(
            ["udisksctl", "mount", "-b", "/dev/nvme0n1p2", "--no-user-interaction"],
            capture_output=True, text=True, timeout=10
        )

    @patch("shutil.which", return_value="/usr/bin/udisksctl")
    @patch("subprocess.run")
    def test_unmount_drive_success(self, mock_run, mock_which):
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_proc.stdout = "Unmounted /dev/nvme0n1p2."
        mock_run.return_value = mock_proc

        result = windows_fs.unmount_drive("/dev/nvme0n1p2")
        self.assertTrue(result)
        mock_run.assert_called_once_with(
            ["udisksctl", "unmount", "-b", "/dev/nvme0n1p2", "--no-user-interaction"],
            capture_output=True, text=True, timeout=10
        )


if __name__ == "__main__":
    unittest.main()
