#
# Setup Networking
#

# Load utility functions
. ./functions.sh

# Install and setup hostname
install_readonly files/network/hostname $R/etc/hostname
sed -i "s/^rpi2-jessie/${HOSTNAME}/" $R/etc/hostname

# Install and setup hosts
install_readonly files/network/hosts $R/etc/hosts
sed -i "s/rpi2-jessie/${HOSTNAME}/" $R/etc/hosts

# Setup hostname entry with static IP
if [ "$NET_ADDRESS" != "" ] ; then
  NET_IP=$(echo ${NET_ADDRESS} | cut -f 1 -d'/')
  sed -i "s/^127.0.1.1/${NET_IP}/" $R/etc/hosts
fi

# Remove IPv6 hosts
if [ "$ENABLE_IPV6" = false ] ; then
  sed -i -e "/::[1-9]/d" -e "/^$/d" $R/etc/hosts
fi

# Install hint about network configuration
install_readonly files/network/interfaces $R/etc/network/interfaces

# Install configuration for interface eth0
install_readonly files/network/eth.network $R/etc/systemd/network/eth.network

if [ "$ENABLE_DHCP" = true ] ; then
  # Enable DHCP configuration for interface eth0
  sed -i -e "s/DHCP=.*/DHCP=yes/" -e "/DHCP/q" $R/etc/systemd/network/eth.network

  # Set DHCP configuration to IPv4 only
  if [ "$ENABLE_IPV6" = false ] ; then
    sed -i "s/DHCP=.*/DHCP=v4/" $R/etc/systemd/network/eth.network
  fi

else # ENABLE_DHCP=false
  # Set static network configuration for interface eth0
  sed -i\
  -e "s|DHCP=.*|DHCP=no|"\
  -e "s|Address=\$|Address=${NET_ADDRESS}|"\
  -e "s|Gateway=\$|Gateway=${NET_GATEWAY}|"\
  -e "0,/DNS=\$/ s|DNS=\$|DNS=${NET_DNS_1}|"\
  -e "0,/DNS=\$/ s|DNS=\$|DNS=${NET_DNS_2}|"\
  -e "s|Domains=\$|Domains=${NET_DNS_DOMAINS}|"\
  -e "0,/NTP=\$/ s|NTP=\$|NTP=${NET_NTP_1}|"\
  -e "0,/NTP=\$/ s|NTP=\$|NTP=${NET_NTP_2}|"\
  $R/etc/systemd/network/eth.network
fi

# Remove empty settings from network configuration
sed -i "/.*=\$/d" $R/etc/systemd/network/eth.network

# Enable systemd-networkd service
chroot_exec systemctl enable systemd-networkd

# Install host.conf resolver configuration
install_readonly files/network/host.conf $R/etc/host.conf

# Enable network stack hardening
if [ "$ENABLE_HARDNET" = true ] ; then
  # Install sysctl.d configuration files
  install_readonly files/sysctl.d/82-rpi-net-hardening.conf $R/etc/sysctl.d/82-rpi-net-hardening.conf

  # Setup resolver warnings about spoofed addresses
  sed -i "s/^# spoof warn/spoof warn/" $R/etc/host.conf
fi
