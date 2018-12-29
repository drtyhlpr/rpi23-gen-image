# Restart dphys-swapfile service if it exists
logger -t "rc.firstboot" "Restarting dphys-swapfile"

systemctl enable dphys-swapfile
systemctl restart dphys-swapfile
