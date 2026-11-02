# ALPORA Custom Arch Linux Live ISO Profile

This directory contains the `archiso` profile definition for creating a bootable, live Arch Linux ISO featuring the complete **ALPORA Desktop Environment** stack preconfigured.

## Requirements
- An active Arch Linux system with root permissions.
- The `archiso` package (`sudo pacman -S archiso`).
- At least 15 GB of free disk space for the build directory and squashfs rootfs.

## Building the ISO
Run the builder script with `sudo`:

```bash
sudo ./packaging/iso/build-iso.sh
```

Upon completion, the bootable `.iso` image will be placed in `packaging/iso/out/`.

## Flashing & Booting
You can write the generated ISO to a USB flash drive using:
- **Ventoy**: Simply copy the `.iso` file into your Ventoy USB drive.
- **dd**:
  ```bash
  sudo dd bs=4M if=packaging/iso/out/alpora-archlinux-*.iso of=/dev/sdX status=progress oflag=sync
  ```
  *(Replace `/dev/sdX` with your target USB drive).*
