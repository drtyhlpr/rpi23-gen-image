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

# Clean up all temporary mount points
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

# Debian release
RELEASE=${RELEASE:=jessie}

# Build settings
BASEDIR=./images/${RELEASE}
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

# Advanced settings
ENABLE_MINBASE=${ENABLE_MINBASE:=false}
ENABLE_UBOOT=${ENABLE_UBOOT:=false}
ENABLE_FBTURBO=${ENABLE_FBTURBO:=false}
ENABLE_HARDNET=${ENABLE_HARDNET:=false}
ENABLE_IPTABLES=${ENABLE_IPTABLES:=false}

# Image chroot path
R=${BUILDDIR}/chroot

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

# Base debootstrap (unpack only)
if [ "$ENABLE_MINBASE" = true ] ; then
  http_proxy=${APT_PROXY} debootstrap --arch=armhf --variant=minbase --foreign --include=${APT_INCLUDES} $RELEASE $R http://${APT_SERVER}/debian
else
  http_proxy=${APT_PROXY} debootstrap --arch=armhf --foreign --include=${APT_INCLUDES} $RELEASE $R http://${APT_SERVER}/debian
fi

# Copy qemu emulator binary to chroot
cp /usr/bin/qemu-arm-static $R/usr/bin

# Copy debian-archive-keyring.pgp
chroot $R mkdir -p /usr/share/keyrings
cp /usr/share/keyrings/debian-archive-keyring.gpg $R/usr/share/keyrings/debian-archive-keyring.gpg

# Complete the bootstrapping process
chroot $R /debootstrap/debootstrap --second-stage

# Mount required filesystems
mount -t proc none $R/proc
mount -t sysfs none $R/sys
mount --bind /dev/pts $R/dev/pts

# Use proxy inside chroot
if [ -z "$APT_PROXY" ] ; then
  echo "Acquire::http::Proxy \"$APT_PROXY\";" >> $R/etc/apt/apt.conf.d/10proxy
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

# Set up default locale and keyboard configuration
if [ "$ENABLE_MINBASE" = false ] ; then
  # Set locale choice in debconf db, even though dpkg-reconfigure ignores and overwrites them due to some bug
  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=684134 https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=685957
  # ... so we have to set locales manually
  if [ "$DEFLOCAL" = "en_US.UTF-8" ] ; then
    LANG=C chroot $R echo "locales locales/locales_to_be_generated multiselect ${DEFLOCAL} UTF-8" | debconf-set-selections
  else
    # en_US.UTF-8 should be available anyway : https://www.debian.org/doc/manuals/debian-reference/ch08.en.html#_the_reconfiguration_of_the_locale
    LANG=C chroot $R echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8, ${DEFLOCAL} UTF-8" | debconf-set-selections
    LANG=C chroot $R sed -i "/en_US.UTF-8/s/^#//" /etc/locale.gen
  fi
  LANG=C chroot $R sed -i "/${DEFLOCAL}/s/^#//" /etc/locale.gen
  LANG=C chroot $R echo "locales locales/default_environment_locale select ${DEFLOCAL}" | debconf-set-selections
  LANG=C chroot $R locale-gen
  LANG=C chroot $R update-locale LANG=${DEFLOCAL}

  # Keyboard configuration, if requested
  if [ "$XKBMODEL" != "" ] ; then
    LANG=C chroot $R sed -i "s/^XKBMODEL.*/XKBMODEL=\"${XKBMODEL}\"/" /etc/default/keyboard
  fi
  if [ "$XKBLAYOUT" != "" ] ; then
    LANG=C chroot $R sed -i "s/^XKBLAYOUT.*/XKBLAYOUT=\"${XKBLAYOUT}\"/" /etc/default/keyboard
  fi
  if [ "$XKBVARIANT" != "" ] ; then
    LANG=C chroot $R sed -i "s/^XKBVARIANT.*/XKBVARIANT=\"${XKBVARIANT}\"/" /etc/default/keyboard
  fi
  if [ "$XKBOPTIONS" != "" ] ; then
    LANG=C chroot $R sed -i "s/^XKBOPTIONS.*/XKBOPTIONS=\"${XKBOPTIONS}\"/" /etc/default/keyboard
  fi
  LANG=C chroot $R dpkg-reconfigure -f noninteractive keyboard-configuration
  # Set up font console
  case "${DEFLOCAL}" in
    *UTF-8)
      LANG=C chroot $R sed -i 's/^CHARMAP.*/CHARMAP="UTF-8"/' /etc/default/console-setup
      ;;
    *)
      LANG=C chroot $R sed -i 's/^CHARMAP.*/CHARMAP="guess"/' /etc/default/console-setup
      ;;
  esac
  LANG=C chroot $R dpkg-reconfigure -f noninteractive console-setup
fi

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

# Set up IPv4 hosts
echo ${HOSTNAME} >$R/etc/hostname
cat <<EOM >$R/etc/hosts
127.0.0.1       localhost
127.0.1.1       ${HOSTNAME}
EOM
if [ "$NET_ADDRESS" != "" ] ; then
NET_IP=$(echo ${NET_ADDRESS} | cut -f 1 -d'/')
sed -i "s/^127.0.1.1/${NET_IP}/" $R/etc/hosts
fi

# Set up IPv6 hosts
if [ "$ENABLE_IPV6" = true ] ; then
cat <<EOM >>$R/etc/hosts

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOM
fi

# Place hint about network configuration
cat <<EOM >$R/etc/network/interfaces
# Debian switched to systemd-networkd configuration files.
# please configure your networks in '/etc/systemd/network/'
EOM

if [ "$ENABLE_DHCP" = true ] ; then
# Enable systemd-networkd DHCP configuration for interface eth0
cat <<EOM >$R/etc/systemd/network/eth.network
[Match]
Name=eth0

[Network]
DHCP=yes
EOM

# Set DHCP configuration to IPv4 only
if [ "$ENABLE_IPV6" = false ] ; then
  sed -i "s/^DHCP=yes/DHCP=v4/" $R/etc/systemd/network/eth.network
fi
else # ENABLE_DHCP=false
cat <<EOM >$R/etc/systemd/network/eth.network
[Match]
Name=eth0

[Network]
DHCP=no
Address=${NET_ADDRESS}
Gateway=${NET_GATEWAY}
DNS=${NET_DNS_1}
DNS=${NET_DNS_2}
Domains=${NET_DNS_DOMAINS}
NTP=${NET_NTP_1}
NTP=${NET_NTP_2}
EOM
fi

# Enable systemd-networkd service
LANG=C chroot $R systemctl enable systemd-networkd

# Generate crypt(3) password string
ENCRYPTED_PASSWORD=`mkpasswd -m sha-512 ${PASSWORD}`

# Set up default user
LANG=C chroot $R adduser --gecos "Raspberry PI user" --add_extra_groups --disabled-password pi
LANG=C chroot $R usermod -a -G sudo -p "${ENCRYPTED_PASSWORD}" pi

# Set up root password
LANG=C chroot $R usermod -p "${ENCRYPTED_PASSWORD}" root

# Set up firmware boot cmdline
CMDLINE="dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootfstype=ext4 rootflags=commit=100,data=writeback elevator=deadline rootwait net.ifnames=1 console=tty1"

# Set up serial console support (if requested)
if [ "$ENABLE_CONSOLE" = true ] ; then
  CMDLINE="${CMDLINE} console=ttyAMA0,115200 kgdboc=ttyAMA0,115200"
fi

# Set up IPv6 networking support
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

# Load snd_bcm2835 kernel module at boot time
if [ "$ENABLE_SOUND" = true ] ; then
  echo "snd_bcm2835" >>$R/etc/modules
fi

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

# Remove SSHD related iptables rules
if [ "$ENABLE_SSHD" = false ] ; then
 sed -e '/^#/! {/SSH/ s/^/# /}' -i $R/etc/iptables/iptables.rules 2> /dev/null
 sed -e '/^#/! {/SSH/ s/^/# /}' -i $R/etc/iptables/ip6tables.rules 2> /dev/null
fi

# Install gcc/c++ build environment inside the chroot
if [ "$ENABLE_UBOOT" = true ] || [ "$ENABLE_FBTURBO" = true ]; then
  LANG=C chroot $R apt-get install -q -y --force-yes --no-install-recommends linux-compiler-gcc-4.9-arm g++ make bc
fi

# Fetch and build U-Boot bootloader
if [ "$ENABLE_UBOOT" = true ] ; then
  # Fetch U-Boot bootloader sources
  git -C $R/tmp clone git://git.denx.de/u-boot.git

  # Build and install U-Boot inside chroot
  LANG=C chroot $R make -C /tmp/u-boot/ rpi_2_defconfig all

  # Copy compiled bootloader binary and set config.txt to load it
  cp $R/tmp/u-boot/u-boot.bin $R/boot/firmware/
  printf "\n# boot u-boot kernel\nkernel=u-boot.bin\n" >> $R/boot/firmware/config.txt

  # Set U-Boot command file
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

  # Generate U-Boot image from command file
  LANG=C chroot $R mkimage -A arm -O linux -T script -C none -a 0x00000000 -e 0x00000000 -n "RPi2 Boot Script" -d /boot/firmware/uboot.mkimage /boot/firmware/boot.scr
fi

# Fetch and build fbturbo Xorg driver
if [ "$ENABLE_FBTURBO" = true ] ; then
  # Fetch fbturbo driver sources
  git -C $R/tmp clone https://github.com/ssvb/xf86-video-fbturbo.git

  # Install Xorg build dependencies
  LANG=C chroot $R apt-get install -q -y --no-install-recommends xorg-dev xutils-dev x11proto-dri2-dev libltdl-dev libtool automake libdrm-dev

  # Build and install fbturbo driver inside chroot
  LANG=C chroot $R /bin/bash -c "cd /tmp/xf86-video-fbturbo; autoreconf -vi; ./configure --prefix=/usr; make; make install"

  # Add fbturbo driver to Xorg configuration
  cat <<EOM >$R/usr/share/X11/xorg.conf.d/99-fbturbo.conf
Section "Device"
        Identifier "Allwinner A10/A13 FBDEV"
        Driver "fbturbo"
        Option "fbdev" "/dev/fb0"
        Option "SwapbuffersWait" "true"
EndSection
EOM

  # Remove Xorg build dependencies
  LANG=C chroot $R apt-get -q -y purge --auto-remove xorg-dev xutils-dev x11proto-dri2-dev libltdl-dev libtool automake libdrm-dev
fi

# Remove gcc/c++ build environment from the chroot
if [ "$ENABLE_UBOOT" = true ] || [ "$ENABLE_FBTURBO" = true ]; then
  LANG=C chroot $R apt-get -y -q purge --auto-remove bc binutils cpp cpp-4.9 g++ g++-4.9 gcc gcc-4.9 libasan1 libatomic1 libc-dev-bin libc6-dev libcloog-isl4 libgcc-4.9-dev libgomp1 libisl10 libmpc3 libmpfr4 libstdc++-4.9-dev libubsan0 linux-compiler-gcc-4.9-arm linux-libc-dev make
fi

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
