#!/usr/bin/env bash
# ==============================================================================
# ALPORA Live System Customization Script (Executed inside chroot during build)
# ==============================================================================
set -euo pipefail

# 1. Create default non-root user 'alpora'
if ! id -u alpora >/dev/null 2>&1; then
    useradd -m -g users -G wheel,audio,video,optical,storage,input,network -s /bin/bash alpora
    passwd -d alpora
fi

# 2. Enable critical live hardware services
systemctl enable NetworkManager.service || true
systemctl enable bluetooth.service || true
systemctl enable systemd-timesyncd.service || true

# 3. Secure file permissions
chmod 700 /root
chmod 440 /etc/sudoers.d/* || true
chmod 755 /usr/local/bin/* || true

echo "==> ALPORA Live RootFS customization completed successfully."

