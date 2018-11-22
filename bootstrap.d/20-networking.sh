#
# Setup Networking
#

# Load utility functions
. ./functions.sh

# Install and setup hostname
install_readonly files/network/hostname "${ETC_DIR}/hostname"
sed -i "s/^RaspberryPI/${HOSTNAME}/" "${ETC_DIR}/hostname"

# Install and setup hosts
install_readonly files/network/hosts "${ETC_DIR}/hosts"
sed -i "s/RaspberryPI/${HOSTNAME}/" "${ETC_DIR}/hosts"

# Setup hostname entry with static IP
if [ "$NET_ADDRESS" != "" ] ; then
  NET_IP=$(echo "${NET_ADDRESS}" | cut -f 1 -d'/')
  sed -i "s/^127.0.1.1/${NET_IP}/" "${ETC_DIR}/hosts"
fi

# Remove IPv6 hosts
if [ "$ENABLE_IPV6" = false ] ; then
  sed -i -e "/::[1-9]/d" -e "/^$/d" "${ETC_DIR}/hosts"
fi

# Install hint about network configuration
install_readonly files/network/interfaces "${ETC_DIR}/network/interfaces"

# Install configuration for interface eth0
install_readonly files/network/eth.network "${ETC_DIR}/systemd/network/eth.network"

# Install configuration for interface wl*
install_readonly files/network/wlan.network "${ETC_DIR}/systemd/network/wlan.network"

#always with dhcp since wpa_supplicant integration is missing
sed -i -e "s/DHCP=.*/DHCP=yes/" -e "/DHCP/q" "${ETC_DIR}/systemd/network/wlan.network"

if [ "$ENABLE_DHCP" = true ] ; then
  # Enable DHCP configuration for interface eth0
  sed -i -e "s/DHCP=.*/DHCP=yes/" -e "/DHCP/q" "${ETC_DIR}/systemd/network/eth.network"
  
  # Set DHCP configuration to IPv4 only
  if [ "$ENABLE_IPV6" = false ] ; then
    sed -i "s/DHCP=.*/DHCP=v4/" "${ETC_DIR}/systemd/network/eth.network"
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
  "${ETC_DIR}/systemd/network/eth.network"
fi

# Remove empty settings from network configuration
sed -i "/.*=\$/d" "${ETC_DIR}/systemd/network/eth.network"
# Remove empty settings from wlan configuration
sed -i "/.*=\$/d" "${ETC_DIR}/systemd/network/wlan.network"

# Move systemd network configuration if required by Debian release
mv -v "${ETC_DIR}/systemd/network/eth.network" "${LIB_DIR}/systemd/network/10-eth.network"
# If WLAN is enabled copy wlan configuration too
if [ "$ENABLE_WIRELESS" = true ] ; then
  mv -v "${ETC_DIR}/systemd/network/wlan.network" "${LIB_DIR}/systemd/network/11-wlan.network"
fi
rm -fr "${ETC_DIR}/systemd/network"

# Enable systemd-networkd service
chroot_exec systemctl enable systemd-networkd

# Install host.conf resolver configuration
install_readonly files/network/host.conf "${ETC_DIR}/host.conf"

# Enable network stack hardening
if [ "$ENABLE_HARDNET" = true ] ; then
  # Install sysctl.d configuration files
  install_readonly files/sysctl.d/82-rpi-net-hardening.conf "${ETC_DIR}/sysctl.d/82-rpi-net-hardening.conf"

  # Setup resolver warnings about spoofed addresses
  sed -i "s/^# spoof warn/spoof warn/" "${ETC_DIR}/host.conf"
fi

# Enable time sync
if [ "$NET_NTP_1" != "" ] ; then
  chroot_exec systemctl enable systemd-timesyncd.service
fi

# Download the firmware binary blob required to use the RPi3 wireless interface
if [ "$ENABLE_WIRELESS" = true ] ; then
  if [ ! -d "${WLAN_FIRMWARE_DIR}" ] ; then
    mkdir -p "${WLAN_FIRMWARE_DIR}"
  fi

  # Create temporary directory for firmware binary blob
  temp_dir=$(as_nobody mktemp -d)

  # Fetch firmware binary blob for RPI3B+
  if [ "$RPI_MODEL" = 3P ] ; then
    # Fetch firmware binary blob for RPi3P
    as_nobody wget -q -O "${temp_dir}/brcmfmac43455-sdio.bin" "${WLAN_FIRMWARE_URL}/brcmfmac43455-sdio.bin"
    as_nobody wget -q -O "${temp_dir}/brcmfmac43455-sdio.txt" "${WLAN_FIRMWARE_URL}/brcmfmac43455-sdio.txt"
    as_nobody wget -q -O "${temp_dir}/brcmfmac43455-sdio.clm_blob" "${WLAN_FIRMWARE_URL}/brcmfmac43455-sdio.clm_blob"
  elif [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 0 ] ; then
    # Fetch firmware binary blob for RPi3
    as_nobody wget -q -O "${temp_dir}/brcmfmac43430-sdio.bin" "${WLAN_FIRMWARE_URL}/brcmfmac43430-sdio.bin"
    as_nobody wget -q -O "${temp_dir}/brcmfmac43430-sdio.txt" "${WLAN_FIRMWARE_URL}/brcmfmac43430-sdio.txt"
  fi
  
  # Move downloaded firmware binary blob
  if [ "$RPI_MODEL" = 3P ] ; then
    mv "${temp_dir}/brcmfmac43455-sdio."* "${WLAN_FIRMWARE_DIR}/"
  elif [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 0 ] ; then
    mv "${temp_dir}/brcmfmac43430-sdio."* "${WLAN_FIRMWARE_DIR}/"
  fi
  
  # Remove temporary directory for firmware binary blob
  rm -fr "${temp_dir}"

  # Set permissions of the firmware binary blob
  if [ "$RPI_MODEL" = 3P ] ; then
    chown root:root "${WLAN_FIRMWARE_DIR}/brcmfmac43455-sdio."*
    chmod 600 "${WLAN_FIRMWARE_DIR}/brcmfmac43455-sdio."*
  elif [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 0 ] ; then
    chown root:root "${WLAN_FIRMWARE_DIR}/brcmfmac43430-sdio."*
    chmod 600 "${WLAN_FIRMWARE_DIR}/brcmfmac43430-sdio."*
  fi
fi
