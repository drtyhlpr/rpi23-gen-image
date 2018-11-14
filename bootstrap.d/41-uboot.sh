#!/bin/bash
#
# Build and Setup U-Boot
#

# Load utility functions
. ./functions.sh

# Fetch and build U-Boot bootloader
if [ "$ENABLE_UBOOT" = true ] ; then
  # Install c/c++ build environment inside the chroot
  chroot_install_cc

  # Copy existing U-Boot sources into chroot directory
  if [ -n "$UBOOTSRC_DIR" ] && [ -d "$UBOOTSRC_DIR" ] ; then
    # Copy local U-Boot sources
    cp -r "${UBOOTSRC_DIR}" "${R}/tmp"
  else
    # Create temporary directory for U-Boot sources
    temp_dir=$(as_nobody mktemp -d)

    # Fetch U-Boot sources
    as_nobody git -C "${temp_dir}" clone "${UBOOT_URL}"

    # Copy downloaded U-Boot sources
    mv "${temp_dir}/u-boot" "${R}/tmp/"

    # Set permissions of the U-Boot sources
    chown -R root:root "${R}/tmp/u-boot"

    # Remove temporary directory for U-Boot sources
    rm -fr "${temp_dir}"
  fi

  # Build and install U-Boot inside chroot
  chroot_exec make -j"${KERNEL_THREADS}" -C /tmp/u-boot/ "${UBOOT_CONFIG}" all

  # Copy compiled bootloader binary and set config.txt to load it
  install_exec "${R}/tmp/u-boot/tools/mkimage" "${R}/usr/sbin/mkimage"
  install_readonly "${R}/tmp/u-boot/u-boot.bin" "${BOOT_DIR}/u-boot.bin"
  printf "\n# boot u-boot kernel\nkernel=u-boot.bin\n" >> "${BOOT_DIR}/config.txt"

  # Install and setup U-Boot command file
  # Set correct KERNEL_IMAGE in mkfile
  sed -i "s/kernel7.img/$KERNEL_BIN_IMAGE/g" files/boot/uboot.mkimage
  # Set correct DTB_FILE
  sed -i "s/bcm2709-rpi-2-b.dtb/$DTB_FILE/g" files/boot/uboot.mkimage
  install_readonly files/boot/uboot.mkimage "${BOOT_DIR}/uboot.mkimage"
  printf "# Set the kernel boot command line\nsetenv bootargs \"earlyprintk ${CMDLINE}\"\n\n$(cat "${BOOT_DIR}"/uboot.mkimage)" > "${BOOT_DIR}/uboot.mkimage"

  if [ "$ENABLE_INITRAMFS" = true ] ; then
    # Convert generated initramfs for U-Boot using mkimage
    chroot_exec /usr/sbin/mkimage -A "${KERNEL_ARCH}" -T ramdisk -C none -n "initramfs-${KERNEL_VERSION}" -d "/boot/firmware/initramfs-${KERNEL_VERSION}" "/boot/firmware/initramfs-${KERNEL_VERSION}.uboot"

    # Remove original initramfs file
    rm -f "${BOOT_DIR}/initramfs-${KERNEL_VERSION}"

    # Configure U-Boot to load generated initramfs
    printf "# Set initramfs file\nsetenv initramfs initramfs-${KERNEL_VERSION}.uboot\n\n$(cat "${BOOT_DIR}"/uboot.mkimage)" > "${BOOT_DIR}/uboot.mkimage"
    printf "\nbootz \${kernel_addr_r} \${ramdisk_addr_r} \${fdt_addr_r}" >> "${BOOT_DIR}/uboot.mkimage"
  else # ENABLE_INITRAMFS=false
    # Remove initramfs from U-Boot mkfile
    sed -i '/.*initramfs.*/d' "${BOOT_DIR}/uboot.mkimage"

    if [ "$BUILD_KERNEL" = false ] ; then
        # Remove dtbfile from U-Boot mkfile
        sed -i '/.*dtbfile.*/d' "${BOOT_DIR}/uboot.mkimage"
        printf "\nbootz \${kernel_addr_r}" >> "${BOOT_DIR}/uboot.mkimage"
    else
      printf "\nbootz \${kernel_addr_r} - \${fdt_addr_r}" >> "${BOOT_DIR}/uboot.mkimage"
    fi
  fi
  
  if [ "$SET_ARCH" = 64 ] ; then
    echo "Setting up config.txt to boot 64bit uboot"
	printf "\n# Tell u-boot a 64bit kernel is used\narm_64bit=1\n" >> "${BOOT_DIR}/config.txt"
	printf "\n# Device tree start addr\ndevice_tree_address=0x100\n" >> "${BOOT_DIR}/config.txt"
	printf "\n# Device tree stop  adrr\ndevice_tree_end=0x8000\n" >> "${BOOT_DIR}/config.txt"
  fi

  # Set mkfile to use the correct mach id
  if [ "$ENABLE_QEMU" = true ] ; then
    sed -i "s/^\(setenv machid \).*/\10x000008e0/" "${BOOT_DIR}/uboot.mkimage"
  fi
  
    # Set mkfile to use the correct dtb file
  sed -i "s/^\(setenv dtbfile \).*/\1${DTB_FILE}/" "${BOOT_DIR}/uboot.mkimage"

  # Set mkfile to use kernel image
  sed  "s/^\(fatload mmc 0:1 \${kernel_addr_r} \).*/\1${KERNEL_IMAGE}/" "${BOOT_DIR}/uboot.mkimage"

  # Remove all leading blank lines
  sed -i "/./,\$!d" "${BOOT_DIR}/uboot.mkimage"

  # Generate U-Boot bootloader image
  chroot_exec /usr/sbin/mkimage -A "${KERNEL_ARCH}" -O linux -T script -C none -a 0x00000000 -e 0x00000000 -n "RPi${RPI_MODEL}" -d /boot/firmware/uboot.mkimage /boot/firmware/boot.scr

  # Remove U-Boot sources
  rm -fr "${R}/tmp/u-boot"
fi

