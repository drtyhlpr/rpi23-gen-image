#
# Setup fstab and initramfs
#

# Load utility functions
. ./functions.sh

# Install and setup fstab
install_readonly files/mount/fstab "${ETC_DIR}/fstab"

if [ "$ENABLE_UBOOTUSB" = true ] ; then
  sed -i "s/mmcblk0p1/sda1/" "${ETC_DIR}/fstab"
  sed -i "s/mmcblk0p2/sda2/" "${ETC_DIR}/fstab"
fi

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
  echo "${CRYPTFS_MAPPING} /dev/mmcblk0p2 none luks,initramfs" >> "${ETC_DIR}/crypttab"

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
	
	if [ "$CRYPTFS_DROPBEAR" = true ]; then
		if [ -n "$CRYPTFS_DROPBEAR_PUBKEY" ] && [ -f "$CRYPTFS_DROPBEAR_PUBKEY" ] ; then
 			install_readonly "${CRYPTFS_DROPBEAR_PUBKEY}" "${ETC_DIR}/dropbear-initramfs/id_rsa.pub"
 			cat /etc/dropbear-initramfs/id_rsa.pub >> /etc/dropbear-initramfs/authorized_keys
 		else
  		  # Create key
 		  chroot_exec /usr/bin/dropbearkey -t rsa -f /etc/dropbear-initramfs/id_rsa.dropbear
			
 		  # Convert dropbear key to openssh key
 		  chroot_exec /usr/lib/dropbear/dropbearconvert dropbear openssh /etc/dropbear-initramfs/id_rsa.dropbear /etc/dropbear-initramfs/id_rsa
			
		  # Get Public Key Part
		  touch /etc/dropbear-initramfs/id_rsa.pub
 		  chroot_exec /usr/bin/dropbearkey -y -f /etc/dropbear-initramfs/id_rsa.dropbear | chroot_exec tee /etc/dropbear-initramfs/id_rsa.pub
 		  
		  # Delete unwanted lines
 		  sed -i '/Public/d' "${ETC_DIR}"/dropbear-initramfs/id_rsa.pub
 		  sed -i '/Fingerprint/d' "${ETC_DIR}"/dropbear-initramfs/id_rsa.pub
 
		  # Trust the new key
 		  touch "${ETC_DIR}"/dropbear-initramfs/authorized_keys
 		  cat "${ETC_DIR}"/dropbear-initramfs/id_rsa.pub | chroot_exec tee -a "${ETC_DIR}"/dropbear-initramfs/authorized_keys

          # Save Keys - convert with putty from rsa/openssh to puttkey
          cp -f "${ETC_DIR}"/dropbear-initramfs/id_rsa "${BASEDIR}"/dropbear_initramfs_key.rsa
			
		  #Get unlock script
 		  install_exec files/initramfs/crypt_unlock.sh "${ETC_DIR}/initramfs-tools/hooks/crypt_unlock.sh"
		fi
	else
	  # Disable SSHD inside initramfs
	  printf "#\n# DROPBEAR: [ y | n ]\n#\n\nDROPBEAR=n\n" >> "${ETC_DIR}/initramfs-tools/initramfs.conf"
	fi

    # Add cryptsetup modules to initramfs
    printf "#\n# CRYPTSETUP: [ y | n ]\n#\n\nCRYPTSETUP=y\n" >> "${ETC_DIR}/initramfs-tools/conf-hook"

    # Dummy mapping required by mkinitramfs
    echo "0 1 crypt $(echo "${CRYPTFS_CIPHER}" | cut -d ':' -f 1) ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff 0 7:0 4096" | chroot_exec dmsetup create "${CRYPTFS_MAPPING}"

    # Generate initramfs with encrypted root partition support
    chroot_exec mkinitramfs -o "/boot/firmware/initramfs-${KERNEL_VERSION}" "${KERNEL_VERSION}"

    # Remove dummy mapping
    chroot_exec cryptsetup close "${CRYPTFS_MAPPING}"
  else
    # Generate initramfs without encrypted root partition support
    chroot_exec mkinitramfs -o "/boot/firmware/initramfs-${KERNEL_VERSION}" "${KERNEL_VERSION}"
  fi
fi
