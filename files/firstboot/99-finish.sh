logger -t "rc.firstboot" "First boot actions finished"
rm -f /etc/rc.firstboot
sed -i '/.*rc.firstboot/d' /etc/rc.local
