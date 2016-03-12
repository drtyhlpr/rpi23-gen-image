# This file contains utility functions used by rpi2-gen-image.sh

cleanup (){
  set +x
  set +e

  # Identify and kill all processes still using files
  echo "killing processes using mount point ..."
  fuser -k $R
  sleep 3
  fuser -9 -k -v $R

  # Clean up all temporary mount points
  echo "removing temporary mount points ..."
  umount -l $R/proc 2> /dev/null
  umount -l $R/sys 2> /dev/null
  umount -l $R/dev/pts 2> /dev/null
  umount "$BUILDDIR/mount/boot/firmware" 2> /dev/null
  umount "$BUILDDIR/mount" 2> /dev/null
  losetup -d "$EXT4_LOOP" 2> /dev/null
  losetup -d "$VFAT_LOOP" 2> /dev/null
  trap - 0 1 2 3 6
}

chroot_exec() {
  # Exec command in chroot
  LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot $R $*
}

install_readonly() {
  # Install file with user read-only permissions
  install -o root -g root -m 644 $*
}

install_exec() {
  # Install file with root exec permissions
  install -o root -g root -m 744 $*
}
