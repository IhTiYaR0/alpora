#!/usr/bin/env bash
# ==============================================================================
# ALPORA Live System Customization Script (Executed inside chroot during build)
# ==============================================================================
set -euo pipefail

# 1. Unlock root and create default non-root user 'alpora'
passwd -d root || true
if ! id -u alpora >/dev/null 2>&1; then
    useradd -m -g users -G wheel,audio,video,optical,storage,input,network -s /bin/bash alpora
    passwd -d alpora
fi

# 2. Enable critical live hardware & security services
systemctl enable NetworkManager.service || true
systemctl enable bluetooth.service || true
systemctl enable systemd-timesyncd.service || true
systemctl enable apparmor.service || true
systemctl enable irqbalance.service || true

# 3. Configure and enable UFW firewall
if command -v ufw >/dev/null 2>&1; then
    ufw default deny incoming || true
    ufw default allow outgoing || true
    ufw allow 1714:1764/udp comment 'ALPORA Phone / KDE Connect' || true
    ufw allow 1714:1764/tcp comment 'ALPORA Phone / KDE Connect' || true
    systemctl enable ufw.service || true
fi

# 4. Secure file permissions
chmod 700 /root
chmod 440 /etc/sudoers.d/* || true
chmod 644 /etc/sysctl.d/*.conf || true
chmod 755 /usr/local/bin/* || true

echo "==> ALPORA Live RootFS customization completed successfully."

