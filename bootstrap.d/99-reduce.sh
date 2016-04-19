#
# Reduce system disk usage
#

# Load utility functions
. ./functions.sh

# Reduce the image size by various operations
if [ "$ENABLE_REDUCE" = true ] ; then
  if [ "$REDUCE_APT" = true ] ; then
    # Install dpkg configuration file
    if [ "$REDUCE_DOC" = true ] || [ "$REDUCE_MAN" = true ] ; then
      install_readonly files/dpkg/01nodoc "${ETCDIR}/dpkg/dpkg.cfg.d/01nodoc"
    fi

    # Install APT configuration files
    install_readonly files/apt/02nocache "${ETCDIR}/apt/apt.conf.d/02nocache"
    install_readonly files/apt/03compress "${ETCDIR}/apt/apt.conf.d/03compress"
    install_readonly files/apt/04norecommends "${ETCDIR}/apt/apt.conf.d/04norecommends"

    # Remove APT cache files
    rm -fr "${R}/var/cache/apt/pkgcache.bin"
    rm -fr "${R}/var/cache/apt/srcpkgcache.bin"
  fi

  # Remove all doc files
  if [ "$REDUCE_DOC" = true ] ; then
    find "${R}/usr/share/doc" -depth -type f ! -name copyright | xargs rm || true
    find "${R}/usr/share/doc" -empty | xargs rmdir || true
  fi

  # Remove all man pages and info files
  if [ "$REDUCE_MAN" = true ] ; then
    rm -rf "${R}/usr/share/man" "${R}/usr/share/groff" "${R}/usr/share/info" "${R}/usr/share/lintian" "${R}/usr/share/linda" "${R}/var/cache/man"
  fi

  # Remove all locale translation files
  if [ "$REDUCE_LOCALE" = true ] ; then
    find "${R}/usr/share/locale" -mindepth 1 -maxdepth 1 ! -name 'en' | xargs rm -r
  fi

  # Remove hwdb PCI device classes (experimental)
  if [ "$REDUCE_HWDB" = true ] ; then
    rm -fr "/lib/udev/hwdb.d/20-pci-*"
  fi

  # Replace bash shell by dash shell (experimental)
  if [ "$REDUCE_BASH" = true ] ; then
    echo "Yes, do as I say!" | chroot_exec apt-get purge -qq -y --force-yes bash
    chroot_exec update-alternatives --install /bin/bash bash /bin/dash 100
  fi

  # Remove sound utils and libraries
  if [ "$ENABLE_SOUND" = false ] ; then
    chroot_exec apt-get -qq -y --force-yes purge alsa-utils libsamplerate0 libasound2 libasound2-data
  fi

  # Re-install tools for managing kernel moduless
  chroot_exec apt-get -qq -y --force-yes install module-init-tools

  # Remove GPU kernels
  if [ "$ENABLE_MINGPU" = true ] ; then
    rm -f "${BOOTDIR}/start.elf"
    rm -f "${BOOTDIR}/fixup.dat"
    rm -f "${BOOTDIR}/start_x.elf"
    rm -f "${BOOTDIR}/fixup_x.dat"
  fi

  # Remove kernel and initrd from /boot (already in /boot/firmware)
  if [ "$BUILD_KERNEL" = false ] ; then
    rm -f "${R}/boot/vmlinuz-*"
    rm -f "${R}/boot/initrd.img-*"
  fi

  # Clean APT list of repositories
  rm -fr "${R}/var/lib/apt/lists/*"
  chroot_exec apt-get -qq -y update
fi
