#
# Build and Setup U-Boot
#

# Load utility functions
. ./functions.sh

# Install gcc/c++ build environment inside the chroot
if [ "$ENABLE_UBOOT" = true ] || [ "$ENABLE_FBTURBO" = true ]; then
  chroot_exec apt-get install -q -y --force-yes --no-install-recommends linux-compiler-gcc-4.9-arm g++ make bc
fi

# Fetch and build U-Boot bootloader
if [ "$ENABLE_UBOOT" = true ] ; then
  # Fetch U-Boot bootloader sources
  git -C $R/tmp clone git://git.denx.de/u-boot.git

  # Build and install U-Boot inside chroot
  chroot_exec make -C /tmp/u-boot/ rpi_2_defconfig all

  # Copy compiled bootloader binary and set config.txt to load it
  cp $R/tmp/u-boot/u-boot.bin $R/boot/firmware/
  printf "\n# boot u-boot kernel\nkernel=u-boot.bin\n" >> $R/boot/firmware/config.txt

  # Install and setup U-Boot command file
  install_readonly files/boot/uboot.mkimage $R/boot/firmware/uboot.mkimage
  printf "# Set the kernel boot command line\nsetenv bootargs \"earlyprintk ${CMDLINE}\"\n\n$(cat $R/boot/firmware/uboot.mkimage)" > $R/boot/firmware/uboot.mkimage

  # Generate U-Boot bootloader image
  chroot_exec /tmp/u-boot/tools/mkimage -A ${KERNEL_ARCH} -O linux -T script -C none -a 0x00000000 -e 0x00000000 -n RPi2 -d /boot/firmware/uboot.mkimage /boot/firmware/boot.scr
fi
