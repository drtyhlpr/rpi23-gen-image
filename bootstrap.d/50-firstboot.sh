#
# First boot actions
#

# Load utility functions
. ./functions.sh

# Prepare rc.firstboot script
cat files/firstboot/10-begin.sh > $R/etc/rc.firstboot

# Ensure openssh server host keys are regenerated on first boot
if [ "$ENABLE_SSHD" = true ] ; then
  cat files/firstboot/21-generate-ssh-keys.sh >> $R/etc/rc.firstboot
  rm -f $R/etc/ssh/ssh_host_*
fi

# Prepare filesystem auto expand
if [ "$EXPANDROOT" = true ] ; then
  cat files/firstboot/22-expandroot.sh >> $R/etc/rc.firstboot
fi

# Ensure that dbus machine-id exists
cat files/firstboot/23-generate-machineid.sh >> $R/etc/rc.firstboot

# Create /etc/resolv.conf symlink
cat files/firstboot/24-create-resolv-symlink.sh >> $R/etc/rc.firstboot

# Finalize rc.firstboot script
cat files/firstboot/99-finish.sh >> $R/etc/rc.firstboot
chmod +x $R/etc/rc.firstboot

# Add rc.firstboot script to rc.local
sed -i '/exit 0/d' $R/etc/rc.local
echo /etc/rc.firstboot >> $R/etc/rc.local
echo exit 0 >> $R/etc/rc.local
