#!/bin/bash
#
# Build and Setup fbturbo Xorg driver
#

# Load utility functions
. ./functions.sh

if [ "$ENABLE_FBTURBO" = true ] ; then
  # Install c/c++ build environment inside the chroot
  chroot_install_cc

  # Copy existing fbturbo sources into chroot directory
  if [ -n "$FBTURBOSRC_DIR" ] && [ -d "$FBTURBOSRC_DIR" ] ; then
    # Copy local fbturbo sources
    cp -r "${FBTURBOSRC_DIR}" "${R}/tmp"
  else
    # Create temporary directory for fbturbo sources
    temp_dir=$(as_nobody mktemp -d)

    # Fetch fbturbo sources
    as_nobody git -C "${temp_dir}" clone "${FBTURBO_URL}"

    # Move downloaded fbturbo sources
    mv "${temp_dir}/xf86-video-fbturbo" "${R}/tmp/"

    # Remove temporary directory for fbturbo sources
    rm -fr "${temp_dir}"
  fi

  # Install Xorg build dependencies
  if [ "$RELEASE" = "jessie" ] ; then
    chroot_exec apt-get -q -y --no-install-recommends install xorg-dev xutils-dev x11proto-dri2-dev libltdl-dev libtool automake libdrm-dev
  elif [ "$RELEASE" = "stretch" ] || [ "$RELEASE" = "buster" ] ; then
    chroot_exec apt-get -q -y --no-install-recommends --allow-unauthenticated install xorg-dev xutils-dev x11proto-dri2-dev libltdl-dev libtool automake libdrm-dev
  fi

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
