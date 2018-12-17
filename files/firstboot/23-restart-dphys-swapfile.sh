# Restart dphys-swapfile service if it exists
if systemctl list-units | grep -q dphys-swapfile ; then
  logger -t "rc.firstboot" "Restarting dphys-swapfile"

  systemctl enable dphys-swapfile
  systemctl restart dphys-swapfile
fi
