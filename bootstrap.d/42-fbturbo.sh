#
# Fetch and build fbturbo Xorg driver
#

. ./functions.sh

if [ "$ENABLE_FBTURBO" = true ] ; then
  # Fetch fbturbo driver sources
  git -C $R/tmp clone https://github.com/ssvb/xf86-video-fbturbo.git

  # Install Xorg build dependencies
  chroot_exec apt-get install -q -y --no-install-recommends xorg-dev xutils-dev x11proto-dri2-dev libltdl-dev libtool automake libdrm-dev

  # Build and install fbturbo driver inside chroot
  chroot_exec /bin/bash -c "cd /tmp/xf86-video-fbturbo; autoreconf -vi; ./configure --prefix=/usr; make; make install"

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
  chroot_exec apt-get -q -y purge --auto-remove xorg-dev xutils-dev x11proto-dri2-dev libltdl-dev libtool automake libdrm-dev
fi

# Remove gcc/c++ build environment from the chroot
if [ "$ENABLE_UBOOT" = true ] || [ "$ENABLE_FBTURBO" = true ]; then
  chroot_exec apt-get -y -q purge --auto-remove bc binutils cpp cpp-4.9 g++ g++-4.9 gcc gcc-4.9 libasan1 libatomic1 libc-dev-bin libc6-dev libcloog-isl4 libgcc-4.9-dev libgomp1 libisl10 libmpc3 libmpfr4 libstdc++-4.9-dev libubsan0 linux-compiler-gcc-4.9-arm linux-libc-dev make
fi
