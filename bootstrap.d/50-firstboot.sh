#
# First boot actions
#

. ./functions.sh

cat files/firstboot/10-begin.sh > $R/etc/rc.firstboot

# Ensure openssh server host keys are regenerated on first boot
if [ "$ENABLE_SSHD" = true ] ; then
  cat files/firstboot/21-generate-ssh-keys.sh >> $R/etc/rc.firstboot
  rm -f $R/etc/ssh/ssh_host_*
fi

if [ "$EXPANDROOT" = true ] ; then
  cat files/firstboot/22-expandroot.sh >> $R/etc/rc.firstboot
fi

cat files/firstboot/99-finish.sh >> $R/etc/rc.firstboot
chmod +x $R/etc/rc.firstboot

sed -i '/exit 0/d' $R/etc/rc.local
echo /etc/rc.firstboot >> $R/etc/rc.local
echo exit 0 >> $R/etc/rc.local
