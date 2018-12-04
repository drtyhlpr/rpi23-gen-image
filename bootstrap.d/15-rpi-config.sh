#
# Setup RPi2/3 config and cmdline
#

# Load utility functions
. ./functions.sh

#if [ "$BUILD_KERNEL" = true ] ; then
  if [ -n "$RPI_FIRMWARE_DIR" ] && [ -d "$RPI_FIRMWARE_DIR" ] ; then
    # Install boot binaries from local directory
    cp "${RPI_FIRMWARE_DIR}"/boot/bootcode.bin "${BOOT_DIR}"/bootcode.bin
    cp "${RPI_FIRMWARE_DIR}"/boot/fixup.dat "${BOOT_DIR}"/fixup.dat
    cp "${RPI_FIRMWARE_DIR}"/boot/fixup_cd.dat "${BOOT_DIR}"/fixup_cd.dat
    cp "${RPI_FIRMWARE_DIR}"/boot/fixup_x.dat "${BOOT_DIR}"/fixup_x.dat
    cp "${RPI_FIRMWARE_DIR}"/boot/start.elf "${BOOT_DIR}"/start.elf
    cp "${RPI_FIRMWARE_DIR}"/boot/start_cd.elf "${BOOT_DIR}"/start_cd.elf
    cp "${RPI_FIRMWARE_DIR}"/boot/start_x.elf "${BOOT_DIR}"/start_x.elf
  else
    # Create temporary directory for boot binaries
    temp_dir=$(as_nobody mktemp -d)

    # Install latest boot binaries from raspberry/firmware github
    as_nobody wget -q -O "${temp_dir}/bootcode.bin" "${FIRMWARE_URL}/bootcode.bin"
    as_nobody wget -q -O "${temp_dir}/fixup.dat" "${FIRMWARE_URL}/fixup.dat"
    as_nobody wget -q -O "${temp_dir}/fixup_cd.dat" "${FIRMWARE_URL}/fixup_cd.dat"
    as_nobody wget -q -O "${temp_dir}/fixup_x.dat" "${FIRMWARE_URL}/fixup_x.dat"
    as_nobody wget -q -O "${temp_dir}/start.elf" "${FIRMWARE_URL}/start.elf"
    as_nobody wget -q -O "${temp_dir}/start_cd.elf" "${FIRMWARE_URL}/start_cd.elf"
    as_nobody wget -q -O "${temp_dir}/start_x.elf" "${FIRMWARE_URL}/start_x.elf"

    # Move downloaded boot binaries
    mv "${temp_dir}/"* "${BOOT_DIR}/"

    # Remove temporary directory for boot binaries
    rm -fr "${temp_dir}"

    # Set permissions of the boot binaries
    chown -R root:root "${BOOT_DIR}"
    chmod -R 600 "${BOOT_DIR}"
  fi
#fi

# Setup firmware boot cmdline
if [ "$ENABLE_UBOOTUSB" = true ] ; then
  CMDLINE="dwc_otg.lpm_enable=0 root=/dev/sda2 rootfstype=ext4 rootflags=commit=100,data=writeback elevator=deadline rootwait console=tty1 init=/bin/systemd"
else
  if [ "$ENABLE_SPLITFS" = true ] ; then
    CMDLINE="dwc_otg.lpm_enable=0 root=/dev/sda1 rootfstype=ext4 rootflags=commit=100,data=writeback elevator=deadline rootwait console=tty1 init=/bin/systemd"
  else
    CMDLINE="dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootfstype=ext4 rootflags=commit=100,data=writeback elevator=deadline rootwait console=tty1 init=/bin/systemd"
  fi
fi

# Add encrypted root partition to cmdline.txt
if [ "$ENABLE_CRYPTFS" = true ] ; then
  if [ "$ENABLE_SPLITFS" = true ] ; then
    CMDLINE=$(echo "${CMDLINE}" | sed "s/sda1/mapper\/${CRYPTFS_MAPPING} cryptdevice=\/dev\/sda1:${CRYPTFS_MAPPING}/")
  else
    if [ "$ENABLE_UBOOTUSB" = true ] ; then
      CMDLINE=$(echo "${CMDLINE}" | sed "s/sda2/mapper\/${CRYPTFS_MAPPING} cryptdevice=\/dev\/sda2:${CRYPTFS_MAPPING}/")
    else
      CMDLINE=$(echo "${CMDLINE}" | sed "s/mmcblk0p2/mapper\/${CRYPTFS_MAPPING} cryptdevice=\/dev\/mmcblk0p2:${CRYPTFS_MAPPING}/")
    fi
  fi
fi

# Enable Kernel messages on standard output
if [ "$ENABLE_PRINTK" = true ] ; then
  install_readonly files/sysctl.d/83-rpi-printk.conf "${ETC_DIR}/sysctl.d/83-rpi-printk.conf"
fi

# Install udev rule for serial alias - serial0 = console serial1=bluetooth
install_readonly files/etc/99-com.rules "${LIB_DIR}/udev/rules.d/99-com.rules"

# Remove IPv6 networking support
if [ "$ENABLE_IPV6" = false ] ; then
  CMDLINE="${CMDLINE} ipv6.disable=1"
fi

# Automatically assign predictable network interface names
if [ "$ENABLE_IFNAMES" = false ] ; then
  CMDLINE="${CMDLINE} net.ifnames=0"
else
  CMDLINE="${CMDLINE} net.ifnames=1"
fi

# Install firmware config
install_readonly files/boot/config.txt "${BOOT_DIR}/config.txt"

# Locks CPU frequency at maximum
if [ "$ENABLE_TURBO" = true ] ; then
  echo "force_turbo=1" >> "${BOOT_DIR}/config.txt"
  # helps to avoid sdcard corruption when force_turbo is enabled.
  echo "boot_delay=1" >> "${BOOT_DIR}/config.txt"
fi

if [ "$RPI_MODEL" = 0 ] || [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 3P ] ; then

  # Bluetooth enabled
  if [ "$ENABLE_BLUETOOTH" = true ] ; then
    # Create temporary directory for Bluetooth sources
    temp_dir=$(as_nobody mktemp -d)

    # Fetch Bluetooth sources
    as_nobody git -C "${temp_dir}" clone "${BLUETOOTH_URL}"

    # Copy downloaded sources
    mv "${temp_dir}/pi-bluetooth" "${R}/tmp/"

    # Bluetooth firmware from arch aur https://aur.archlinux.org/packages/pi-bluetooth/
    as_nobody wget -q -O "${R}/tmp/pi-bluetooth/LICENCE.broadcom_bcm43xx" https://aur.archlinux.org/cgit/aur.git/plain/LICENCE.broadcom_bcm43xx?h=pi-bluetooth
    as_nobody wget -q -O "${R}/tmp/pi-bluetooth/BCM43430A1.hcd" https://aur.archlinux.org/cgit/aur.git/plain/BCM43430A1.hcd?h=pi-bluetooth

    # Set permissions
    chown -R root:root "${R}/tmp/pi-bluetooth"

    # Install tools
    install_readonly "${R}/tmp/pi-bluetooth/usr/bin/btuart" "${R}/usr/bin/btuart"
    install_readonly "${R}/tmp/pi-bluetooth/usr/bin/bthelper" "${R}/usr/bin/bthelper"

	# make scripts executable
	chmod +x "${R}/usr/bin/bthelper"
	chmod +x "${R}/usr/bin/btuart"

    # Install bluetooth udev rule
    install_readonly "${R}/tmp/pi-bluetooth/lib/udev/rules.d/90-pi-bluetooth.rules" "${LIB_DIR}/udev/rules.d/90-pi-bluetooth.rules"

    # Install Firmware Flash file and apropiate licence
    mkdir -p "$BLUETOOTH_FIRMWARE_DIR"
    install_readonly "${R}/tmp/pi-bluetooth/LICENCE.broadcom_bcm43xx" "${BLUETOOTH_FIRMWARE_DIR}/LICENCE.broadcom_bcm43xx"
    install_readonly "${R}/tmp/pi-bluetooth/BCM43430A1.hcd" "${BLUETOOTH_FIRMWARE_DIR}/LICENCE.broadcom_bcm43xx"
    install_readonly "${R}/tmp/pi-bluetooth/debian/pi-bluetooth.bthelper@.service" "${ETC_DIR}/systemd/system/pi-bluetooth.bthelper@.service"
    install_readonly "${R}/tmp/pi-bluetooth/debian/pi-bluetooth.hciuart.service" "${ETC_DIR}/systemd/system/pi-bluetooth.hciuart.service"

    # Remove temporary directories
    rm -fr "${temp_dir}"
	rm -fr "${R}"/tmp/pi-bluetooth

    # Switch Pi3 Bluetooth function to use the mini-UART (ttyS0) and restore UART0/ttyAMA0 over GPIOs 14 & 15. Slow Bluetooth and slow cpu. Use /dev/ttyS0 instead of /dev/ttyAMA0
    if [ "$ENABLE_MINIUART_OVERLAY" = true ] ; then

	  # set overlay to swap ttyAMA0 and ttyS0
      echo "dtoverlay=pi3-miniuart-bt" >> "${BOOT_DIR}/config.txt"

	  # if force_turbo didn't lock cpu at high speed, lock it at low speed (XOR logic) or miniuart will be broken
	  if [ "$ENABLE_TURBO" = false ] ; then 
	    echo "core_freq=250" >> "${BOOT_DIR}/config.txt"
	  fi
	fi

	# Activate services
	chroot_exec systemctl enable pi-bluetooth.hciuart.service

  else # if ENABLE_BLUETOOTH = false
  	# set overlay to disable bluetooth
    echo "dtoverlay=pi3-disable-bt" >> "${BOOT_DIR}/config.txt"
  fi # ENABLE_BLUETOOTH end
fi

# may need sudo systemctl disable hciuart
if [ "$ENABLE_CONSOLE" = true ] ; then
  echo "enable_uart=1"  >> "${BOOT_DIR}/config.txt" 
  # add string to cmdline
  CMDLINE="${CMDLINE} console=serial0,115200"

  # Enable serial console systemd style
  chroot_exec systemctl enable serial-getty@serial0.service
else
  echo "enable_uart=0"  >> "${BOOT_DIR}/config.txt"
fi

if [ "$ENABLE_SYSTEMDSWAP" = true ] ; then
  # Create temporary directory for systemd-swap sources
  temp_dir=$(as_nobody mktemp -d)

  # Fetch systemd-swap sources
  as_nobody git -C "${temp_dir}" clone "${SYSTEMDSWAP_URL}"

  # Copy downloaded systemd-swap sources
  mv "${temp_dir}/systemd-swap" "${R}/tmp/"

  # Set permissions of the systemd-swap sources
  chown -R root:root "${R}/tmp/systemd-swap"

  # Remove temporary directory for systemd-swap sources
  rm -fr "${temp_dir}"

  # Change into downloaded src dir
  cd "${R}/tmp/systemd-swap" || exit

  # Build package
  . ./package.sh debian

  # Install package
  chroot_exec dpkg -i /tmp/systemd-swap/systemd-swap-*any.deb

  # Enable service
  chroot_exec systemctl enable systemd-swap

  # Change back into script root dir
  cd "${WORKDIR}" || exit
else
  # Enable ZSWAP in cmdline if systemd-swap is not used
  if [ "$KERNEL_ZSWAP" = true ] ; then
    CMDLINE="${CMDLINE} zswap.enabled=1 zswap.max_pool_percent=25 zswap.compressor=lz4"
  fi
fi
  if [ "$KERNEL_SECURITY" = true ] ; then
    CMDLINE="${CMDLINE} apparmor=1 security=apparmor" 
  fi

# Install firmware boot cmdline
echo "${CMDLINE}" > "${BOOT_DIR}/cmdline.txt"

# Setup minimal GPU memory allocation size: 16MB (no X)
if [ "$ENABLE_MINGPU" = true ] ; then
  echo "gpu_mem=16" >> "${BOOT_DIR}/config.txt"
fi

# Setup boot with initramfs
if [ "$ENABLE_INITRAMFS" = true ] ; then
  echo "initramfs initramfs-${KERNEL_VERSION} followkernel" >> "${BOOT_DIR}/config.txt"
fi

# Create firmware configuration and cmdline symlinks
ln -sf firmware/config.txt "${R}/boot/config.txt"
ln -sf firmware/cmdline.txt "${R}/boot/cmdline.txt"

# Install and setup kernel modules to load at boot
mkdir -p "${LIB_DIR}/modules-load.d/"
install_readonly files/modules/rpi2.conf "${LIB_DIR}/modules-load.d/rpi2.conf"

# Load hardware random module at boot
if [ "$ENABLE_HWRANDOM" = true ] && [ "$BUILD_KERNEL" = false ] ; then
  sed -i "s/^# bcm2708_rng/bcm2708_rng/" "${LIB_DIR}/modules-load.d/rpi2.conf"
fi

# Load sound module at boot
if [ "$ENABLE_SOUND" = true ] ; then
  sed -i "s/^# snd_bcm2835/snd_bcm2835/" "${LIB_DIR}/modules-load.d/rpi2.conf"
else
  echo "dtparam=audio=off" >> "${BOOT_DIR}/config.txt"
fi

# Enable I2C interface
if [ "$ENABLE_I2C" = true ] ; then
  echo "dtparam=i2c_arm=on" >> "${BOOT_DIR}/config.txt"
  sed -i "s/^# i2c-bcm2708/i2c-bcm2708/" "${LIB_DIR}/modules-load.d/rpi2.conf"
  sed -i "s/^# i2c-dev/i2c-dev/" "${LIB_DIR}/modules-load.d/rpi2.conf"
fi

# Enable SPI interface
if [ "$ENABLE_SPI" = true ] ; then
  echo "dtparam=spi=on" >> "${BOOT_DIR}/config.txt"
  echo "spi-bcm2708" >> "${LIB_DIR}/modules-load.d/rpi2.conf"
  if [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 3P ]; then
    sed -i "s/spi-bcm2708/spi-bcm2835/" "${LIB_DIR}/modules-load.d/rpi2.conf"
  fi
fi

# Disable RPi2/3 under-voltage warnings
if [ -n "$DISABLE_UNDERVOLT_WARNINGS" ] ; then
  echo "avoid_warnings=${DISABLE_UNDERVOLT_WARNINGS}" >> "${BOOT_DIR}/config.txt"
fi

# Install kernel modules blacklist
mkdir -p "${ETC_DIR}/modprobe.d/"
install_readonly files/modules/raspi-blacklist.conf "${ETC_DIR}/modprobe.d/raspi-blacklist.conf"

# Install sysctl.d configuration files
install_readonly files/sysctl.d/81-rpi-vm.conf "${ETC_DIR}/sysctl.d/81-rpi-vm.conf"
