logger -t "rc.firstboot" "Configuring network interface name"

INTERFACE_NAME=$(dmesg | grep "renamed from eth0" | awk -F ":| " '{ print $9 }')

if [ ! -z INTERFACE_NAME ] ; then
  if [ -r "/etc/systemd/network/eth.network" ] ; then
    sed -i "s/eth0/${INTERFACE_NAME}/" /etc/systemd/network/eth.network
  fi

  if [ -r "/lib/systemd/network/10-eth.network" ] ; then
    sed -i "s/eth0/${INTERFACE_NAME}/" /lib/systemd/network/10-eth.network
  fi
fi
