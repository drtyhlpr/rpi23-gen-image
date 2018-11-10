#
# Setup RPi2/3 config and cmdline
#

# Load utility functions
. ./functions.sh

if [ "$BUILD_KERNEL" = true ] ; then
  if [ -n "$RPI_FIRMWARE_DIR" ] && [ -d "$RPI_FIRMWARE_DIR" ] ; then
    # Install boot binaries from local directory
    cp ${RPI_FIRMWARE_DIR}/boot/bootcode.bin ${BOOT_DIR}/bootcode.bin
    cp ${RPI_FIRMWARE_DIR}/boot/fixup.dat ${BOOT_DIR}/fixup.dat
    cp ${RPI_FIRMWARE_DIR}/boot/fixup_cd.dat ${BOOT_DIR}/fixup_cd.dat
    cp ${RPI_FIRMWARE_DIR}/boot/fixup_x.dat ${BOOT_DIR}/fixup_x.dat
    cp ${RPI_FIRMWARE_DIR}/boot/start.elf ${BOOT_DIR}/start.elf
    cp ${RPI_FIRMWARE_DIR}/boot/start_cd.elf ${BOOT_DIR}/start_cd.elf
    cp ${RPI_FIRMWARE_DIR}/boot/start_x.elf ${BOOT_DIR}/start_x.elf
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
fi

# Setup firmware boot cmdline
if [ "$ENABLE_SPLITFS" = true ] ; then
  CMDLINE="dwc_otg.lpm_enable=0 root=/dev/sda1 rootfstype=ext4 rootflags=commit=100,data=writeback elevator=deadline rootwait console=tty1"
else
  CMDLINE="dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootfstype=ext4 rootflags=commit=100,data=writeback elevator=deadline rootwait console=tty1"
fi

# Add encrypted root partition to cmdline.txt
if [ "$ENABLE_CRYPTFS" = true ] ; then
  if [ "$ENABLE_SPLITFS" = true ] ; then
    CMDLINE=$(echo ${CMDLINE} | sed "s/sda1/mapper\/${CRYPTFS_MAPPING} cryptdevice=\/dev\/sda1:${CRYPTFS_MAPPING}/")
  else
    CMDLINE=$(echo ${CMDLINE} | sed "s/mmcblk0p2/mapper\/${CRYPTFS_MAPPING} cryptdevice=\/dev\/mmcblk0p2:${CRYPTFS_MAPPING}/")
  fi
fi

# Add serial console support
if [ "$ENABLE_CONSOLE" = true ] ; then
  CMDLINE="${CMDLINE} console=ttyAMA0,115200 kgdboc=ttyAMA0,115200"
fi

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

# Set init to systemd if required by Debian release
if [ "$RELEASE" = "stretch" ] || [ "$RELEASE" = "buster" ] ; then
  CMDLINE="${CMDLINE} init=/bin/systemd"
fi

# Install firmware boot cmdline
echo "${CMDLINE}" > "${BOOT_DIR}/cmdline.txt"

# Install firmware config
install_readonly files/boot/config.txt "${BOOT_DIR}/config.txt"

# Setup minimal GPU memory allocation size: 16MB (no X)
if [ "$ENABLE_MINGPU" = true ] ; then
  echo "gpu_mem=16" >> "${BOOT_DIR}/config.txt"
fi

# Setup boot with initramfs
if [ "$ENABLE_INITRAMFS" = true ] ; then
  echo "initramfs initramfs-${KERNEL_VERSION} followkernel" >> "${BOOT_DIR}/config.txt"
fi

# Disable RPi3 Bluetooth and restore ttyAMA0 serial device
if [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 3P ] ; then
  if [ "$ENABLE_CONSOLE" = true ] && [ "$ENABLE_UBOOT" = false ] ; then
    echo "dtoverlay=pi3-disable-bt" >> "${BOOT_DIR}/config.txt"
    echo "enable_uart=1" >> "${BOOT_DIR}/config.txt"
  fi
fi

# Create firmware configuration and cmdline symlinks
ln -sf firmware/config.txt "${R}/boot/config.txt"
ln -sf firmware/cmdline.txt "${R}/boot/cmdline.txt"

# Install and setup kernel modules to load at boot
mkdir -p "${R}/lib/modules-load.d/"
install_readonly files/modules/rpi2.conf "${R}/lib/modules-load.d/rpi2.conf"

# Load hardware random module at boot
if [ "$ENABLE_HWRANDOM" = true ] && [ "$BUILD_KERNEL" = false ] ; then
   sed -i "s/^# bcm2708_rng/bcm2708_rng/" "${R}/lib/modules-load.d/rpi2.conf"
fi

# Load sound module at boot
if [ "$ENABLE_SOUND" = true ] ; then
  sed -i "s/^# snd_bcm2835/snd_bcm2835/" "${R}/lib/modules-load.d/rpi2.conf"
else
  echo "dtparam=audio=off" >> "${BOOT_DIR}/config.txt"
fi

# Enable I2C interface
if [ "$ENABLE_I2C" = true ] ; then
  echo "dtparam=i2c_arm=on" >> "${BOOT_DIR}/config.txt"
  sed -i "s/^# i2c-bcm2708/i2c-bcm2708/" "${R}/lib/modules-load.d/rpi2.conf"
  sed -i "s/^# i2c-dev/i2c-dev/" "${R}/lib/modules-load.d/rpi2.conf"
fi

# Enable SPI interface
if [ "$ENABLE_SPI" = true ] ; then
  echo "dtparam=spi=on" >> "${BOOT_DIR}/config.txt"
  echo "spi-bcm2708" >> "${R}/lib/modules-load.d/rpi2.conf"
  if [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 3P ]; then
    sed -i "s/spi-bcm2708/spi-bcm2835/" "${R}/lib/modules-load.d/rpi2.conf"
  fi
fi

# Disable RPi2/3 under-voltage warnings
if [ ! -z "$DISABLE_UNDERVOLT_WARNINGS" ] ; then
  echo "avoid_warnings=${DISABLE_UNDERVOLT_WARNINGS}" >> "${BOOT_DIR}/config.txt"
fi

# Install kernel modules blacklist
mkdir -p "${ETC_DIR}/modprobe.d/"
install_readonly files/modules/raspi-blacklist.conf "${ETC_DIR}/modprobe.d/raspi-blacklist.conf"

# Install sysctl.d configuration files
install_readonly files/sysctl.d/81-rpi-vm.conf "${ETC_DIR}/sysctl.d/81-rpi-vm.conf"
