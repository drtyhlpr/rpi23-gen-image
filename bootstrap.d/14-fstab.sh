#
# Setup fstab and initramfs
#

# Load utility functions
. ./functions.sh

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
if [ "$BUILD_KERNEL" = true ] && [ "$ENABLE_INITRAMFS" = true ] ; then
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
