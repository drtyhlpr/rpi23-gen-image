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

cleanup (){
  set +x
  set +e
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

set -e
set -x

RELEASE=${RELEASE:=jessie}

# Build settings
BASEDIR=./images/${RELEASE}
BUILDDIR=${BASEDIR}/build

# General settings
HOSTNAME=${HOSTNAME:=rpi2-${RELEASE}}
PASSWORD=${PASSWORD:=raspberry}
DEFLOCAL=${DEFLOCAL:="en_US.UTF-8"}
TIMEZONE=${TIMEZONE:="Europe/Berlin"}

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
ENABLE_FLUXBOX=${ENABLE_FLUXBOX:=false}

# Advanced settings
ENABLE_MINBASE=${ENABLE_MINBASE:=false}
ENABLE_UBOOT=${ENABLE_UBOOT:=false}
ENABLE_HARDNET=${ENABLE_HARDNET:=false}
ENABLE_IPTABLES=${ENABLE_IPTABLES:=false}

# Image chroot path
R=${BUILDDIR}/chroot

# Packages required for bootstrapping
REQUIRED_PACKAGES="debootstrap debian-archive-keyring qemu-user-static dosfstools rsync bmap-tools whois git-core"

# Missing packages that need to be installed
MISSING_PACKAGES=""

# Packages required in the chroot build enviroment
APT_INCLUDES="apt-transport-https,ca-certificates,debian-archive-keyring,dialog,sudo"

set +x

# Are we running as root?
if [ "$(id -u)" -ne "0" ] ; then
  echo "this script must be executed with root privileges"
  exit 1
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
  APT_INCLUDES="${APT_INCLUDES},vim-tiny,net-tools"
else
  APT_INCLUDES="${APT_INCLUDES},locales"
fi

# Add dbus package, recommended if using systemd
if [ "$ENABLE_DBUS" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},dbus"
fi

# Add openssh server package
if [ "$ENABLE_SSHD" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},openssh-server"
fi

# Add rng-tools package
if [ "$ENABLE_HWRANDOM" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},rng-tools"
fi

# Add xorg package
if [ "$ENABLE_XORG" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},xorg"
fi

# Add fluxbox package with eterm
if [ "$ENABLE_FLUXBOX" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},fluxbox,eterm"
fi

# Set empty proxy string
if [ -z "$APT_PROXY" ] ; then
  APT_PROXY="http://"
fi

# Base debootstrap (unpack only)
if [ "$ENABLE_MINBASE" = true ] ; then
  debootstrap --arch=armhf --variant=minbase --foreign --include=${APT_INCLUDES} $RELEASE $R ${APT_PROXY}${APT_SERVER}/debian
else
  debootstrap --arch=armhf --foreign --include=${APT_INCLUDES} $RELEASE $R ${APT_PROXY}${APT_SERVER}/debian
fi

# Copy qemu emulator binary to chroot
cp /usr/bin/qemu-arm-static $R/usr/bin

# Copy debian-archive-keyring.pgp
chroot $R mkdir -p /usr/share/keyrings
cp /usr/share/keyrings/debian-archive-keyring.gpg $R/usr/share/keyrings/debian-archive-keyring.gpg

# Complete the bootstrapping proccess
chroot $R /debootstrap/debootstrap --second-stage

# Mount required filesystems
mount -t proc none $R/proc
mount -t sysfs none $R/sys
mount --bind /dev/pts $R/dev/pts

# Use proxy inside chroot
if [ -z "$APT_PROXY" ] ; then
  echo "Acquire::http::Proxy \"$APT_PROXY\"" >> $R/etc/apt/apt.conf.d/10proxy
fi

# Pin package flash-kernel to repositories.collabora.co.uk
cat <<EOM >$R/etc/apt/preferences.d/flash-kernel
Package: flash-kernel
Pin: origin repositories.collabora.co.uk
Pin-Priority: 1000
EOM

# Set up timezone
echo ${TIMEZONE} >$R/etc/timezone
LANG=C chroot $R dpkg-reconfigure -f noninteractive tzdata

# Set up default locales to "en_US.UTF-8" default
if [ "$ENABLE_MINBASE" = false ] ; then
  LANG=C chroot $R sed -i '/${DEFLOCAL}/s/^#//' /etc/locale.gen
  LANG=C chroot $R locale-gen ${DEFLOCAL}
fi

# Upgrade collabora package index and install collabora keyring
echo "deb https://repositories.collabora.co.uk/debian ${RELEASE} rpi2" >$R/etc/apt/sources.list
LANG=C chroot $R apt-get -qq -y update
LANG=C chroot $R apt-get -qq -y --force-yes install collabora-obs-archive-keyring

# Set up initial sources.list
cat <<EOM >$R/etc/apt/sources.list
deb http://${APT_SERVER}/debian ${RELEASE} main contrib
#deb-src http://${APT_SERVER}/debian ${RELEASE} main contrib

deb http://${APT_SERVER}/debian/ ${RELEASE}-updates main contrib
#deb-src http://${APT_SERVER}/debian/ ${RELEASE}-updates main contrib

deb http://security.debian.org/ ${RELEASE}/updates main contrib
#deb-src http://security.debian.org/ ${RELEASE}/updates main contrib

deb https://repositories.collabora.co.uk/debian ${RELEASE} rpi2
EOM

# Upgrade package index and update all installed packages and changed dependencies
LANG=C chroot $R apt-get -qq -y update
LANG=C chroot $R apt-get -qq -y -u dist-upgrade

# Kernel installation
# Install flash-kernel last so it doesn't try (and fail) to detect the platform in the chroot
LANG=C chroot $R apt-get -qq -y --no-install-recommends install linux-image-3.18.0-trunk-rpi2
LANG=C chroot $R apt-get -qq -y install flash-kernel

VMLINUZ="$(ls -1 $R/boot/vmlinuz-* | sort | tail -n 1)"
[ -z "$VMLINUZ" ] && exit 1
mkdir -p $R/boot/firmware

# required boot binaries from raspberry/firmware github (commit: "kernel: Bump to 3.18.10")
wget -q -O $R/boot/firmware/bootcode.bin https://github.com/raspberrypi/firmware/raw/cd355a9dd4f1f4de2e79b0c8e102840885cdf1de/boot/bootcode.bin
wget -q -O $R/boot/firmware/fixup_cd.dat https://github.com/raspberrypi/firmware/raw/cd355a9dd4f1f4de2e79b0c8e102840885cdf1de/boot/fixup_cd.dat
wget -q -O $R/boot/firmware/fixup.dat https://github.com/raspberrypi/firmware/raw/cd355a9dd4f1f4de2e79b0c8e102840885cdf1de/boot/fixup.dat
wget -q -O $R/boot/firmware/fixup_x.dat https://github.com/raspberrypi/firmware/raw/cd355a9dd4f1f4de2e79b0c8e102840885cdf1de/boot/fixup_x.dat
wget -q -O $R/boot/firmware/start_cd.elf https://github.com/raspberrypi/firmware/raw/cd355a9dd4f1f4de2e79b0c8e102840885cdf1de/boot/start_cd.elf
wget -q -O $R/boot/firmware/start.elf https://github.com/raspberrypi/firmware/raw/cd355a9dd4f1f4de2e79b0c8e102840885cdf1de/boot/start.elf
wget -q -O $R/boot/firmware/start_x.elf https://github.com/raspberrypi/firmware/raw/cd355a9dd4f1f4de2e79b0c8e102840885cdf1de/boot/start_x.elf
cp $VMLINUZ $R/boot/firmware/kernel7.img

# Set up hosts
echo ${HOSTNAME} >$R/etc/hostname
cat <<EOM >$R/etc/hosts
127.0.0.1       localhost
127.0.1.1       ${HOSTNAME}
EOM

if [ "$ENABLE_IPV6" = true ] ; then
cat <<EOM >>$R/etc/hosts

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOM
fi

# Generate crypt(3) password string
ENCRYPTED_PASSWORD=`mkpasswd -m sha-512 ${PASSWORD}`

# Set up default user
LANG=C chroot $R adduser --gecos "Raspberry PI user" --add_extra_groups --disabled-password pi
LANG=C chroot $R usermod -a -G sudo -p "${ENCRYPTED_PASSWORD}" pi

# Set up root password
LANG=C chroot $R usermod -p "${ENCRYPTED_PASSWORD}" root

# Set up interfaces
cat <<EOM >$R/etc/network/interfaces
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug eth0
iface eth0 inet dhcp
EOM

# Set up firmware boot cmdline
CMDLINE="dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootfstype=ext4 rootflags=commit=100,data=writeback elevator=deadline rootwait net.ifnames=1 console=tty1"

# Set up serial console support (if requested)
if [ "$ENABLE_CONSOLE" = true ] ; then
  CMDLINE="${CMDLINE} console=ttyAMA0,115200 kgdboc=ttyAMA0,115200"
fi

# Set up ipv6 support (if requested)
if [ "$ENABLE_IPV6" = false ] ; then
  CMDLINE="${CMDLINE} ipv6.disable=1"
fi

echo "${CMDLINE}" >$R/boot/firmware/cmdline.txt

# Set up firmware config
cat <<EOM >$R/boot/firmware/config.txt
# For more options and information see
# http://www.raspberrypi.org/documentation/configuration/config-txt.md
# Some settings may impact device functionality. See link above for details

# uncomment if you get no picture on HDMI for a default "safe" mode
#hdmi_safe=1

# uncomment this if your display has a black border of unused pixels visible
# and your display can output without overscan
#disable_overscan=1

# uncomment the following to adjust overscan. Use positive numbers if console
# goes off screen, and negative if there is too much border
#overscan_left=16
#overscan_right=16
#overscan_top=16
#overscan_bottom=16

# uncomment to force a console size. By default it will be display's size minus
# overscan.
#framebuffer_width=1280
#framebuffer_height=720

# uncomment if hdmi display is not detected and composite is being output
#hdmi_force_hotplug=1

# uncomment to force a specific HDMI mode (this will force VGA)
#hdmi_group=1
#hdmi_mode=1

# uncomment to force a HDMI mode rather than DVI. This can make audio work in
# DMT (computer monitor) modes
#hdmi_drive=2

# uncomment to increase signal to HDMI, if you have interference, blanking, or
# no display
#config_hdmi_boost=4

# uncomment for composite PAL
#sdtv_mode=2

# uncomment to overclock the arm. 700 MHz is the default.
#arm_freq=800
EOM

# Set smallest possible GPU memory allocation size: 16MB (no X)
if [ "$ENABLE_MINGPU" = true ] ; then
  echo "gpu_mem=16" >>$R/boot/firmware/config.txt
fi

# Create symlinks
ln -sf firmware/config.txt $R/boot/config.txt
ln -sf firmware/cmdline.txt $R/boot/cmdline.txt

# Prepare modules-load.d directory
mkdir -p $R/lib/modules-load.d/

# Load random module on boot
if [ "$ENABLE_HWRANDOM" = true ] ; then
  cat <<EOM >$R/lib/modules-load.d/rpi2.conf
bcm2708_rng
EOM
fi

# Prepare modprobe.d directory
mkdir -p $R/etc/modprobe.d/

# Blacklist sound modules
cat <<EOM >$R/etc/modprobe.d/raspi-blacklist.conf
blacklist snd_soc_core
blacklist snd_pcm
blacklist snd_pcm_dmaengine
blacklist snd_timer
blacklist snd_compress
blacklist snd_soc_pcm512x_i2c
blacklist snd_soc_pcm512x
blacklist snd_soc_tas5713
blacklist snd_soc_wm8804
EOM

# Create default fstab
cat <<EOM >$R/etc/fstab
/dev/mmcblk0p2 / ext4 noatime,nodiratime,errors=remount-ro,discard,data=writeback,commit=100 0 1
/dev/mmcblk0p1 /boot/firmware vfat defaults,noatime,nodiratime 0 2
EOM

# Avoid swapping and increase cache sizes
cat <<EOM >>$R/etc/sysctl.d/99-sysctl.conf

# Avoid swapping and increase cache sizes
vm.swappiness=1
vm.dirty_background_ratio=20
vm.dirty_ratio=40
vm.dirty_writeback_centisecs=500
vm.dirty_expire_centisecs=6000
EOM

# Enable network stack hardening
if [ "$ENABLE_HARDNET" = true ] ; then
  cat <<EOM >>$R/etc/sysctl.d/99-sysctl.conf

# Enable network stack hardening
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.lo.accept_redirects=0
net.ipv4.conf.lo.send_redirects=0
net.ipv4.conf.lo.accept_source_route=0
net.ipv4.conf.eth0.accept_redirects=0
net.ipv4.conf.eth0.send_redirects=0
net.ipv4.conf.eth0.accept_source_route=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1

net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.all.router_solicitations=0
net.ipv6.conf.all.accept_ra_rtr_pref=0
net.ipv6.conf.all.accept_ra_pinfo=0
net.ipv6.conf.all.accept_ra_defrtr=0
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.all.dad_transmits=0
net.ipv6.conf.all.max_addresses=1

net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.default.accept_source_route=0
net.ipv6.conf.default.router_solicitations=0
net.ipv6.conf.default.accept_ra_rtr_pref=0
net.ipv6.conf.default.accept_ra_pinfo=0
net.ipv6.conf.default.accept_ra_defrtr=0
net.ipv6.conf.default.autoconf=0
net.ipv6.conf.default.dad_transmits=0
net.ipv6.conf.default.max_addresses=1

net.ipv6.conf.lo.accept_redirects=0
net.ipv6.conf.lo.accept_source_route=0
net.ipv6.conf.lo.router_solicitations=0
net.ipv6.conf.lo.accept_ra_rtr_pref=0
net.ipv6.conf.lo.accept_ra_pinfo=0
net.ipv6.conf.lo.accept_ra_defrtr=0
net.ipv6.conf.lo.autoconf=0
net.ipv6.conf.lo.dad_transmits=0
net.ipv6.conf.lo.max_addresses=1

net.ipv6.conf.eth0.accept_redirects=0
net.ipv6.conf.eth0.accept_source_route=0
net.ipv6.conf.eth0.router_solicitations=0
net.ipv6.conf.eth0.accept_ra_rtr_pref=0
net.ipv6.conf.eth0.accept_ra_pinfo=0
net.ipv6.conf.eth0.accept_ra_defrtr=0
net.ipv6.conf.eth0.autoconf=0
net.ipv6.conf.eth0.dad_transmits=0
net.ipv6.conf.eth0.max_addresses=1
EOM

# Enable resolver warnings about spoofed addresses
  cat <<EOM >>$R/etc/host.conf
spoof warn
EOM
fi

# Regenerate openssh server host keys
if [ "$ENABLE_SSHD" = true ] ; then
  rm -fr $R/etc/ssh/ssh_host_*
  LANG=C chroot $R dpkg-reconfigure openssh-server
fi

# Enable serial console systemd style
if [ "$ENABLE_CONSOLE" = true ] ; then
  LANG=C chroot $R systemctl enable serial-getty\@ttyAMA0.service
fi

# Enable firewall based on iptables started by systemd service
if [ "$ENABLE_IPTABLES" = true ] ; then
  # Create iptables configuration directory
  mkdir -p "$R/etc/iptables"

  # Create iptables systemd service
  cat <<EOM >$R/etc/systemd/system/iptables.service
[Unit]
Description=Packet Filtering Framework
DefaultDependencies=no
After=systemd-sysctl.service
Before=sysinit.target
[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/iptables.rules
ExecReload=/sbin/iptables-restore /etc/iptables/iptables.rules
ExecStop=/etc/iptables/flush-iptables.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOM

  # Create flush-table script called by iptables service
  cat <<EOM >$R/etc/iptables/flush-iptables.sh
#!/bin/sh
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
EOM

  # Create iptables rule file
  cat <<EOM >$R/etc/iptables/iptables.rules
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:TCP - [0:0]
:UDP - [0:0]
:SSH - [0:0]

# Rate limit ping requests
-A INPUT -p icmp --icmp-type echo-request -m limit --limit 30/min --limit-burst 8 -j ACCEPT
-A INPUT -p icmp --icmp-type echo-request -j DROP

# Accept established connections
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Accept all traffic on loopback interface
-A INPUT -i lo -j ACCEPT

# Drop packets declared invalid
-A INPUT -m conntrack --ctstate INVALID -j DROP

# SSH rate limiting
-A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -j SSH
-A SSH -m recent --name sshbf --rttl --rcheck --hitcount 3 --seconds 10 -j DROP
-A SSH -m recent --name sshbf --rttl --rcheck --hitcount 20 --seconds 1800 -j DROP
-A SSH -m recent --name sshbf --set -j ACCEPT

# Send TCP and UDP connections to their respective rules chain
-A INPUT -p udp -m conntrack --ctstate NEW -j UDP
-A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP

# Reject dropped packets with a RFC compliant responce
-A INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
-A INPUT -p tcp -j REJECT --reject-with tcp-rst
-A INPUT -j REJECT --reject-with icmp-proto-unreachable

## TCP PORT RULES
# -A TCP -p tcp -j LOG

## UDP PORT RULES
# -A UDP -p udp -j LOG

COMMIT
EOM

  # Reload systemd configuration and enable iptables service
  LANG=C chroot $R systemctl daemon-reload
  LANG=C chroot $R systemctl enable iptables.service

  if [ "$ENABLE_IPV6" = true ] ; then
    # Create ip6tables systemd service
    cat <<EOM >$R/etc/systemd/system/ip6tables.service
[Unit]
Description=Packet Filtering Framework
DefaultDependencies=no
After=systemd-sysctl.service
Before=sysinit.target
[Service]
Type=oneshot
ExecStart=/sbin/ip6tables-restore /etc/iptables/ip6tables.rules
ExecReload=/sbin/ip6tables-restore /etc/iptables/ip6tables.rules
ExecStop=/etc/iptables/flush-ip6tables.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOM

    # Create ip6tables file
    cat <<EOM >$R/etc/iptables/flush-ip6tables.sh
#!/bin/sh
ip6tables -F
ip6tables -X
ip6tables -Z
for table in $(</proc/net/ip6_tables_names)
do
        ip6tables -t \$table -F
        ip6tables -t \$table -X
        ip6tables -t \$table -Z
done
ip6tables -P INPUT ACCEPT
ip6tables -P OUTPUT ACCEPT
ip6tables -P FORWARD ACCEPT
EOM

    # Create ip6tables rule file
    cat <<EOM >$R/etc/iptables/ip6tables.rules
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:TCP - [0:0]
:UDP - [0:0]
:SSH - [0:0]

# Drop packets with RH0 headers
-A INPUT -m rt --rt-type 0 -j DROP
-A OUTPUT -m rt --rt-type 0 -j DROP
-A FORWARD -m rt --rt-type 0 -j DROP

# Rate limit ping requests
-A INPUT -p icmpv6 --icmpv6-type echo-request -m limit --limit 30/min --limit-burst 8 -j ACCEPT
-A INPUT -p icmpv6 --icmpv6-type echo-request -j DROP

# Accept established connections
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Accept all traffic on loopback interface
-A INPUT -i lo -j ACCEPT

# Drop packets declared invalid
-A INPUT -m conntrack --ctstate INVALID -j DROP

# SSH rate limiting
-A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -j SSH
-A SSH -m recent --name sshbf --rttl --rcheck --hitcount 3 --seconds 10 -j DROP
-A SSH -m recent --name sshbf --rttl --rcheck --hitcount 20 --seconds 1800 -j DROP
-A SSH -m recent --name sshbf --set -j ACCEPT

# Send TCP and UDP connections to their respective rules chain
-A INPUT -p udp -m conntrack --ctstate NEW -j UDP
-A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP

# Reject dropped packets with a RFC compliant responce
-A INPUT -p udp -j REJECT --reject-with icmp6-adm-prohibited
-A INPUT -p tcp -j REJECT --reject-with icmp6-adm-prohibited
-A INPUT -j REJECT --reject-with icmp6-adm-prohibited

## TCP PORT RULES
# -A TCP -p tcp -j LOG

## UDP PORT RULES
# -A UDP -p udp -j LOG

COMMIT
EOM

  # Reload systemd configuration and enable iptables service
  LANG=C chroot $R systemctl daemon-reload
  LANG=C chroot $R systemctl enable ip6tables.service

  fi
fi

if [ "$ENABLE_UBOOT" = true ] ; then
  # Fetch u-boot github
  git -C $R/tmp clone git://git.denx.de/u-boot.git

  # Install minimal gcc/g++ build environment and build u-boot inside chroot
  LANG=C chroot $R apt-get install -qq -y --force-yes --no-install-recommends linux-compiler-gcc-4.9-arm g++ make bc
  LANG=C chroot $R make -C /tmp/u-boot/ rpi_2_defconfig all

  # Copy compiled bootloader binary and set config.txt to load it
  cp $R/tmp/u-boot/u-boot.bin $R/boot/firmware/
  printf "\n# boot u-boot kernel\nkernel=u-boot.bin\n" >> $R/boot/firmware/config.txt

  # Set u-boot command file
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

  # Generate u-boot image from command file
  LANG=C chroot $R mkimage -A arm -O linux -T script -C none -a 0x00000000 -e 0x00000000 -n "RPi2 Boot Script" -d /boot/firmware/uboot.mkimage /boot/firmware/boot.scr

  # Remove gcc/c++ build enviroment
  LANG=C chroot $R apt-get -y -q purge --auto-remove bc binutils cpp cpp-4.9 g++ g++-4.9 gcc gcc-4.9 libasan1 libatomic1 libc-dev-bin libc6-dev libcloog-isl4 libgcc-4.9-dev libgomp1 libisl10 libmpc3 libmpfr4 libstdc++-4.9-dev libubsan0 linux-compiler-gcc-4.9-arm linux-libc-dev make
fi

# Enable systemd-networkd DHCP configuration for the eth0 interface
printf "[Match]\nName=eth0\n\n[Network]\nDHCP=yes\n" > $R/etc/systemd/network/eth.network

# Set DHCP configuration to IPv4 only
if [ "$ENABLE_IPV6" = false ] ; then
  sed -i "s/=yes/=v4/" $R/etc/systemd/network/eth.network
fi

# Enable systemd-networkd service
LANG=C chroot $R systemctl enable systemd-networkd

# Place hint about netowrk configuration
cat <<EOM >$R/etc/network/interfaces
# Debian switched to systemd-networkd configuration files.
# please configure your networks in '/etc/systemd/network/'
EOM

# Clean cached downloads
LANG=C chroot $R apt-get -y clean
LANG=C chroot $R apt-get -y autoclean
LANG=C chroot $R apt-get -y autoremove

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

# Calculate size of the chroot directory
CHROOT_SIZE=$(expr `du -s $R | awk '{ print $1 }'` / 1024)

# Calculate required image size
IMAGE_SIZE=`expr $(expr ${CHROOT_SIZE} / 1024 + 1) \* 1024`

# Calculate number of sectors for the partition
IMAGE_SECTORS=`expr $(expr ${IMAGE_SIZE} \* 1048576) / 512 - 133120`

# Prepare date string for image file name
DATE="$(date +%Y-%m-%d)"

# Prepare image file
dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}.img" bs=1M count=1
dd if=/dev/zero of="$BASEDIR/${DATE}-debian-${RELEASE}.img" bs=1M count=0 seek=${IMAGE_SIZE}

# Write partition table
sfdisk -q -L -f "$BASEDIR/${DATE}-debian-${RELEASE}.img" <<EOM
unit: sectors

1 : start=     2048, size=   131072, Id= c, bootable
2 : start=   133120, size=  ${IMAGE_SECTORS}, Id=83
3 : start=        0, size=        0, Id= 0
4 : start=        0, size=        0, Id= 0
EOM

# Set up temporary loop devices and build filesystems
VFAT_LOOP="$(losetup -o 1M --sizelimit 64M -f --show $BASEDIR/${DATE}-debian-${RELEASE}.img)"
EXT4_LOOP="$(losetup -o 65M --sizelimit `expr ${IMAGE_SIZE} - 64`M -f --show $BASEDIR/${DATE}-debian-${RELEASE}.img)"
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
