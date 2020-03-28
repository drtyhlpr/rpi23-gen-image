logger -t "rc.firstboot" "Configuring network interface name"

INTERFACE_NAME_ETH=$(dmesg | grep "renamed from eth0" | awk -F ":| " '{ print $9 }')
INTERFACE_NAME_WIFI=$(dmesg | grep "renamed from wlan0" | awk -F ":| " '{ print $9 }')

if [ ! -z INTERFACE_NAME_ETH ] ; then
  if [ -r "/etc/systemd/network/eth0.network" ] ; then
    sed -i "s/eth0/${INTERFACE_NAME_ETH}/" /etc/systemd/network/eth0.network
  fi

  if [ -r "/lib/systemd/network/10-eth0.network" ] ; then
    sed -i "s/eth0/${INTERFACE_NAME_ETH}/" /lib/systemd/network/10-eth0.network
  fi
  # Move config to new interface name
  mv /etc/systemd/network/eth0.network /etc/systemd/network/"${INTERFACE_NAME_ETH}".network
fi

if [ ! -z INTERFACE_NAME_WIFI ] ; then
  if [ -r "/etc/systemd/network/wlan0.network" ] ; then
    sed -i "s/wlan0/${INTERFACE_NAME_WIFI}/" /etc/systemd/network/wlan0.network
  fi

  if [ -r "/lib/systemd/network/11-wlan0.network" ] ; then
    sed -i "s/wlan0/${INTERFACE_NAME_WIFI}/" /lib/systemd/network/11-wlan0.network
  fi
  # Move config to new interface name
  mv /etc/systemd/network/wlan0.network /etc/systemd/network/"${INTERFACE_NAME_WIFI}".network
  
  systemctl disable wpa_supplicant@wlan0.service 
  systemctl enable wpa_supplicant@"${INTERFACE_NAME_WIFI}".service 
  systemctl start wpa_supplicant@"${INTERFACE_NAME_WIFI}".service 
fi
