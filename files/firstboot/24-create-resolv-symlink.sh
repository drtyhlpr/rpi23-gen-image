logger -t "rc.firstboot" "Creating /etc/resolv.conf symlink"
if [ -f "/run/systemd/resolve/resolv.conf" ] ; then
  ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
fi
