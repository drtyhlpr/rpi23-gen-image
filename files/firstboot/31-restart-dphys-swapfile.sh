logger -t "rc.firstboot" "Restarting dphys-swapfile"

if systemctl is-enabled dphys-swapfile ; then
  systemctl restart dphys-swapfile
fi
