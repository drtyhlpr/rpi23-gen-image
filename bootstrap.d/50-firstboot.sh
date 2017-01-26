#
# First boot actions
#

# Load utility functions
. ./scripts/functions.sh

# Prepare rc.firstboot script
cat files/firstboot/10-begin.sh > "${ETC_DIR}/rc.firstboot"

# Ensure openssh server host keys are regenerated on first boot
if [ "$ENABLE_SSHD" = true ] ; then
  cat files/firstboot/21-generate-ssh-keys.sh >> "${ETC_DIR}/rc.firstboot"
fi

# Prepare filesystem auto expand
if [ "$EXPANDROOT" = true ] ; then
  if [ "$ENABLE_CRYPTFS" = false ] ; then
    cat files/firstboot/22-expandroot.sh >> "${ETC_DIR}/rc.firstboot"
  else
    # Regenerate initramfs to remove encrypted root partition auto expand
    cat files/firstboot/23-regenerate-initramfs.sh >> "${ETC_DIR}/rc.firstboot"
  fi
fi

# Ensure that dbus machine-id exists
cat files/firstboot/24-generate-machineid.sh >> "${ETC_DIR}/rc.firstboot"

# Create /etc/resolv.conf symlink
cat files/firstboot/25-create-resolv-symlink.sh >> "${ETC_DIR}/rc.firstboot"

# Configure automatic network interface names
if [ "$ENABLE_IFNAMES" = true ] ; then
  cat files/firstboot/26-config-ifnames.sh >> "${ETC_DIR}/rc.firstboot"
fi

# Finalize rc.firstboot script
cat files/firstboot/99-finish.sh >> "${ETC_DIR}/rc.firstboot"
chmod +x "${ETC_DIR}/rc.firstboot"

# Install default rc.local if it does not exist
if [ ! -f "${ETC_DIR}/rc.local" ] ; then
  install_exec files/etc/rc.local "${ETC_DIR}/rc.local"
fi

# Add rc.firstboot script to rc.local
sed -i '/exit 0/d' "${ETC_DIR}/rc.local"
echo /etc/rc.firstboot >> "${ETC_DIR}/rc.local"
echo exit 0 >> "${ETC_DIR}/rc.local"
