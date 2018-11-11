#
# Setup APT repositories
#

# Load utility functions
. ./functions.sh

# Install and setup APT proxy configuration
if [ -z "$APT_PROXY" ] ; then
  install_readonly files/apt/10proxy "${ETC_DIR}/apt/apt.conf.d/10proxy"
  sed -i "s/\"\"/\"${APT_PROXY}\"/" "${ETC_DIR}/apt/apt.conf.d/10proxy"
fi

if [ "$BUILD_KERNEL" = false ] ; then
  if [ "$RPI_MODEL" = 2 ] ; then
  # Install APT pinning configuration for flash-kernel package
  install_readonly files/apt/flash-kernel "${ETC_DIR}/apt/preferences.d/flash-kernel"

  # Install APT sources.list
  install_readonly files/apt/sources.list "${ETC_DIR}/apt/sources.list"
  echo "deb ${COLLABORA_URL} ${RELEASE} rpi2" >> "${ETC_DIR}/apt/sources.list"

  # Upgrade collabora package index and install collabora keyring
  chroot_exec apt-get -qq -y update
  chroot_exec apt-get -qq -y --allow-unauthenticated install collabora-obs-archive-keyring
  # if RPI_MODEL = [0] || [1] || [1P]
  else
  echo "error: ATM there is just a precompiled kernel for model 2";
  # insert apt configuration for precompiled kernel repository for RPI 0,1,1P
  fi
  
else # BUILD_KERNEL=true
  #autconfigure best apt server to not spam ftp.debian.org
  rm files/apt/sources.list
  #netselect-apt does not know buster yet
  if [ "$RELEASE" = "buster" ] ; then
    RLS = "testing"
  fi
  
  if [ "$ENABLE_NONFREE" ] ; then
    netselect-apt --arch "$RELEASE_ARCH" --sources --nonfree --outfile "${ETC_DIR}/apt/sources.list" -d "$RELEASE"
  else
    netselect-apt --arch "$RELEASE_ARCH" --sources --nonfree --outfile "${ETC_DIR}/apt/sources.list" -d "$RELEASE"
  fi
fi

# Allow the installation of non-free Debian packages
if [ "$ENABLE_NONFREE" = true ] ; then
  sed -i "s/ contrib/ contrib non-free/" "${ETC_DIR}/apt/sources.list"
fi

# Upgrade package index and update all installed packages and changed dependencies
chroot_exec apt-get -qq -y update
chroot_exec apt-get -qq -y -u dist-upgrade

if [ "$APT_INCLUDES_LATE" ] ; then
  chroot_exec apt-get -qq -y install $(echo $APT_INCLUDES_LATE |tr , ' ')
fi

if [ -d packages ] ; then
  for package in packages/*.deb ; do
    cp $package ${R}/tmp
    chroot_exec dpkg --unpack /tmp/$(basename $package)
  done
fi
chroot_exec apt-get -qq -y -f install

chroot_exec apt-get -qq -y check
