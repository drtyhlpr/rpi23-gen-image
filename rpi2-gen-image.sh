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

source ./functions.sh

set -e
set -x

# Debian release
RELEASE=${RELEASE:=jessie}
KERNEL=${KERNEL:=3.18.0-trunk-rpi2}

# Build settings
BASEDIR=$(pwd)/images/${RELEASE}
BUILDDIR=${BASEDIR}/build

# General settings
HOSTNAME=${HOSTNAME:=rpi2-${RELEASE}}
PASSWORD=${PASSWORD:=raspberry}
DEFLOCAL=${DEFLOCAL:="en_US.UTF-8"}
TIMEZONE=${TIMEZONE:="Europe/Berlin"}
XKBMODEL=${XKBMODEL:=""}
XKBLAYOUT=${XKBLAYOUT:=""}
XKBVARIANT=${XKBVARIANT:=""}
XKBOPTIONS=${XKBOPTIONS:=""}
EXPANDROOT=${EXPANDROOT:=true}

# Network settings
ENABLE_DHCP=${ENABLE_DHCP:=true}
# NET_* settings are ignored when ENABLE_DHCP=true
# NET_ADDRESS is an IPv4 or IPv6 address and its prefix, separated by "/"
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
ENABLE_UBOOT=${ENABLE_UBOOT:=false}
ENABLE_FBTURBO=${ENABLE_FBTURBO:=false}
ENABLE_HARDNET=${ENABLE_HARDNET:=false}
ENABLE_IPTABLES=${ENABLE_IPTABLES:=false}

# Kernel compilation settings
BUILD_KERNEL=${BUILD_KERNEL:=false}

# Image chroot path
R=${BUILDDIR}/chroot
CHROOT_SCRIPTS=${CHROOT_SCRIPTS:=""}

# Packages required for bootstrapping
REQUIRED_PACKAGES="debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git-core"

# Missing packages that need to be installed
MISSING_PACKAGES=""

# Packages required in the chroot build environment
APT_INCLUDES=${APT_INCLUDES:=""}
APT_INCLUDES="${APT_INCLUDES},apt-transport-https,ca-certificates,debian-archive-keyring,dialog,sudo"

set +x

# Are we running as root?
if [ "$(id -u)" -ne "0" ] ; then
  echo "this script must be executed with root privileges"
  exit 1
fi

# Add packages required for kernel cross compilation
if [ "$BUILD_KERNEL" = true ] ; then
  REQUIRED_PACKAGES="${REQUIRED_PACKAGES} crossbuild-essential-armhf"
fi

# Check if all required packages are installed
for package in $REQUIRED_PACKAGES ; do
  if [ "`dpkg-query -W -f='${Status}' $package`" != "install ok installed" ] ; then
    MISSING_PACKAGES="$MISSING_PACKAGES $package"
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
if [ -e "$BUILDDIR" ]; then
  echo "directory $BUILDDIR already exists, not proceeding"
  exit 1
fi

set -x

# Call "cleanup" function on various signals and errors
trap cleanup 0 1 2 3 6

# Set up chroot directory
mkdir -p $R

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

if [ "$ENABLE_USER" = true ]; then
  APT_INCLUDES="${APT_INCLUDES},sudo"
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

## Main bootstrap
for i in bootstrap.d/*.sh; do
  . $i
done

for i in custom.d/*.sh; do
  . $i
done

# Invoke custom scripts
if [ -n "${CHROOT_SCRIPTS}" ]; then
  cp -r "${CHROOT_SCRIPTS}" "${R}/chroot_scripts"
  LANG=C chroot $R bash -c 'for SCRIPT in /chroot_scripts/*; do if [ -f $SCRIPT -a -x $SCRIPT ]; then $SCRIPT; fi done;'
  rm -rf "${R}/chroot_scripts"
fi

## Cleanup
chroot_exec apt-get -y clean
chroot_exec apt-get -y autoclean
chroot_exec apt-get -y autoremove

# Unmount mounted filesystems
umount -l $R/proc
umount -l $R/sys

# Clean up files
rm -f $R/etc/apt/sources.list.save
rm -f $R/etc/resolvconf/resolv.conf.d/original
rm -rf $R/run
mkdir -p $R/run
rm -f $R/etc/*-
rm -f $R/root/.bash_history
rm -rf $R/tmp/*
rm -f $R/var/lib/urandom/random-seed
[ -L $R/var/lib/dbus/machine-id ] || rm -f $R/var/lib/dbus/machine-id
rm -f $R/etc/machine-id
rm -fr $R/etc/apt/apt.conf.d/10proxy

# Calculate size of the chroot directory in KB
CHROOT_SIZE=$(expr `du -s $R | awk '{ print $1 }'`)

# Calculate the amount of needed 512 Byte sectors
TABLE_SECTORS=$(expr 1 \* 1024 \* 1024 \/ 512)
BOOT_SECTORS=$(expr 64 \* 1024 \* 1024 \/ 512)
ROOT_OFFSET=$(expr ${TABLE_SECTORS} + ${BOOT_SECTORS})

# The root partition is EXT4
# This means more space than the actual used space of the chroot is used.
# As overhead for journaling and reserved blocks 20% are added.
ROOT_SECTORS=$(expr $(expr ${CHROOT_SIZE} + ${CHROOT_SIZE} \/ 100 \* 20) \* 1024 \/ 512)

# Calculate required image size in 512 Byte sectors
IMAGE_SECTORS=$(expr ${TABLE_SECTORS} + ${BOOT_SECTORS} + ${ROOT_SECTORS})

# Prepare date string for image file name
DATE="$(date +%Y-%m-%d)"

# Prepare image file
dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}.img" bs=512 count=${TABLE_SECTORS}
dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}.img" bs=512 count=0 seek=${IMAGE_SECTORS}

# Write partition table
sfdisk -q -f "$BASEDIR/${DATE}-debian-${RELEASE}.img" <<EOM
unit: sectors

1 : start=   ${TABLE_SECTORS}, size=   ${BOOT_SECTORS}, Id= c, bootable
2 : start=     ${ROOT_OFFSET}, size=   ${ROOT_SECTORS}, Id=83
3 : start=                  0, size=                 0, Id= 0
4 : start=                  0, size=                 0, Id= 0
EOM

# Set up temporary loop devices and build filesystems
VFAT_LOOP="$(losetup -o 1M --sizelimit 64M -f --show $BASEDIR/${DATE}-debian-${RELEASE}.img)"
EXT4_LOOP="$(losetup -o 65M -f --show $BASEDIR/${DATE}-debian-${RELEASE}.img)"
mkfs.vfat "$VFAT_LOOP"
mkfs.ext4 "$EXT4_LOOP"

# Mount the temporary loop devices
mkdir -p "$BUILDDIR/mount"
mount "$EXT4_LOOP" "$BUILDDIR/mount"

mkdir -p "$BUILDDIR/mount/boot/firmware"
mount "$VFAT_LOOP" "$BUILDDIR/mount/boot/firmware"

# Copy all files from the chroot to the loop device mount point directory
rsync -a "$R/" "$BUILDDIR/mount/"

# Unmount all temporary loop devices and mount points
cleanup

# (optinal) create block map file for "bmaptool"
bmaptool create -o "$BASEDIR/${DATE}-debian-${RELEASE}.bmap" "$BASEDIR/${DATE}-debian-${RELEASE}.img"

# Image was successfully created
echo "$BASEDIR/${DATE}-debian-${RELEASE}.img (${IMAGE_SIZE})" ": successfully created"
