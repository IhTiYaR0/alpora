#!/usr/bin/env bash
# ALPORA Live Archiso Profile Definition
# Documentation: https://wiki.archlinux.org/title/archiso

iso_name="alpora-archlinux"
iso_label="ALPORA_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="ALPORA Desktop <https://github.com/pnam-it309/alpora>"
iso_application="ALPORA Desktop Live System & Installer"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.systemd-boot.esp' 'uefi-x64.systemd-boot.esp'
           'uefi-ia32.systemd-boot.eltorito' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers.d/alpora"]="0:0:440"
  ["/etc/sysctl.d/99-alpora-security.conf"]="0:0:644"
  ["/etc/sysctl.d/99-alpora-performance.conf"]="0:0:644"
  ["/root"]="0:0:750"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/usr/local/bin/alpora-install"]="0:0:755"
)

