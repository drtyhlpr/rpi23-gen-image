#
# Debootstrap basic system
#

. ./functions.sh

# Base debootstrap (unpack only)
if [ "$ENABLE_MINBASE" = true ] ; then
  http_proxy=${APT_PROXY} debootstrap --arch=armhf --variant=minbase --foreign --include=${APT_INCLUDES} $RELEASE $R http://${APT_SERVER}/debian
else
  http_proxy=${APT_PROXY} debootstrap --arch=armhf --foreign --include=${APT_INCLUDES} $RELEASE $R http://${APT_SERVER}/debian
fi

# Copy qemu emulator binary to chroot
cp /usr/bin/qemu-arm-static $R/usr/bin

# Copy debian-archive-keyring.pgp
mkdir -p $R/usr/share/keyrings
cp /usr/share/keyrings/debian-archive-keyring.gpg $R/usr/share/keyrings/debian-archive-keyring.gpg

# Complete the bootstrapping process
chroot_exec /debootstrap/debootstrap --second-stage

# Mount required filesystems
mount -t proc none $R/proc
mount -t sysfs none $R/sys
mount --bind /dev/pts $R/dev/pts
