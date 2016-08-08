#
# Build and Setup fbturbo Xorg driver
#

# Load utility functions
. ./functions.sh

if [ "$ENABLE_FBTURBO" = true ] ; then
  # Fetch fbturbo driver sources
  git -C "${R}/tmp" clone "${FBTURBO_URL}"

  # Install Xorg build dependencies
  chroot_exec apt-get -q -y --force-yes --no-install-recommends install xorg-dev xutils-dev x11proto-dri2-dev libltdl-dev libtool automake libdrm-dev

  # Build and install fbturbo driver inside chroot
  chroot_exec /bin/bash -x <<'EOF'
cd /tmp/xf86-video-fbturbo
autoreconf -vi
./configure --prefix=/usr
make
make install
EOF

  # Install fbturbo driver Xorg configuration
  install_readonly files/xorg/99-fbturbo.conf "${R}/usr/share/X11/xorg.conf.d/99-fbturbo.conf"

  # Remove Xorg build dependencies
  chroot_exec apt-get -qq -y --auto-remove purge xorg-dev xutils-dev x11proto-dri2-dev libltdl-dev libtool automake libdrm-dev
fi

# Remove gcc/c++ build environment from the chroot
if [ "$ENABLE_UBOOT" = true ] || [ "$ENABLE_FBTURBO" = true ] ; then
  chroot_exec apt-get -qq -y --auto-remove purge ${COMPILER_PACKAGES}
fi
