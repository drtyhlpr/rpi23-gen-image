#
# Build and Setup RPi2/3 Kernel
#

# Load utility functions
. ./functions.sh

# Fetch and build latest raspberry kernel
if [ "$BUILD_KERNEL" = true ] ; then
  # Setup source directory
  mkdir -p "${R}/usr/src/linux"

  # Copy existing kernel sources into chroot directory
  if [ -n "$KERNELSRC_DIR" ] && [ -d "$KERNELSRC_DIR" ] ; then
    # Copy kernel sources
    cp -r "${KERNELSRC_DIR}/"* "${R}/usr/src/linux"

    # Clean the kernel sources
    if [ "$KERNELSRC_CLEAN" = true ] && [ "$KERNELSRC_PREBUILT" = false ] ; then
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" mrproper
    fi
  else # KERNELSRC_DIR=""
    # Create temporary directory for kernel sources
    temp_dir=$(as_nobody mktemp -d)

    # Fetch current RPi2/3 kernel sources
    if [ -z "${KERNEL_BRANCH}" ] ; then
      as_nobody git -C "${temp_dir}" clone --depth=1 "${KERNEL_URL}" linux
    else
      as_nobody git -C "${temp_dir}" clone --depth=1 --branch "${KERNEL_BRANCH}" "${KERNEL_URL}" linux
   fi
    
    # Copy downloaded kernel sources
    cp -r "${temp_dir}/linux/"* "${R}/usr/src/linux/"

    # Remove temporary directory for kernel sources
    rm -fr "${temp_dir}"

    # Set permissions of the kernel sources
    chown -R root:root "${R}/usr/src"
  fi

  # Calculate optimal number of kernel building threads
  if [ "$KERNEL_THREADS" = "1" ] && [ -r /proc/cpuinfo ] ; then
    KERNEL_THREADS=$(grep -c processor /proc/cpuinfo)
  fi

  # Configure and build kernel
  if [ "$KERNELSRC_PREBUILT" = false ] ; then
    # Remove device, network and filesystem drivers from kernel configuration
    if [ "$KERNEL_REDUCE" = true ] ; then
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" "${KERNEL_DEFCONFIG}"
      sed -i\
      -e "s/\(^CONFIG_SND.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_SOUND.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_AC97.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_VIDEO_.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_MEDIA_TUNER.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_DVB.*\=\)[ym]/\1n/"\
      -e "s/\(^CONFIG_REISERFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_JFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_XFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_GFS2.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_OCFS2.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_BTRFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_HFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_JFFS2.*\=\)[ym]/\1n/"\
      -e "s/\(^CONFIG_UBIFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_SQUASHFS.*\=\)[ym]/\1n/"\
      -e "s/\(^CONFIG_W1.*\=\)[ym]/\1n/"\
      -e "s/\(^CONFIG_HAMRADIO.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_CAN.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_IRDA.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_BT_.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_WIMAX.*\=\)[ym]/\1n/"\
      -e "s/\(^CONFIG_6LOWPAN.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_IEEE802154.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_NFC.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_FB_TFT=.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_TOUCHSCREEN.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_USB_GSPCA_.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_DRM.*\=\).*/\1n/"\
      "${KERNEL_DIR}/.config"
    fi

    if [ "$KERNELSRC_CONFIG" = true ] ; then
      # Load default raspberry kernel configuration
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" "${KERNEL_DEFCONFIG}"

      if [ ! -z "$KERNELSRC_USRCONFIG" ] ; then
        cp $KERNELSRC_USRCONFIG ${KERNEL_DIR}/.config
      fi

      # Start menu-driven kernel configuration (interactive)
      if [ "$KERNEL_MENUCONFIG" = true ] ; then
        make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" menuconfig
      fi
    fi

    # Cross compile kernel and modules
    make -C "${KERNEL_DIR}" -j${KERNEL_THREADS} ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" "${KERNEL_BIN_IMAGE}" modules dtbs
  fi

  # Check if kernel compilation was successful
  if [ ! -r "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/${KERNEL_BIN_IMAGE}" ] ; then
    echo "error: kernel compilation failed! (kernel image not found)"
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

  # Copy dts and dtb device tree sources and binaries
  mkdir "${BOOT_DIR}/overlays"
  
  # Ensure the proper .dtb is located
  if [ "$KERNEL_ARCH" = "arm" ] ; then
    install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/"*.dtb "${BOOT_DIR}/"
  else
    install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/broadcom/"*.dtb "${BOOT_DIR}/"
  fi

  install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/overlays/"*.dtb* "${BOOT_DIR}/overlays/"
  install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/overlays/README" "${BOOT_DIR}/overlays/README"

  if [ "$ENABLE_UBOOT" = false ] ; then
    # Convert and copy kernel image to the boot directory
    "${KERNEL_DIR}/scripts/mkknlimg" "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/${KERNEL_BIN_IMAGE}" "${BOOT_DIR}/${KERNEL_IMAGE}"
  else
    # Copy kernel image to the boot directory
    install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/${KERNEL_BIN_IMAGE}" "${BOOT_DIR}/${KERNEL_IMAGE}"
  fi

  # Remove kernel sources
  if [ "$KERNEL_REMOVESRC" = true ] ; then
    rm -fr "${KERNEL_DIR}"
  else
    make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" modules_prepare

    # Create symlinks for kernel modules
    chroot_exec ln -sf /usr/src/linux "/lib/modules/${KERNEL_VERSION}/build"
    chroot_exec ln -sf /usr/src/linux "/lib/modules/${KERNEL_VERSION}/source"
  fi

else # BUILD_KERNEL=false
  # Kernel installation
  chroot_exec apt-get -qq -y --no-install-recommends install linux-image-"${COLLABORA_KERNEL}" raspberrypi-bootloader-nokernel

  # Install flash-kernel last so it doesn't try (and fail) to detect the platform in the chroot
  chroot_exec apt-get -qq -y install flash-kernel

  # Check if kernel installation was successful
  VMLINUZ="$(ls -1 ${R}/boot/vmlinuz-* | sort | tail -n 1)"
  if [ -z "$VMLINUZ" ] ; then
    echo "error: kernel installation failed! (/boot/vmlinuz-* not found)"
    cleanup
    exit 1
  fi
  # Copy vmlinuz kernel to the boot directory
  install_readonly "${VMLINUZ}" "${BOOT_DIR}/${KERNEL_IMAGE}"
fi
