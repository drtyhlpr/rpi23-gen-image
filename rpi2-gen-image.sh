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

# Are we running as root?
if [ "$(id -u)" -ne "0" ] ; then
  echo "error: this script must be executed with root privileges!"
  exit 1
fi

# Check if ./functions.sh script exists
if [ ! -r "./functions.sh" ] ; then
  echo "error: './functions.sh' required script not found!"
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
KERNEL_IMAGE=${KERNEL_IMAGE:=kernel7.img}
DTB_FILE=${DTB_FILE:=bcm2709-rpi-2-b.dtb}
UBOOT_CONFIG=${UBOOT_CONFIG:=rpi_2_defconfig}
QEMU_BINARY=${QEMU_BINARY:=/usr/bin/qemu-arm-static}

# Build directories
BASEDIR="$(pwd)/images/${RELEASE}"
BUILDDIR="${BASEDIR}/build"

# Chroot directories
R="${BUILDDIR}/chroot"
ETCDIR="${R}/etc"
BOOTDIR="${R}/boot/firmware"
KERNELDIR="${R}/usr/src/linux"

# Firmware directory: Blank if download from github
FIRMWAREDIR=${FIRMWAREDIR:=""}

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
USER_NAME=${USER_NAME:="pi"}
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
ENABLE_INITRAMFS=${ENABLE_INITRAMFS:=false}

# Kernel compilation settings
BUILD_KERNEL=${BUILD_KERNEL:=false}
KERNEL_REDUCE=${KERNEL_REDUCE:=false}
KERNEL_THREADS=${KERNEL_THREADS:=1}
KERNEL_HEADERS=${KERNEL_HEADERS:=true}
KERNEL_MENUCONFIG=${KERNEL_MENUCONFIG:=false}
KERNEL_REMOVESRC=${KERNEL_REMOVESRC:=true}

# Kernel compilation from source directory settings
KERNELSRC_DIR=${KERNELSRC_DIR:=""}
KERNELSRC_CLEAN=${KERNELSRC_CLEAN:=false}
KERNELSRC_CONFIG=${KERNELSRC_CONFIG:=true}
KERNELSRC_PREBUILT=${KERNELSRC_PREBUILT:=false}

# Reduce disk usage settings
REDUCE_APT=${REDUCE_APT:=true}
REDUCE_DOC=${REDUCE_DOC:=true}
REDUCE_MAN=${REDUCE_MAN:=true}
REDUCE_VIM=${REDUCE_VIM:=false}
REDUCE_BASH=${REDUCE_BASH:=false}
REDUCE_HWDB=${REDUCE_HWDB:=true}
REDUCE_SSHD=${REDUCE_SSHD:=true}
REDUCE_LOCALE=${REDUCE_LOCALE:=true}

# Encrypted filesystem settings
ENABLE_CRYPTFS=${ENABLE_CRYPTFS:=false}
CRYPTFS_PASSWORD=${CRYPTFS_PASSWORD:=""}
CRYPTFS_MAPPING=${CRYPTFS_MAPPING:="secure"}
CRYPTFS_CIPHER=${CRYPTFS_CIPHER:="aes-xts-plain64:sha512"}
CRYPTFS_XTSKEYSIZE=${CRYPTFS_XTSKEYSIZE:=512}

# Stop the Crypto Wars
DISABLE_FBI=${DISABLE_FBI:=false}

# Chroot scripts directory
CHROOT_SCRIPTS=${CHROOT_SCRIPTS:=""}

# Packages required in the chroot build environment
APT_INCLUDES=${APT_INCLUDES:=""}
APT_INCLUDES="${APT_INCLUDES},apt-transport-https,apt-utils,ca-certificates,debian-archive-keyring,dialog,sudo"

# Packages required for bootstrapping
REQUIRED_PACKAGES="debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git"
MISSING_PACKAGES=""

set +x

# Add packages required for kernel cross compilation
if [ "$BUILD_KERNEL" = true ] ; then
  REQUIRED_PACKAGES="${REQUIRED_PACKAGES} crossbuild-essential-armhf"
fi

# Add libncurses5 to enable kernel menuconfig
if [ "$KERNEL_MENUCONFIG" = true ] ; then
  REQUIRED_PACKAGES="${REQUIRED_PACKAGES} libncurses5-dev"
fi

# Stop the Crypto Wars
if [ "$DISABLE_FBI" = true ] ; then
  ENABLE_CRYPTFS=true
fi

# Add cryptsetup package to enable filesystem encryption
if [ "$ENABLE_CRYPTFS" = true ]  && [ "$BUILD_KERNEL" = true ] ; then
  REQUIRED_PACKAGES="${REQUIRED_PACKAGES} cryptsetup"
  APT_INCLUDES="${APT_INCLUDES},cryptsetup"

  if [ -z "$CRYPTFS_PASSWORD" ] ; then
    echo "error: no password defined (CRYPTFS_PASSWORD)!"
    exit 1
  fi
  ENABLE_INITRAMFS=true
fi

# Add initramfs generation tools
if [ "$ENABLE_INITRAMFS" = true ] && [ "$BUILD_KERNEL" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},initramfs-tools"
fi

# Check if all required packages are installed on the build system
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
  [ "$confirm" != "y" ] && exit 1
fi

# Make sure all required packages are installed
apt-get -qq -y install ${REQUIRED_PACKAGES}

# Check if ./bootstrap.d directory exists
if [ ! -d "./bootstrap.d/" ] ; then
  echo "error: './bootstrap.d' required directory not found!"
  exit 1
fi

# Check if ./files directory exists
if [ ! -d "./files/" ] ; then
  echo "error: './files' required directory not found!"
  exit 1
fi

# Check if specified KERNELSRC_DIR directory exists
if [ -n "$KERNELSRC_DIR" ] && [ ! -d "$KERNELSRC_DIR" ] ; then
  echo "error: '${KERNELSRC_DIR}' specified directory not found (KERNELSRC_DIR)!"
  exit 1
fi

# Check if specified CHROOT_SCRIPTS directory exists
if [ -n "$CHROOT_SCRIPTS" ] && [ ! -d "$CHROOT_SCRIPTS" ] ; then
   echo "error: ${CHROOT_SCRIPTS} specified directory not found (CHROOT_SCRIPTS)!"
   exit 1
fi

# Check if specified device mapping already exists (will be used by cryptsetup)
if [ -r "/dev/mapping/${CRYPTFS_MAPPING}" ] ; then
  echo "error: mapping /dev/mapping/${CRYPTFS_MAPPING} already exists, not proceeding"
  exit 1
fi

# Don't clobber an old build
if [ -e "$BUILDDIR" ] ; then
  echo "error: directory ${BUILDDIR} already exists, not proceeding"
  exit 1
fi

# Setup chroot directory
mkdir -p "${R}"

# Check if build directory has enough of free disk space >512MB
if [ "$(df --output=avail ${BUILDDIR} | sed "1d")" -le "524288" ] ; then
  echo "error: ${BUILDDIR} not enough space left to generate the output image!"
  exit 1
fi

set -x

# Call "cleanup" function on various signals and errors
trap cleanup 0 1 2 3 6

# Add required packages for the minbase installation
if [ "$ENABLE_MINBASE" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},vim-tiny,netbase,net-tools,ifupdown"
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

# Replace selected packages with smaller clones
if [ "$ENABLE_REDUCE" = true ] ; then
  # Add levee package instead of vim-tiny
  if [ "$REDUCE_VIM" = true ] ; then
    APT_INCLUDES="$(echo ${APT_INCLUDES} | sed "s/vim-tiny/levee/")"
  fi

  # Add dropbear package instead of openssh-server
  if [ "$REDUCE_SSHD" = true ] ; then
    APT_INCLUDES="$(echo ${APT_INCLUDES} | sed "s/openssh-server/dropbear/")"
  fi
fi

# Configure kernel sources if no KERNELSRC_DIR
if [ "$BUILD_KERNEL" = true ] && [ -z "$KERNELSRC_DIR" ] ; then
  KERNELSRC_CONFIG=true
fi

# Configure reduced kernel
if [ "$KERNEL_REDUCE" = true ] ; then
  KERNELSRC_CONFIG=false
fi

# Execute bootstrap scripts
for SCRIPT in bootstrap.d/*.sh; do
  head -n 3 "$SCRIPT"
  . "$SCRIPT"
done

## Execute custom bootstrap scripts
if [ -d "custom.d" ] ; then
  for SCRIPT in custom.d/*.sh; do
    . "$SCRIPT"
  done
fi

# Execute custom scripts inside the chroot
if [ -n "$CHROOT_SCRIPTS" ] && [ -d "$CHROOT_SCRIPTS" ] ; then
  cp -r "${CHROOT_SCRIPTS}" "${R}/chroot_scripts"
  chroot_exec /bin/bash -x <<'EOF'
for SCRIPT in /chroot_scripts/* ; do
  if [ -f $SCRIPT -a -x $SCRIPT ] ; then
    $SCRIPT
  fi
done
EOF
  rm -rf "${R}/chroot_scripts"
fi

# Remove apt-utils
chroot_exec apt-get purge -qq -y --force-yes apt-utils

# Generate required machine-id
MACHINE_ID=$(dbus-uuidgen)
echo -n "${MACHINE_ID}" > "${R}/var/lib/dbus/machine-id"
echo -n "${MACHINE_ID}" > "${ETCDIR}/machine-id"

# APT Cleanup
chroot_exec apt-get -y clean
chroot_exec apt-get -y autoclean
chroot_exec apt-get -y autoremove

# Unmount mounted filesystems
umount -l "${R}/proc"
umount -l "${R}/sys"

# Clean up directories
rm -rf "${R}/run/*"
rm -rf "${R}/tmp/*"

# Clean up files
rm -f "${ETCDIR}/ssh/ssh_host_*"
rm -f "${ETCDIR}/dropbear/dropbear_*"
rm -f "${ETCDIR}/apt/sources.list.save"
rm -f "${ETCDIR}/resolvconf/resolv.conf.d/original"
rm -f "${ETCDIR}/*-"
rm -f "${ETCDIR}/apt/apt.conf.d/10proxy"
rm -f "${ETCDIR}/resolv.conf"
rm -f "${R}/root/.bash_history"
rm -f "${R}/var/lib/urandom/random-seed"
rm -f "${R}/initrd.img"
rm -f "${R}/vmlinuz"
rm -f "${R}${QEMU_BINARY}"

# Calculate size of the chroot directory in KB
CHROOT_SIZE=$(expr `du -s "${R}" | awk '{ print $1 }'`)

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

  # Write firmware/boot partition tables
  sfdisk -q -L -uS -f "$BASEDIR/${DATE}-debian-${RELEASE}-frmw.img" 2> /dev/null <<EOM
${TABLE_SECTORS},${FRMW_SECTORS},c,*
EOM

  # Write root partition table
  sfdisk -q -L -uS -f "$BASEDIR/${DATE}-debian-${RELEASE}-root.img" 2> /dev/null <<EOM
${TABLE_SECTORS},${ROOT_SECTORS},83
EOM

  # Setup temporary loop devices
  FRMW_LOOP="$(losetup -o 1M --sizelimit 64M -f --show $BASEDIR/${DATE}-debian-${RELEASE}-frmw.img)"
  ROOT_LOOP="$(losetup -o 1M -f --show $BASEDIR/${DATE}-debian-${RELEASE}-root.img)"
else # ENABLE_SPLITFS=false
  dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}.img" bs=512 count=${TABLE_SECTORS}
  dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}.img" bs=512 count=0 seek=${IMAGE_SECTORS}

  # Write partition table
  sfdisk -q -L -uS -f "$BASEDIR/${DATE}-debian-${RELEASE}.img" 2> /dev/null <<EOM
${TABLE_SECTORS},${FRMW_SECTORS},c,*
${ROOT_OFFSET},${ROOT_SECTORS},83
EOM

  # Setup temporary loop devices
  FRMW_LOOP="$(losetup -o 1M --sizelimit 64M -f --show $BASEDIR/${DATE}-debian-${RELEASE}.img)"
  ROOT_LOOP="$(losetup -o 65M -f --show $BASEDIR/${DATE}-debian-${RELEASE}.img)"
fi

if [ "$ENABLE_CRYPTFS" = true ] ; then
  # Create dummy ext4 fs
  mkfs.ext4 "$ROOT_LOOP"

  # Setup password keyfile
  echo -n ${CRYPTFS_PASSWORD} > .password
  chmod 600 .password

  # Initialize encrypted partition
  echo "YES" | cryptsetup luksFormat "${ROOT_LOOP}" -c "${CRYPTFS_CIPHER}" -s "${CRYPTFS_XTSKEYSIZE}" .password

  # Open encrypted partition and setup mapping
  cryptsetup luksOpen "${ROOT_LOOP}" -d .password "${CRYPTFS_MAPPING}"

  # Secure delete password keyfile
  shred -zu .password

  # Update temporary loop device
  ROOT_LOOP="/dev/mapper/${CRYPTFS_MAPPING}"

  # Wipe encrypted partition (encryption cipher is used for randomness)
  dd if=/dev/zero of="${ROOT_LOOP}" bs=512 count=$(blockdev --getsz "${ROOT_LOOP}")
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
rsync -a "${R}/" "$BUILDDIR/mount/"

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
