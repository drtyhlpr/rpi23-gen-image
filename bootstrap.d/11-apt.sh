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
  # Install APT pinning configuration for flash-kernel package
  install_readonly files/apt/flash-kernel "${ETC_DIR}/apt/preferences.d/flash-kernel"

  # Install APT sources.list
  install_readonly files/apt/sources.list "${ETC_DIR}/apt/sources.list"
  echo "deb ${COLLABORA_URL} ${RELEASE} rpi2" >> "${ETC_DIR}/apt/sources.list"

  # Upgrade collabora package index and install collabora keyring
  chroot_exec apt-get -qq -y update
  chroot_exec apt-get -qq -y --allow-unauthenticated install collabora-obs-archive-keyring
else # BUILD_KERNEL=true
  # Install APT sources.list
  install_readonly files/apt/sources.list "${ETC_DIR}/apt/sources.list"

  # Use specified APT server and release
  sed -i "s/\/ftp.debian.org\//\/${APT_SERVER}\//" "${ETC_DIR}/apt/sources.list"
  sed -i "s/ jessie/ ${RELEASE}/" "${ETC_DIR}/apt/sources.list"
fi

# Allow the installation of non-free Debian packages
if [ "$ENABLE_NONFREE" = true ] ; then
  sed -i "s/ contrib/ contrib non-free/" "${ETC_DIR}/apt/sources.list"
fi

# Upgrade package index and update all installed packages and changed dependencies
chroot_exec apt-get -qq -y update
chroot_exec apt-get -qq -y --allow-unauthenticated -u dist-upgrade

if [ -d packages ] ; then
  for package in packages/*.deb ; do
    cp $package ${R}/tmp
    chroot_exec dpkg --unpack /tmp/$(basename $package)
  done
fi
chroot_exec apt-get -qq -y -f install

chroot_exec apt-get -qq -y check
