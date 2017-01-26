#!/bin/bash

clear

# Raspberry Pi model configuration
RPI_MODEL=${RPI_MODEL:=2}
RPI2_DTB_FILE=${RPI2_DTB_FILE:=bcm2709-rpi-2-b.dtb}
RPI2_UBOOT_CONFIG=${RPI2_UBOOT_CONFIG:=rpi_2_defconfig}
RPI3_DTB_FILE=${RPI3_DTB_FILE:=bcm2710-rpi-3-b.dtb}
RPI3_UBOOT_CONFIG=${RPI3_UBOOT_CONFIG:=rpi_3_32b_defconfig}

# Debian release
RELEASE=${RELEASE:=jessie}
KERNEL_ARCH=${KERNEL_ARCH:=arm}
RELEASE_ARCH=${RELEASE_ARCH:=armhf}
CROSS_COMPILE=${CROSS_COMPILE:=arm-linux-gnueabihf-}
COLLABORA_KERNEL=${COLLABORA_KERNEL:=3.18.0-trunk-rpi2}
KERNEL_DEFCONFIG=${KERNEL_DEFCONFIG:=bcm2709_defconfig}
KERNEL_IMAGE=${KERNEL_IMAGE:=kernel7.img}
QEMU_BINARY=${QEMU_BINARY:=/usr/bin/qemu-arm-static}

# URLs
KERNEL_URL=${KERNEL_URL:=https://github.com/raspberrypi/linux}
FIRMWARE_URL=${FIRMWARE_URL:=https://github.com/raspberrypi/firmware/raw/master/boot}
WLAN_FIRMWARE_URL=${WLAN_FIRMWARE_URL:=https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm80211/brcm}
COLLABORA_URL=${COLLABORA_URL:=https://repositories.collabora.co.uk/debian}
FBTURBO_URL=${FBTURBO_URL:=https://github.com/ssvb/xf86-video-fbturbo.git}
UBOOT_URL=${UBOOT_URL:=git://git.denx.de/u-boot.git}

# Build directories
BASEDIR="$(pwd)/images/${RELEASE}"
BUILDDIR="${BASEDIR}/build"

# Chroot directories
R="${BUILDDIR}/chroot"
ETC_DIR="${R}/etc"
LIB_DIR="${R}/lib"
BOOT_DIR="${R}/boot/firmware"
KERNEL_DIR="${R}/usr/src/linux"
WLAN_FIRMWARE_DIR="${R}/lib/firmware/brcm"

# Firmware directory: Blank if download from github
RPI_FIRMWARE_DIR=${RPI_FIRMWARE_DIR:=""}

# General settings
HOSTNAME=${HOSTNAME:=rpi${RPI_MODEL}-${RELEASE}}
PASSWORD=${PASSWORD:=raspberry}
USER_PASSWORD=${USER_PASSWORD:=raspberry}
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
ENABLE_NONFREE=${ENABLE_NONFREE:=false}
ENABLE_WIRELESS=${ENABLE_WIRELESS:=false}
ENABLE_SOUND=${ENABLE_SOUND:=true}
ENABLE_DBUS=${ENABLE_DBUS:=true}
ENABLE_HWRANDOM=${ENABLE_HWRANDOM:=true}
ENABLE_MINGPU=${ENABLE_MINGPU:=false}
ENABLE_XORG=${ENABLE_XORG:=true}
ENABLE_WM=${ENABLE_WM:="lxde"}
ENABLE_RSYSLOG=${ENABLE_RSYSLOG:=true}
ENABLE_USER=${ENABLE_USER:=true}
USER_NAME=${USER_NAME:="pi"}
ENABLE_ROOT=${ENABLE_ROOT:=false}
ENABLE_ROOT_SSH=${ENABLE_ROOT_SSH:=false}

# Advanced settings
ENABLE_MINBASE=${ENABLE_MINBASE:=false}
ENABLE_REDUCE=${ENABLE_REDUCE:=false}
ENABLE_UBOOT=${ENABLE_UBOOT:=false}
ENABLE_FBTURBO=${ENABLE_FBTURBO:=true}
ENABLE_HARDNET=${ENABLE_HARDNET:=false}
ENABLE_IPTABLES=${ENABLE_IPTABLES:=false}
ENABLE_SPLITFS=${ENABLE_SPLITFS:=false}
ENABLE_INITRAMFS=${ENABLE_INITRAMFS:=true}
ENABLE_IFNAMES=${ENABLE_IFNAMES:=true}

# Kernel compilation settings
BUILD_KERNEL=${BUILD_KERNEL:=true}
KERNEL_REDUCE=${KERNEL_REDUCE:=false}
KERNEL_THREADS=${KERNEL_THREADS:=1}
KERNEL_HEADERS=${KERNEL_HEADERS:=true}
KERNEL_MENUCONFIG=${KERNEL_MENUCONFIG:=false}
KERNEL_REMOVESRC=${KERNEL_REMOVESRC:=true}

# Kernel compilation from source directory settings
KERNELSRC_DIR=${KERNELSRC_DIR:="/opt/linux"}
KERNELSRC_CLEAN=${KERNELSRC_CLEAN:=false}
KERNELSRC_CONFIG=${KERNELSRC_CONFIG:=true}
KERNELSRC_PREBUILT=${KERNELSRC_PREBUILT:=false}
KERNELSRC_BRANCH=${KERNELSRC_BRANCH:="linux_stable"}

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
APT_INCLUDES="${APT_INCLUDES},apt-transport-https,apt-utils,ca-certificates,debian-archive-keyring,dialog,sudo,systemd,sysvinit-utils"

# Packages required for bootstrapping
REQUIRED_PACKAGES="debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git bc psmisc"
MISSING_PACKAGES=""

