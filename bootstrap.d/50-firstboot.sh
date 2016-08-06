#
# First boot actions
#

# Load utility functions
. ./functions.sh

# Prepare rc.firstboot script
cat files/firstboot/10-begin.sh > "${ETCDIR}/rc.firstboot"

# Ensure openssh server host keys are regenerated on first boot
if [ "$ENABLE_SSHD" = true ] ; then
  cat files/firstboot/21-generate-ssh-keys.sh >> "${ETCDIR}/rc.firstboot"
fi

# Prepare filesystem auto expand
if [ "$EXPANDROOT" = true ] ; then
  if [ "$ENABLE_CRYPTFS" = false ] ; then
    cat files/firstboot/22-expandroot.sh >> "${ETCDIR}/rc.firstboot"
  else
    # Regenerate initramfs to remove encrypted root partition auto expand
    cat files/firstboot/23-regenerate-initramfs.sh >> "${ETCDIR}/rc.firstboot"
  fi
fi

# Ensure that dbus machine-id exists
cat files/firstboot/24-generate-machineid.sh >> "${ETCDIR}/rc.firstboot"

# Create /etc/resolv.conf symlink
cat files/firstboot/25-create-resolv-symlink.sh >> "${ETCDIR}/rc.firstboot"

# Configure automatic network interface names
if [ "$ENABLE_IFNAMES" = true ] ; then
  cat files/firstboot/26-config-ifnames.sh >> "${ETCDIR}/rc.firstboot"
fi

# Finalize rc.firstboot script
cat files/firstboot/99-finish.sh >> "${ETCDIR}/rc.firstboot"
chmod +x "${ETCDIR}/rc.firstboot"

# Install default rc.local if it does not exist
if [ ! -f "${ETCDIR}/rc.local" ] ; then
  install_exec files/etc/rc.local "${ETCDIR}/rc.local"
fi

# Add rc.firstboot script to rc.local
sed -i '/exit 0/d' "${ETCDIR}/rc.local"
echo /etc/rc.firstboot >> "${ETCDIR}/rc.local"
echo exit 0 >> "${ETCDIR}/rc.local"
