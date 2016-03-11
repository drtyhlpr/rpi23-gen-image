#
# Setup Uboot
#

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

  # Set U-Boot command file
  cat <<EOM >$R/boot/firmware/uboot.mkimage
# Tell Linux that it is booting on a Raspberry Pi2
setenv machid 0x00000c42

# Set the kernel boot command line
setenv bootargs "earlyprintk ${CMDLINE}"

# Save these changes to u-boot's environment
saveenv

# Load the existing Linux kernel into RAM
fatload mmc 0:1 \${kernel_addr_r} kernel7.img

# Boot the kernel we have just loaded
bootz \${kernel_addr_r}
EOM

  # Generate U-Boot image from command file
  chroot_exec mkimage -A arm -O linux -T script -C none -a 0x00000000 -e 0x00000000 -n "RPi2 Boot Script" -d /boot/firmware/uboot.mkimage /boot/firmware/boot.scr
fi
