#
# Build and Setup U-Boot
#

# Load utility functions
. ./functions.sh

# Install gcc/c++ build environment inside the chroot
if [ "$ENABLE_UBOOT" = true ] || [ "$ENABLE_FBTURBO" = true ] ; then
  COMPILER_PACKAGES=$(chroot_exec apt-get -s install ${COMPILER_PACKAGES} | grep "^Inst " | awk -v ORS=" " '{ print $2 }')
  chroot_exec apt-get -q -y --force-yes --no-install-recommends install ${COMPILER_PACKAGES}
fi

# Fetch and build U-Boot bootloader
if [ "$ENABLE_UBOOT" = true ] ; then
  # Fetch U-Boot bootloader sources
  git -C "${R}/tmp" clone "${UBOOT_URL}"

  # Build and install U-Boot inside chroot
  chroot_exec make -C /tmp/u-boot/ ${UBOOT_CONFIG} all

  # Copy compiled bootloader binary and set config.txt to load it
  install_exec "${R}/tmp/u-boot/tools/mkimage" "${R}/usr/sbin/mkimage"
  install_readonly "${R}/tmp/u-boot/u-boot.bin" "${BOOTDIR}/u-boot.bin"
  printf "\n# boot u-boot kernel\nkernel=u-boot.bin\n" >> "${BOOTDIR}/config.txt"

  # Install and setup U-Boot command file
  install_readonly files/boot/uboot.mkimage "${BOOTDIR}/uboot.mkimage"
  printf "# Set the kernel boot command line\nsetenv bootargs \"earlyprintk ${CMDLINE}\"\n\n$(cat ${BOOTDIR}/uboot.mkimage)" > "${BOOTDIR}/uboot.mkimage"

  if [ "$ENABLE_INITRAMFS" = true ] ; then
    # Convert generated initramfs for U-Boot using mkimage
    chroot_exec /usr/sbin/mkimage -A "${KERNEL_ARCH}" -T ramdisk -C none -n "initramfs-${KERNEL_VERSION}" -d "/boot/firmware/initramfs-${KERNEL_VERSION}" "/boot/firmware/initramfs-${KERNEL_VERSION}.uboot"

    # Remove original initramfs file
    rm -f "${BOOTDIR}/initramfs-${KERNEL_VERSION}"

    # Configure U-Boot to load generated initramfs
    printf "# Set initramfs file\nsetenv initramfs initramfs-${KERNEL_VERSION}.uboot\n\n$(cat ${BOOTDIR}/uboot.mkimage)" > "${BOOTDIR}/uboot.mkimage"
    printf "\nbootz \${kernel_addr_r} \${ramdisk_addr_r} \${fdt_addr_r}" >> "${BOOTDIR}/uboot.mkimage"
  else # ENABLE_INITRAMFS=false
    # Remove initramfs from U-Boot mkfile
    sed -i '/.*initramfs.*/d' "${BOOTDIR}/uboot.mkimage"

    if [ "$BUILD_KERNEL" = false ] ; then
      # Remove dtbfile from U-Boot mkfile
      sed -i '/.*dtbfile.*/d' "${BOOTDIR}/uboot.mkimage"
      printf "\nbootz \${kernel_addr_r}" >> "${BOOTDIR}/uboot.mkimage"
    else
      printf "\nbootz \${kernel_addr_r} - \${fdt_addr_r}" >> "${BOOTDIR}/uboot.mkimage"
    fi
  fi

  # Set mkfile to use dtb file
  sed -i "s/^\(setenv dtbfile \).*/\1${DTB_FILE}/" "${BOOTDIR}/uboot.mkimage"

  # Set mkfile to use kernel image
  sed -i "s/^\(fatload mmc 0:1 \${kernel_addr_r} \).*/\1${KERNEL_IMAGE}/" "${BOOTDIR}/uboot.mkimage"

  # Remove all leading blank lines
  sed -i "/./,\$!d" "${BOOTDIR}/uboot.mkimage"

  # Generate U-Boot bootloader image
  chroot_exec /usr/sbin/mkimage -A "${KERNEL_ARCH}" -O linux -T script -C none -a 0x00000000 -e 0x00000000 -n RPi2 -d /boot/firmware/uboot.mkimage /boot/firmware/boot.scr

  # Remove U-Boot sources
  rm -fr "${R}/tmp/u-boot"
fi
