# ALPORA Custom Arch Linux Live ISO Profile

This directory contains the `archiso` profile definition for creating **ALPORA OS**: a bootable, live Arch Linux ISO featuring the complete **ALPORA Desktop Environment** stack preconfigured with auto-login into Hyprland and offline installer capabilities.

---

## Method 1: Cloud Build via GitHub Actions (Recommended)

You don't need a local Linux machine or 15 GB of disk space to build the ISO. GitHub Actions will build it in the cloud for you:

1. Navigate to the **Actions** tab on your GitHub repository: `https://github.com/pnam-it309/alpora/actions`.
2. Under **Workflows**, click **Build ALPORA OS Live ISO**.
3. Click **Run workflow** (select branch `main`).
4. Wait for the build to complete (~25-35 minutes).
5. Download `alpora-os-live-iso.zip` containing the bootable `.iso` and SHA256 checksums from the **Artifacts** section!

*(When you publish a new GitHub Release, this workflow automatically compiles the ISO and attaches it to the release assets).*

---

## Method 2: Local Build on Arch Linux

### Requirements
- An active Arch Linux system with root permissions.
- The `archiso` package (`sudo pacman -S archiso`).
- At least 15 GB of free disk space for squashfs rootfs creation.

### Building
Run the builder script with root privileges:

```bash
sudo ./packaging/iso/build-iso.sh
```

Upon completion, the bootable `.iso` image and checksum will be placed in `packaging/iso/out/`.

---

## Live Desktop Experience & Installation

* **Auto-Login:** The Live USB automatically logs into the `alpora` desktop user with `sudo` access.
* **Instant Hyprland Session:** Hyprland starts immediately on boot with ALPORA TopBar, Dynamic Island, and Fcitx5 Bamboo Vietnamese input.
* **Install to Disk:** To permanently install ALPORA OS onto your computer's hard drive, open a terminal or press `Super+Return` and run:
  ```bash
  alpora-install
  ```

---

## Security Hardening & Performance Built-in

ALPORA OS ISO comes pre-hardened out of the box:
* **Wayland Protocol Isolation:** Hyprland isolates every client window, preventing unauthorized keylogging and background screen capture.
* **Firewall (UFW):** Default deny incoming traffic, allow outgoing, with explicit pinhole allowance for ALPORA Phone / KDE Connect ecosystem (ports 1714:1764).
* **Mandatory Access Control (AppArmor):** `apparmor.service` enabled for zero-day mitigation and untrusted process sandboxing.
* **Kernel & Multi-core Optimization:** Sysctl profiles (`99-alpora-security.conf` and `99-alpora-performance.conf`) configure `kernel.kptr_restrict`, `dmesg_restrict`, `unprivileged_bpf_disabled`, `vm.swappiness = 10`, and `vm.max_map_count = 1048576` for peak Wine/Proton gaming frame stability (Honkai, ZZZ) and low memory usage.

---

## Flashing to USB

You can write the generated ISO to a USB flash drive using:
* **Ventoy**: Simply copy the `.iso` file into your Ventoy USB drive.
* **Rufus (Windows)**: Select the ISO in Rufus and write in *DD Image mode*.
* **dd (Linux)**:
  ```bash
  sudo dd bs=4M if=packaging/iso/out/alpora-archlinux-*.iso of=/dev/sdX status=progress oflag=sync
  ```
