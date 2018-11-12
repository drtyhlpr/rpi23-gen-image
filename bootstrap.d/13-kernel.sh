#!/bin/bash
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
    # Copy kernel sources and include hidden files
    cp -r "${KERNELSRC_DIR}/". "${R}/usr/src/linux"

    # Clean the kernel sources
    if [ "$KERNELSRC_CLEAN" = true ] && [ "$KERNELSRC_PREBUILT" = false ] ; then
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" mrproper
    fi
  else # KERNELSRC_DIR=""
    # Create temporary directory for kernel sources
    temp_dir=$(as_nobody mktemp -d)

    # Fetch current RPi2/3 kernel sources
    if [ -z "${KERNEL_BRANCH}" ] ; then
      as_nobody -H git -C "${temp_dir}" clone --depth=1 "${KERNEL_URL}" linux
    else
      as_nobody -H git -C "${temp_dir}" clone --depth=1 --branch "${KERNEL_BRANCH}" "${KERNEL_URL}" linux
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

      # Set kernel configuration parameters to enable qemu emulation
      if [ "$ENABLE_QEMU" = true ] ; then
        echo "CONFIG_FHANDLE=y" >> "${KERNEL_DIR}"/.config
        echo "CONFIG_LBDAF=y" >> "${KERNEL_DIR}"/.config

        if [ "$ENABLE_CRYPTFS" = true ] ; then
          {
            echo "CONFIG_EMBEDDED=y"
            echo "CONFIG_EXPERT=y"
            echo "CONFIG_DAX=y"
            echo "CONFIG_MD=y"
            echo "CONFIG_BLK_DEV_MD=y"
            echo "CONFIG_MD_AUTODETECT=y"
            echo "CONFIG_BLK_DEV_DM=y"
            echo "CONFIG_BLK_DEV_DM_BUILTIN=y"
            echo "CONFIG_DM_CRYPT=y"
            echo "CONFIG_CRYPTO_BLKCIPHER=y"
            echo "CONFIG_CRYPTO_CBC=y"
            echo "CONFIG_CRYPTO_XTS=y"
            echo "CONFIG_CRYPTO_SHA512=y"
            echo "CONFIG_CRYPTO_MANAGER=y"       
          } >> "${KERNEL_DIR}"/.config
        fi
      fi

      # Copy custom kernel configuration file
      if [ -n "$KERNELSRC_USRCONFIG" ] ; then
        cp "$KERNELSRC_USRCONFIG" "${KERNEL_DIR}"/.config
      fi

      # Set kernel configuration parameters to their default values
      if [ "$KERNEL_OLDDEFCONFIG" = true ] ; then
        make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
      fi

      # Start menu-driven kernel configuration (interactive)
      if [ "$KERNEL_MENUCONFIG" = true ] ; then
        make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" menuconfig
      fi
    fi

    # Use ccache to cross compile the kernel
    if [ "$KERNEL_CCACHE" = true ] ; then
      cc="ccache ${CROSS_COMPILE}gcc"
    else
      cc="${CROSS_COMPILE}gcc"
    fi

    # Cross compile kernel and dtbs
    make -C "${KERNEL_DIR}" -j"${KERNEL_THREADS}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="${cc}" "${KERNEL_BIN_IMAGE}" dtbs

    # Cross compile kernel modules
    if [ "$(grep "CONFIG_MODULES=y" "${KERNEL_DIR}/.config")" ] ; then
      make -C "${KERNEL_DIR}" -j"${KERNEL_THREADS}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="${cc}" modules
    fi
  fi

  # Check if kernel compilation was successful
  if [ ! -r "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/${KERNEL_BIN_IMAGE}" ] ; then
    echo "error: kernel compilation failed! (kernel image not found)"
    cleanup
    exit 1
  fi

  # Install kernel modules
  if [ "$ENABLE_REDUCE" = true ] ; then
    if [ "$(grep "CONFIG_MODULES=y" "${KERNEL_DIR}/.config")" ] ; then
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=../../.. modules_install
    fi
  else
    if [ "$(grep "CONFIG_MODULES=y" "${KERNEL_DIR}/.config")" ] ; then
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH=../../.. modules_install
    fi

    # Install kernel firmware
    if [ "$(grep "^firmware_install:" "${KERNEL_DIR}/Makefile")" ] ; then
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_FW_PATH=../../../lib firmware_install
    fi
  fi

  # Install kernel headers
  if [ "$KERNEL_HEADERS" = true ] && [ "$KERNEL_REDUCE" = false ] ; then
    make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_HDR_PATH=../.. headers_install
  fi

  # Prepare boot (firmware) directory
  mkdir "${BOOT_DIR}"

  # Get kernel release version
  KERNEL_VERSION=$(cat "${KERNEL_DIR}/include/config/kernel.release")

  # Copy kernel configuration file to the boot directory
  install_readonly "${KERNEL_DIR}/.config" "${R}/boot/config-${KERNEL_VERSION}"

  # Prepare device tree directory
  mkdir "${BOOT_DIR}/overlays"
  
  # Ensure the proper .dtb is located
  if [ "$KERNEL_ARCH" = "arm" ] ; then
    for dtb in "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/"*.dtb ; do
      if [ -f "${dtb}" ] ; then
        install_readonly "${dtb}" "${BOOT_DIR}/"
      fi
    done
  else
    for dtb in "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/broadcom/"*.dtb ; do
      if [ -f "${dtb}" ] ; then
        install_readonly "${dtb}" "${BOOT_DIR}/"
      fi
    done
  fi

  # Copy compiled dtb device tree files
  if [ -d "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/overlays" ] ; then
    for dtb in "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/overlays/"*.dtb ; do
      if [ -f "${dtb}" ] ; then
        install_readonly "${dtb}" "${BOOT_DIR}/overlays/"
      fi
    done

    if [ -f "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/overlays/README" ] ; then
      install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/overlays/README" "${BOOT_DIR}/overlays/README"
    fi
  fi

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
    # Prepare compiled kernel modules
    if [ "$(grep "CONFIG_MODULES=y" "${KERNEL_DIR}/.config")" ] ; then
      if [ "$(grep "^modules_prepare:" "${KERNEL_DIR}/Makefile")" ] ; then
        make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" modules_prepare
      fi

      # Create symlinks for kernel modules
      chroot_exec ln -sf /usr/src/linux "/lib/modules/${KERNEL_VERSION}/build"
      chroot_exec ln -sf /usr/src/linux "/lib/modules/${KERNEL_VERSION}/source"
    fi
  fi
elif [ "$BUILD_KERNEL" = false ] ; then
  echo " Install precompiled kernel..."
  echo "error: not implemented"
  # Check if kernel installation was successful
  VMLINUZ="$(ls -1 "${R}"/boot/vmlinuz-* | sort | tail -n 1)"
  if [ -z "$VMLINUZ" ] ; then
    echo "error: kernel installation failed! (/boot/vmlinuz-* not found)"
    cleanup
    exit 1
  fi
  # Copy vmlinuz kernel to the boot directory
  install_readonly "${VMLINUZ}" "${BOOT_DIR}/${KERNEL_IMAGE}"

  if [ "$SET_ARCH" = 64 ] ; then
  echo "Using precompiled arm64 kernel"
  else
    echo "error: no precompiled arm64 (bcmrpi3) kernel found"
    exit 1
    # inset precompiled 64 bit kernel code here
  fi
#fi build_kernel=true
fi
