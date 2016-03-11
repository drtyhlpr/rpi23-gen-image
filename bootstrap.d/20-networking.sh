#
# Setup networking
#

. ./functions.sh

# Set up IPv4 hosts
echo ${HOSTNAME} >$R/etc/hostname
cat <<EOM >$R/etc/hosts
127.0.0.1       localhost
127.0.1.1       ${HOSTNAME}
EOM

if [ "$NET_ADDRESS" != "" ] ; then
NET_IP=$(echo ${NET_ADDRESS} | cut -f 1 -d'/')
sed -i "s/^127.0.1.1/${NET_IP}/" $R/etc/hosts
fi

# Set up IPv6 hosts
if [ "$ENABLE_IPV6" = true ] ; then
cat <<EOM >>$R/etc/hosts

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOM
fi

# Place hint about network configuration
cat <<EOM >$R/etc/network/interfaces
# Debian switched to systemd-networkd configuration files.
# please configure your networks in '/etc/systemd/network/'
source /etc/interfaces.d/*.conf
EOM

if [ "$ENABLE_DHCP" = true ] ; then
# Enable systemd-networkd DHCP configuration for interface eth0
cat <<EOM >$R/etc/systemd/network/eth.network
[Match]
Name=eth0

[Network]
DHCP=yes
EOM

# Set DHCP configuration to IPv4 only
if [ "$ENABLE_IPV6" = false ] ; then
  sed -i "s/^DHCP=yes/DHCP=v4/" $R/etc/systemd/network/eth.network
fi
else # ENABLE_DHCP=false
cat <<EOM >$R/etc/systemd/network/eth.network
[Match]
Name=eth0

[Network]
DHCP=no
Address=${NET_ADDRESS}
Gateway=${NET_GATEWAY}
DNS=${NET_DNS_1}
DNS=${NET_DNS_2}
Domains=${NET_DNS_DOMAINS}
NTP=${NET_NTP_1}
NTP=${NET_NTP_2}
EOM
fi

# Enable systemd-networkd service
chroot_exec systemctl enable systemd-networkd

# Enable network stack hardening
if [ "$ENABLE_HARDNET" = true ] ; then
  install -o root -g root -m 644 files/sysctl.d/81-rpi-net-hardening.conf $R/etc/sysctl.d/81-rpi-net-hardening.conf

# Enable resolver warnings about spoofed addresses
  cat <<EOM >>$R/etc/host.conf
spoof warn
EOM
fi
