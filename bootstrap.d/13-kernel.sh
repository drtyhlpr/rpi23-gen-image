#
# Build and Setup RPi2/3 Kernel
#

# Load utility functions
. ./functions.sh


# Setup source directory
mkdir -p "${R}/usr/src"

# Copy existing kernel sources into chroot directory
if [ -n "$KERNELSRC_DIR" ] && [ -d "$KERNELSRC_DIR" ] ; then
  # Copy kernel sources
  cp -rL "${KERNELSRC_DIR}" "${R}/usr/src"

  # Clean the kernel sources
  make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" mrproper
else
  echo "error: $KERNELSRC_DIR not existing!"
  cleanup
  exit 1
fi


# Check if kernel compilation was successful
if [ ! -r "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/zImage" ] ; then
  echo "error: kernel compilation failed! (zImage not found)"
  cleanup
  exit 1
fi

# Install kernel modules
if [ "$ENABLE_REDUCE" = true ] ; then
  make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=../../.. modules_install
else
  make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH=../../.. modules_install

  # Install kernel firmware
  make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_FW_PATH=../../../lib firmware_install
fi

# Install kernel headers
if [ "$KERNEL_HEADERS" = true ] && [ "$KERNEL_REDUCE" = false ] ; then
  make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_HDR_PATH=../.. headers_install
fi

# Prepare boot (firmware) directory
mkdir "${BOOT_DIR}"

# Get kernel release version
KERNEL_VERSION=`cat "${KERNEL_DIR}/include/config/kernel.release"`

# Copy kernel configuration file to the boot directory
install_readonly "${KERNEL_DIR}/.config" "${R}/boot/config-${KERNEL_VERSION}"


# Copy device tree binaries
install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/${DTB_FILE}" "${BOOT_DIR}/"


if [ "$ENABLE_UBOOT" = false ] ; then
  # Convert and copy zImage kernel to the boot directory
  "${KERNEL_DIR}/scripts/mkknlimg" "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/zImage" "${BOOT_DIR}/${KERNEL_IMAGE}"
else
  # Copy zImage kernel to the boot directory
  install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/zImage" "${BOOT_DIR}/${KERNEL_IMAGE}"
fi

# Remove kernel sources
if [ "$KERNEL_REMOVESRC" = true ] ; then
  rm -fr "${KERNEL_DIR}"
fi

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
  # Install latest boot binaries from raspberry/firmware github
  wget -q -O "${BOOT_DIR}/bootcode.bin" "${FIRMWARE_URL}/bootcode.bin"
  wget -q -O "${BOOT_DIR}/fixup.dat" "${FIRMWARE_URL}/fixup.dat"
  wget -q -O "${BOOT_DIR}/fixup_cd.dat" "${FIRMWARE_URL}/fixup_cd.dat"
  wget -q -O "${BOOT_DIR}/fixup_x.dat" "${FIRMWARE_URL}/fixup_x.dat"
  wget -q -O "${BOOT_DIR}/start.elf" "${FIRMWARE_URL}/start.elf"
  wget -q -O "${BOOT_DIR}/start_cd.elf" "${FIRMWARE_URL}/start_cd.elf"
  wget -q -O "${BOOT_DIR}/start_x.elf" "${FIRMWARE_URL}/start_x.elf"
fi



# Setup firmware boot cmdline
if [ "$ENABLE_SPLITFS" = true ] ; then
  CMDLINE="dwc_otg.lpm_enable=0 root=/dev/sda1 rootfstype=ext4 rootflags=commit=100,data=writeback elevator=deadline rootwait console=tty1"
else
  CMDLINE="dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootfstype=ext4 rootflags=commit=100,data=writeback elevator=deadline rootwait console=tty1 cma=256M@512M"
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
if [ "$RELEASE" = "stretch" ] ; then
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
if [ "$RPI_MODEL" = 3 ] ; then
  if [ "$ENABLE_CONSOLE" = true ] ; then
    echo "dtoverlay=pi3-miniuart-bt" >> "${BOOT_DIR}/config.txt"
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
fi

# Install kernel modules blacklist
mkdir -p "${ETC_DIR}/modprobe.d/"
install_readonly files/modules/raspi-blacklist.conf "${ETC_DIR}/modprobe.d/raspi-blacklist.conf"

# Install and setup fstab
install_readonly files/mount/fstab "${ETC_DIR}/fstab"

# Add usb/sda disk root partition to fstab
if [ "$ENABLE_SPLITFS" = true ] && [ "$ENABLE_CRYPTFS" = false ] ; then
  sed -i "s/mmcblk0p2/sda1/" "${ETC_DIR}/fstab"
fi

# Add encrypted root partition to fstab and crypttab
if [ "$ENABLE_CRYPTFS" = true ] ; then
  # Replace fstab root partition with encrypted partition mapping
  sed -i "s/mmcblk0p2/mapper\/${CRYPTFS_MAPPING}/" "${ETC_DIR}/fstab"

  # Add encrypted partition to crypttab and fstab
  install_readonly files/mount/crypttab "${ETC_DIR}/crypttab"
  echo "${CRYPTFS_MAPPING} /dev/mmcblk0p2 none luks" >> "${ETC_DIR}/crypttab"

  if [ "$ENABLE_SPLITFS" = true ] ; then
    # Add usb/sda disk to crypttab
    sed -i "s/mmcblk0p2/sda1/" "${ETC_DIR}/crypttab"
  fi
fi

# Generate initramfs file
if [ "$ENABLE_INITRAMFS" = true ] ; then
  if [ "$ENABLE_CRYPTFS" = true ] ; then
    # Include initramfs scripts to auto expand encrypted root partition
    if [ "$EXPANDROOT" = true ] ; then
      install_exec files/initramfs/expand_encrypted_rootfs "${ETC_DIR}/initramfs-tools/scripts/init-premount/expand_encrypted_rootfs"
      install_exec files/initramfs/expand-premount "${ETC_DIR}/initramfs-tools/scripts/local-premount/expand-premount"
      install_exec files/initramfs/expand-tools "${ETC_DIR}/initramfs-tools/hooks/expand-tools"
    fi

    # Disable SSHD inside initramfs
    printf "#\n# DROPBEAR: [ y | n ]\n#\n\nDROPBEAR=n\n" >> "${ETC_DIR}/initramfs-tools/initramfs.conf"

    # Dummy mapping required by mkinitramfs
    echo "0 1 crypt $(echo ${CRYPTFS_CIPHER} | cut -d ':' -f 1) ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff 0 7:0 4096" | chroot_exec dmsetup create "${CRYPTFS_MAPPING}"

    # Generate initramfs with encrypted root partition support
    chroot_exec mkinitramfs -o "/boot/firmware/initramfs-${KERNEL_VERSION}" "${KERNEL_VERSION}"

    # Remove dummy mapping
    chroot_exec cryptsetup close "${CRYPTFS_MAPPING}"
  else
    # Generate initramfs without encrypted root partition support
    chroot_exec mkinitramfs -o "/boot/firmware/initramfs-${KERNEL_VERSION}" "${KERNEL_VERSION}"
  fi
fi

# Install sysctl.d configuration files
install_readonly files/sysctl.d/81-rpi-vm.conf "${ETC_DIR}/sysctl.d/81-rpi-vm.conf"
