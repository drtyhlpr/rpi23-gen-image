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

# Ensure /etc/systemd/network directory is available
mkdir -p "${ETC_DIR}/systemd/network"

# Setup hostname entry with static IP
if [ "$NET_ETH_ADDRESS" != "" ] ; then
  NET_IP=$(echo "${NET_ETH_ADDRESS}" | cut -f 1 -d'/')
  sed -i "s/^127.0.1.1/${NET_IP}/" "${ETC_DIR}/hosts"
fi

# Remove IPv6 hosts
if [ "$ENABLE_IPV6" = false ] ; then
  sed -i -e "/::[1-9]/d" -e "/^$/d" "${ETC_DIR}/hosts"
fi

# Install hint about network configuration
install_readonly files/network/interfaces "${ETC_DIR}/network/interfaces"

# Install configuration for interface eth0
install_readonly files/network/eth0.network "${ETC_DIR}/systemd/network/eth0.network"

if [ "$RPI_MODEL" = 3P ] ; then
printf "\n[Link]\nGenericReceiveOffload=off\nTCPSegmentationOffload=off\nGenericSegmentationOffload=off" >> "${ETC_DIR}/systemd/network/eth0.network"
fi

# Install configuration for interface wl*
install_readonly files/network/wlan0.network "${ETC_DIR}/systemd/network/wlan0.network"

#always with dhcp since wpa_supplicant integration is missing
sed -i -e "s/DHCP=.*/DHCP=yes/" -e "/DHCP/q" "${ETC_DIR}/systemd/network/wlan0.network"

if [ "$ENABLE_ETH_DHCP" = true ] ; then
  # Enable DHCP configuration for interface eth0
  sed -i -e "s/DHCP=.*/DHCP=yes/" -e "/DHCP/q" "${ETC_DIR}/systemd/network/eth0.network"
  
  # Set DHCP configuration to IPv4 only
  if [ "$ENABLE_IPV6" = false ] ; then
    sed -i "s/DHCP=.*/DHCP=v4/" "${ETC_DIR}/systemd/network/eth0.network"
	sed '/IPv6PrivacyExtensions=true/d' "${ETC_DIR}/systemd/network/eth0.network"
  fi

else # ENABLE_ETH_DHCP=false
  # Set static network configuration for interface eth0
  if [ -n NET_ETH_ADDRESS ] && [ -n NET_ETH_GATEWAY ] && [ -n NET_ETH_DNS_1 ] ; then
    sed -i\
    -e "s|DHCP=.*|DHCP=no|"\
    -e "s|Address=\$|Address=${NET_ETH_ADDRESS}|"\
    -e "s|Gateway=\$|Gateway=${NET_ETH_GATEWAY}|"\
    -e "0,/DNS=\$/ s|DNS=\$|DNS=${NET_ETH_DNS_1}|"\
    -e "0,/DNS=\$/ s|DNS=\$|DNS=${NET_ETH_DNS_2}|"\
    -e "s|Domains=\$|Domains=${NET_ETH_DNS_DOMAINS}|"\
    -e "0,/NTP=\$/ s|NTP=\$|NTP=${NET_ETH_NTP_1}|"\
    -e "0,/NTP=\$/ s|NTP=\$|NTP=${NET_ETH_NTP_2}|"\
    "${ETC_DIR}/systemd/network/eth0.network"
  fi
fi


if [ "$ENABLE_WIRELESS" = true ] ; then
  mkdir -p "${ETC_DIR}/wpa_supplicant"
  if [ "$ENABLE_WIFI_DHCP" = true ] ; then
    # Enable DHCP configuration for interface eth0
    sed -i -e "s/DHCP=.*/DHCP=yes/" -e "/DHCP/q" "${ETC_DIR}/systemd/network/wlan0.network"

    # Set DHCP configuration to IPv4 only
    if [ "$ENABLE_IPV6" = false ] ; then
      sed -i "s/DHCP=.*/DHCP=v4/" "${ETC_DIR}/systemd/network/wlan0.network"
	  sed '/IPv6PrivacyExtensions=true/d' "${ETC_DIR}/systemd/network/wlan0.network"
    fi

  else # ENABLE_WIFI_DHCP=false
    # Set static network configuration for interface eth0
	if [ -n NET_WIFI_ADDRESS ] && [ -n NET_WIFI_GATEWAY ] && [ -n NET_WIFI_DNS_1 ] ; then
      sed -i\
      -e "s|DHCP=.*|DHCP=no|"\
      -e "s|Address=\$|Address=${NET_WIFI_ADDRESS}|"\
      -e "s|Gateway=\$|Gateway=${NET_WIFI_GATEWAY}|"\
      -e "0,/DNS=\$/ s|DNS=\$|DNS=${NET_WIFI_DNS_1}|"\
      -e "0,/DNS=\$/ s|DNS=\$|DNS=${NET_WIFI_DNS_2}|"\
      -e "s|Domains=\$|Domains=${NET_WIFI_DNS_DOMAINS}|"\
      -e "0,/NTP=\$/ s|NTP=\$|NTP=${NET_WIFI_NTP_1}|"\
      -e "0,/NTP=\$/ s|NTP=\$|NTP=${NET_WIFI_NTP_2}|"\
      "${ETC_DIR}/systemd/network/wlan0.network"
	fi
  fi
  
  if [ ! -z "$NET_WIFI_SSID" ] && [ ! -z "$NET_WIFI_PSK" ] ; then
  chroot_exec printf "
  ctrl_interface=/run/wpa_supplicant
  update_config=1
  eapol_version=1
  ap_scan=1
  fast_reauth=1

  " > "${ETC_DIR}/wpa_supplicant/wpa_supplicant-wlan0.conf"

  #Configure WPA_supplicant
  chroot_exec wpa_passphrase "$NET_WIFI_SSID" "$NET_WIFI_PSK" >> "${ETC_DIR}/wpa_supplicant/wpa_supplicant-wlan0.conf"

  chroot_exec systemctl enable wpa_supplicant.service
  chroot_exec systemctl enable wpa_supplicant@wlan0.service 
  fi
  # Remove empty settings from wlan configuration
  sed -i "/.*=\$/d" "${ETC_DIR}/systemd/network/wlan0.network"
  # If WLAN is enabled copy wlan configuration too
  mv -v "${ETC_DIR}/systemd/network/wlan0.network" "${LIB_DIR}/systemd/network/11-wlan0.network"
fi

# Remove empty settings from network configuration
sed -i "/.*=\$/d" "${ETC_DIR}/systemd/network/eth0.network"

# Move systemd network configuration if required by Debian release
mv -v "${ETC_DIR}/systemd/network/eth0.network" "${LIB_DIR}/systemd/network/10-eth0.network"

#Clean up
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
  if [ "$RPI_MODEL" = 3P ] || [ "$RPI_MODEL" = 4 ] ; then
    # Fetch firmware binary blob for RPi3P
    as_nobody wget -q -O "${temp_dir}/brcmfmac43455-sdio.bin" "${WLAN_FIRMWARE_URL}/brcmfmac43455-sdio.bin"
    as_nobody wget -q -O "${temp_dir}/brcmfmac43455-sdio.txt" "${WLAN_FIRMWARE_URL}/brcmfmac43455-sdio.txt"
    as_nobody wget -q -O "${temp_dir}/brcmfmac43455-sdio.clm_blob" "${WLAN_FIRMWARE_URL}/brcmfmac43455-sdio.clm_blob"
	
	# Move downloaded firmware binary blob
	mv "${temp_dir}/brcmfmac43455-sdio."* "${WLAN_FIRMWARE_DIR}/"
	
	# Set permissions of the firmware binary blob
	chown root:root "${WLAN_FIRMWARE_DIR}/brcmfmac43455-sdio."*
    chmod 600 "${WLAN_FIRMWARE_DIR}/brcmfmac43455-sdio."*
  elif [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 0 ] ; then
    # Fetch firmware binary blob for RPi3
    as_nobody wget -q -O "${temp_dir}/brcmfmac43430-sdio.bin" "${WLAN_FIRMWARE_URL}/brcmfmac43430-sdio.bin"
    as_nobody wget -q -O "${temp_dir}/brcmfmac43430-sdio.txt" "${WLAN_FIRMWARE_URL}/brcmfmac43430-sdio.txt"
	
	# Move downloaded firmware binary blob
	mv "${temp_dir}/brcmfmac43430-sdio."* "${WLAN_FIRMWARE_DIR}/"
	
	# Set permissions of the firmware binary blob
	chown root:root "${WLAN_FIRMWARE_DIR}/brcmfmac43430-sdio."*
    chmod 600 "${WLAN_FIRMWARE_DIR}/brcmfmac43430-sdio."*
  fi
  
  # Remove temporary directory for firmware binary blob
  rm -fr "${temp_dir}"
fi
