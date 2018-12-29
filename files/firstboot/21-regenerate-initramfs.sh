logger -t "rc.firstboot" "Regenerating initramfs to remove encrypted root partition auto-expand"

KERNEL_VERSION=$(uname -r)
KERNEL_ARCH=$(uname -m)
INITRAMFS="/boot/firmware/initramfs-${KERNEL_VERSION}"
INITRAMFS_UBOOT="${INITRAMFS}.uboot"

# Extract kernel arch
case "${KERNEL_ARCH}" in
  arm*) KERNEL_ARCH=arm ;;
  aarch64) KERNEL_ARCH=arm64 ;;
esac

# Regenerate initramfs
if [ -r "${INITRAMFS}" ] ; then
  rm -f /etc/initramfs-tools/scripts/init-premount/expand_encrypted_rootfs
  rm -f /etc/initramfs-tools/scripts/local-premount/expand-premount
  rm -f /etc/initramfs-tools/hooks/expand-tools
  rm -f "${INITRAMFS}"
  mkinitramfs -o "${INITRAMFS}" "${KERNEL_VERSION}"
fi

# Convert generated initramfs for U-Boot using mkimage
if [ -r "${INITRAMFS_UBOOT}" ] ; then
  rm -f /etc/initramfs-tools/scripts/init-premount/expand_encrypted_rootfs
  rm -f /etc/initramfs-tools/scripts/local-premount/expand-premount
  rm -f /etc/initramfs-tools/hooks/expand-tools
  rm -f "${INITRAMFS_UBOOT}"
  mkinitramfs -o "${INITRAMFS}" "${KERNEL_VERSION}"
  mkimage -A "${KERNEL_ARCH}" -T ramdisk -C none -n "initramfs-${KERNEL_VERSION}" -d "${INITRAMFS}" "${INITRAMFS_UBOOT}"
  rm -f "${INITRAMFS}"
fi
