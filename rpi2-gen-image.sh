#!/bin/sh

########################################################################
# rpi2-gen-image.sh					   ver2a 12/2015
#
# Advanced debian "jessie" bootstrap script for RPi2
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# some parts based on rpi2-build-image:
# Copyright (C) 2015 Ryan Finnie <ryan@finnie.org>
# Copyright (C) 2015 Luca Falavigna <dktrkranz@debian.org>
########################################################################

# Check if ./functions.sh script exists
if [ ! -r "./functions.sh" ] ; then
  echo "error: './functions.sh' required script not found. please reinstall the latest script version!"
  exit 1
fi

# Load utility functions
. ./functions.sh

# Introduce settings
set -e
echo -n -e "\n#\n# RPi2 Bootstrap Settings\n#\n"
set -x

# Debian release
RELEASE=${RELEASE:=jessie}
KERNEL_ARCH=${KERNEL_ARCH:=arm}
RELEASE_ARCH=${RELEASE_ARCH:=armhf}
CROSS_COMPILE=${CROSS_COMPILE:=arm-linux-gnueabihf-}
COLLABORA_KERNEL=${COLLABORA_KERNEL:=3.18.0-trunk-rpi2}
KERNEL_DEFCONFIG=${KERNEL_DEFCONFIG:=bcm2709_defconfig}
QEMU_BINARY=${QEMU_BINARY:=/usr/bin/qemu-arm-static}

# Build settings
BASEDIR=$(pwd)/images/${RELEASE}
BUILDDIR=${BASEDIR}/build

# General settings
HOSTNAME=${HOSTNAME:=rpi2-${RELEASE}}
PASSWORD=${PASSWORD:=raspberry}
DEFLOCAL=${DEFLOCAL:="en_US.UTF-8"}
TIMEZONE=${TIMEZONE:="Europe/Berlin"}
EXPANDROOT=${EXPANDROOT:=true}

# Keyboard settings
XKB_MODEL=${XKB_MODEL:=""}
XKB_LAYOUT=${XKB_LAYOUT:=""}
XKB_VARIANT=${XKB_VARIANT:=""}
XKB_OPTIONS=${XKB_OPTIONS:=""}

# Network settings (DHCP)
ENABLE_DHCP=${ENABLE_DHCP:=true}

# Network settings (static)
# only used on ENABLE_DHCP=false
NET_ADDRESS=${NET_ADDRESS:=""}
NET_GATEWAY=${NET_GATEWAY:=""}
NET_DNS_1=${NET_DNS_1:=""}
NET_DNS_2=${NET_DNS_2:=""}
NET_DNS_DOMAINS=${NET_DNS_DOMAINS:=""}
NET_NTP_1=${NET_NTP_1:=""}
NET_NTP_2=${NET_NTP_2:=""}

# APT settings
APT_PROXY=${APT_PROXY:=""}
APT_SERVER=${APT_SERVER:="ftp.debian.org"}

# Feature settings
ENABLE_CONSOLE=${ENABLE_CONSOLE:=true}
ENABLE_IPV6=${ENABLE_IPV6:=true}
ENABLE_SSHD=${ENABLE_SSHD:=true}
ENABLE_SOUND=${ENABLE_SOUND:=true}
ENABLE_DBUS=${ENABLE_DBUS:=true}
ENABLE_HWRANDOM=${ENABLE_HWRANDOM:=true}
ENABLE_MINGPU=${ENABLE_MINGPU:=false}
ENABLE_XORG=${ENABLE_XORG:=false}
ENABLE_WM=${ENABLE_WM:=""}
ENABLE_RSYSLOG=${ENABLE_RSYSLOG:=true}
ENABLE_USER=${ENABLE_USER:=true}
ENABLE_ROOT=${ENABLE_ROOT:=false}
ENABLE_ROOT_SSH=${ENABLE_ROOT_SSH:=false}

# Advanced settings
ENABLE_MINBASE=${ENABLE_MINBASE:=false}
ENABLE_REDUCE=${ENABLE_REDUCE:=flase}
ENABLE_UBOOT=${ENABLE_UBOOT:=false}
ENABLE_FBTURBO=${ENABLE_FBTURBO:=false}
ENABLE_HARDNET=${ENABLE_HARDNET:=false}
ENABLE_IPTABLES=${ENABLE_IPTABLES:=false}
ENABLE_SPLITFS=${ENABLE_SPLITFS:=false}

# Kernel compilation settings
BUILD_KERNEL=${BUILD_KERNEL:=false}
KERNEL_THREADS=${KERNEL_THREADS:=1}
KERNEL_HEADERS=${KERNEL_HEADERS:=true}
KERNEL_MENUCONFIG=${KERNEL_MENUCONFIG:=false}
KERNEL_REMOVESRC=${KERNEL_REMOVESRC:=true}

# Kernel compilation from source directory settings
KERNELSRC_DIR=${KERNELSRC_DIR:=""}
KERNELSRC_CLEAN=${KERNELSRC_CLEAN:=false}
KERNELSRC_CONFIG=${KERNELSRC_CONFIG:=true}
KERNELSRC_PREBUILT=${KERNELSRC_PREBUILT:=false}

# Image chroot path
R=${BUILDDIR}/chroot
CHROOT_SCRIPTS=${CHROOT_SCRIPTS:=""}

# Packages required for bootstrapping
REQUIRED_PACKAGES="debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git-core"

# Missing packages that need to be installed
MISSING_PACKAGES=""

# Packages required in the chroot build environment
APT_INCLUDES=${APT_INCLUDES:=""}
APT_INCLUDES="${APT_INCLUDES},apt-transport-https,apt-utils,ca-certificates,debian-archive-keyring,dialog,sudo"

set +x

# Are we running as root?
if [ "$(id -u)" -ne "0" ] ; then
  echo "error: this script must be executed with root privileges!"
  exit 1
fi

# Check if ./bootstrap.d directory exists
if [ ! -d "./bootstrap.d/" ] ; then
  echo "error: './bootstrap.d' required directory not found. please reinstall the latest script version!"
  exit 1
fi

# Check if ./files directory exists
if [ ! -d "./files/" ] ; then
  echo "error: './files' required directory not found. please reinstall the latest script version!"
  exit 1
fi

# Check if specified KERNELSRC_DIR directory exists
if [ -n "$KERNELSRC_DIR" ] && [ ! -d "$KERNELSRC_DIR" ] ; then
  echo "error: ${KERNELSRC_DIR} (KERNELSRC_DIR) specified directory not found!"
  exit 1
fi

# Check if specified CHROOT_SCRIPTS directory exists
if [ -n "$CHROOT_SCRIPTS" ] && [ ! -d "$CHROOT_SCRIPTS" ] ; then
   echo "error: ${CHROOT_SCRIPTS} (CHROOT_SCRIPTS) specified directory not found!"
   exit 1
fi

# Add packages required for kernel cross compilation
if [ "$BUILD_KERNEL" = true ] ; then
  REQUIRED_PACKAGES="${REQUIRED_PACKAGES} crossbuild-essential-armhf"

  if [ "$KERNEL_MENUCONFIG" = true ] ; then
    REQUIRED_PACKAGES="${REQUIRED_PACKAGES} ncurses-dev"
  fi
fi

# Check if all required packages are installed
for package in $REQUIRED_PACKAGES ; do
  if [ "`dpkg-query -W -f='${Status}' $package`" != "install ok installed" ] ; then
    MISSING_PACKAGES="${MISSING_PACKAGES} $package"
  fi
done

# Ask if missing packages should get installed right now
if [ -n "$MISSING_PACKAGES" ] ; then
  echo "the following packages needed by this script are not installed:"
  echo "$MISSING_PACKAGES"

  echo -n "\ndo you want to install the missing packages right now? [y/n] "
  read confirm
  if [ "$confirm" != "y" ] ; then
    exit 1
  fi
fi

# Make sure all required packages are installed
apt-get -qq -y install ${REQUIRED_PACKAGES}

# Don't clobber an old build
if [ -e "$BUILDDIR" ] ; then
  echo "error: directory ${BUILDDIR} already exists, not proceeding"
  exit 1
fi

# Setup chroot directory
mkdir -p "$R"

# Check if build directory has enough of free disk space >512MB
if [ "$(df --output=avail ${BUILDDIR} | sed "1d")" -le "524288" ] ; then
  echo "error: ${BUILDDIR} not enough space left on this partition to generate the output image!"
  exit 1
fi

# Warn if build directory has low free disk space <1024MB
if [ "$(df --output=avail ${BUILDDIR} | sed "1d")" -le "1048576" ] ; then
  echo `df -h --output=avail ${BUILDDIR} | sed "1 s|.*Avail|warning: $partition is low on free space:|"`
fi

set -x

# Call "cleanup" function on various signals and errors
trap cleanup 0 1 2 3 6

# Add required packages for the minbase installation
if [ "$ENABLE_MINBASE" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},vim-tiny,netbase,net-tools"
else
  APT_INCLUDES="${APT_INCLUDES},locales,keyboard-configuration,console-setup"
fi

# Add parted package, required to get partprobe utility
if [ "$EXPANDROOT" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},parted"
fi

# Add dbus package, recommended if using systemd
if [ "$ENABLE_DBUS" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},dbus"
fi

# Add iptables IPv4/IPv6 package
if [ "$ENABLE_IPTABLES" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},iptables"
fi

# Add openssh server package
if [ "$ENABLE_SSHD" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},openssh-server"
fi

# Add alsa-utils package
if [ "$ENABLE_SOUND" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},alsa-utils"
fi

# Add rng-tools package
if [ "$ENABLE_HWRANDOM" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},rng-tools"
fi

# Add fbturbo video driver
if [ "$ENABLE_FBTURBO" = true ] ; then
  # Enable xorg package dependencies
  ENABLE_XORG=true
fi

# Add user defined window manager package
if [ -n "$ENABLE_WM" ] ; then
  APT_INCLUDES="${APT_INCLUDES},${ENABLE_WM}"

  # Enable xorg package dependencies
  ENABLE_XORG=true
fi

# Add xorg package
if [ "$ENABLE_XORG" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},xorg"
fi

# Set KERNELSRC_CONFIG=true
if [ "$BUILD_KERNEL" = true ] && [ -z "$KERNELSRC_DIR" ] ; then
  KERNELSRC_CONFIG=true
fi

## MAIN bootstrap
for SCRIPT in bootstrap.d/*.sh; do
  # Execute bootstrap scripts (lexicographical order)
  head -n 3 "$SCRIPT"
  . "$SCRIPT"
done

## Custom bootstrap scripts
if [ -d "custom.d" ] ; then
  # Execute custom bootstrap scripts (lexicographical order)
  for SCRIPT in custom.d/*.sh; do
    . "$SCRIPT"
  done
fi

# Invoke custom scripts
if [ -n "$CHROOT_SCRIPTS" ] && [ -d "$CHROOT_SCRIPTS" ] ; then
  cp -r "${CHROOT_SCRIPTS}" "${R}/chroot_scripts"
  # Execute scripts inside the chroot (lexicographical order)
  chroot_exec /bin/bash -x <<'EOF'
for SCRIPT in /chroot_scripts/* ; do
  if [ -f $SCRIPT -a -x $SCRIPT ] ; then
    $SCRIPT
  fi
done
EOF
  rm -rf "$R/chroot_scripts"
fi

# Remove apt-utils
chroot_exec apt-get purge -qq -y --force-yes apt-utils

# Reduce the image size by removing and compressing
if [ "$ENABLE_REDUCE" = true ] ; then
  # Install dpkg configuration fragment file
  install_readonly files/dpkg/01nodoc "$R/etc/dpkg/dpkg.cfg.d/01nodoc"

  # Install APT configuration fragment files
  install_readonly files/apt/02nocache "$R/etc/apt/apt.conf.d/02nocache"
  install_readonly files/apt/03compress "$R/etc/apt/apt.conf.d/03compress"
  install_readonly files/apt/04norecommends "$R/etc/apt/apt.conf.d/04norecommends"

  # Remove APT cache files
  rm -fr "$R/var/cache/apt/pkgcache.bin"
  rm -fr "$R/var/cache/apt/srcpkgcache.bin"

  # Remove all doc and man files
  find "$R/usr/share/doc" -depth -type f ! -name copyright | xargs rm || true
  find "$R/usr/share/doc" -empty | xargs rmdir || true
  rm -rf "$R/usr/share/man" "$R/usr/share/groff" "$R/usr/share/info" "$R/usr/share/lintian" "$R/usr/share/linda" "$R/var/cache/man"

  # Remove all translation files
  find "$R/usr/share/locale" -mindepth 1 -maxdepth 1 ! -name 'en' | xargs rm -r

  # Clean APT list of repositories
  rm -fr "$R/var/lib/apt/lists/*"
  chroot_exec apt-get -qq -y update

  # Remove GPU kernels
  if [ "$ENABLE_MINGPU" = true ] ; then
    rm -f "$R/boot/firmware/start.elf"
    rm -f "$R/boot/firmware/fixup.dat"
    rm -f "$R/boot/firmware/start_x.elf"
    rm -f "$R/boot/firmware/fixup_x.dat"
  fi
fi

# APT Cleanup
chroot_exec apt-get -y clean
chroot_exec apt-get -y autoclean
chroot_exec apt-get -y autoremove

# Unmount mounted filesystems
umount -l "$R/proc"
umount -l "$R/sys"

# Clean up directories
rm -rf "$R/run"
rm -rf "$R/tmp/*"

# Clean up files
rm -f "$R/etc/apt/sources.list.save"
rm -f "$R/etc/resolvconf/resolv.conf.d/original"
rm -f "$R/etc/*-"
rm -f "$R/root/.bash_history"
rm -f "$R/var/lib/urandom/random-seed"
rm -f "$R/var/lib/dbus/machine-id"
rm -f "$R/etc/machine-id"
rm -f "$R/etc/apt/apt.conf.d/10proxy"
rm -f "$R/etc/resolv.conf"
rm -f "${R}${QEMU_BINARY}"

# Calculate size of the chroot directory in KB
CHROOT_SIZE=$(expr `du -s "$R" | awk '{ print $1 }'`)

# Calculate the amount of needed 512 Byte sectors
TABLE_SECTORS=$(expr 1 \* 1024 \* 1024 \/ 512)
FRMW_SECTORS=$(expr 64 \* 1024 \* 1024 \/ 512)
ROOT_OFFSET=$(expr ${TABLE_SECTORS} + ${FRMW_SECTORS})

# The root partition is EXT4
# This means more space than the actual used space of the chroot is used.
# As overhead for journaling and reserved blocks 20% are added.
ROOT_SECTORS=$(expr $(expr ${CHROOT_SIZE} + ${CHROOT_SIZE} \/ 100 \* 20) \* 1024 \/ 512)

# Calculate required image size in 512 Byte sectors
IMAGE_SECTORS=$(expr ${TABLE_SECTORS} + ${FRMW_SECTORS} + ${ROOT_SECTORS})

# Prepare date string for image file name
DATE="$(date +%Y-%m-%d)"

# Prepare image file
if [ "$ENABLE_SPLITFS" = true ] ; then
  dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}-frmw.img" bs=512 count=${TABLE_SECTORS}
  dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}-frmw.img" bs=512 count=0 seek=${FRMW_SECTORS}
  dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}-root.img" bs=512 count=${TABLE_SECTORS}
  dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}-root.img" bs=512 count=0 seek=${ROOT_SECTORS}
  # Write partition tables
  sfdisk -q -L -f "$BASEDIR/${DATE}-debian-${RELEASE}-frmw.img" <<EOM
unit: sectors

1 : start=   ${TABLE_SECTORS}, size=   ${FRMW_SECTORS}, Id= c, bootable
2 : start=                  0, size=                 0, Id= 0
3 : start=                  0, size=                 0, Id= 0
4 : start=                  0, size=                 0, Id= 0
EOM
  sfdisk -q -L -f "$BASEDIR/${DATE}-debian-${RELEASE}-root.img" <<EOM
unit: sectors

1 : start=   ${TABLE_SECTORS}, size=   ${ROOT_SECTORS}, Id=83
2 : start=                  0, size=                 0, Id= 0
3 : start=                  0, size=                 0, Id= 0
4 : start=                  0, size=                 0, Id= 0
EOM
  # Setup temporary loop devices
  FRMW_LOOP="$(losetup -o 1M --sizelimit 64M -f --show $BASEDIR/${DATE}-debian-${RELEASE}-frmw.img)"
  ROOT_LOOP="$(losetup -o 1M -f --show $BASEDIR/${DATE}-debian-${RELEASE}-root.img)"
else
  dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}.img" bs=512 count=${TABLE_SECTORS}
  dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}.img" bs=512 count=0 seek=${IMAGE_SECTORS}
  # Write partition table
  sfdisk -q -f "$BASEDIR/${DATE}-debian-${RELEASE}.img" <<EOM
unit: sectors

1 : start=   ${TABLE_SECTORS}, size=   ${FRMW_SECTORS}, Id= c, bootable
2 : start=     ${ROOT_OFFSET}, size=   ${ROOT_SECTORS}, Id=83
3 : start=                  0, size=                 0, Id= 0
4 : start=                  0, size=                 0, Id= 0
EOM
  # Setup temporary loop devices
  FRMW_LOOP="$(losetup -o 1M --sizelimit 64M -f --show $BASEDIR/${DATE}-debian-${RELEASE}.img)"
  ROOT_LOOP="$(losetup -o 65M -f --show $BASEDIR/${DATE}-debian-${RELEASE}.img)"
fi

# Build filesystems
mkfs.vfat "$FRMW_LOOP"
mkfs.ext4 "$ROOT_LOOP"

# Mount the temporary loop devices
mkdir -p "$BUILDDIR/mount"
mount "$ROOT_LOOP" "$BUILDDIR/mount"

mkdir -p "$BUILDDIR/mount/boot/firmware"
mount "$FRMW_LOOP" "$BUILDDIR/mount/boot/firmware"

# Copy all files from the chroot to the loop device mount point directory
rsync -a "$R/" "$BUILDDIR/mount/"

# Unmount all temporary loop devices and mount points
cleanup

# Create block map file(s) of image(s)
if [ "$ENABLE_SPLITFS" = true ] ; then
  # Create block map files for "bmaptool"
  bmaptool create -o "$BASEDIR/${DATE}-debian-${RELEASE}-frmw.bmap" "$BASEDIR/${DATE}-debian-${RELEASE}-frmw.img"
  bmaptool create -o "$BASEDIR/${DATE}-debian-${RELEASE}-root.bmap" "$BASEDIR/${DATE}-debian-${RELEASE}-root.img"

  # Image was successfully created
  echo "$BASEDIR/${DATE}-debian-${RELEASE}-frmw.img ($(expr \( ${TABLE_SECTORS} + ${FRMW_SECTORS} \) \* 512 \/ 1024 \/ 1024)M)" ": successfully created"
  echo "$BASEDIR/${DATE}-debian-${RELEASE}-root.img ($(expr \( ${TABLE_SECTORS} + ${ROOT_SECTORS} \) \* 512 \/ 1024 \/ 1024)M)" ": successfully created"
else
  # Create block map file for "bmaptool"
  bmaptool create -o "$BASEDIR/${DATE}-debian-${RELEASE}.bmap" "$BASEDIR/${DATE}-debian-${RELEASE}.img"

  # Image was successfully created
  echo "$BASEDIR/${DATE}-debian-${RELEASE}.img ($(expr \( ${TABLE_SECTORS} + ${FRMW_SECTORS} + ${ROOT_SECTORS} \) \* 512 \/ 1024 \/ 1024)M)" ": successfully created"
fi
