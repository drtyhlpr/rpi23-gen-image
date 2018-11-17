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
  echo "Downloading precompiled kernel"
  echo "error: not configured"
  exit 1;
# BUILD_KERNEL=true
else
  echo "No precompiled kernel repositories were added"
fi

# Upgrade package index and update all installed packages and changed dependencies
chroot_exec apt-get -qq -y update
chroot_exec apt-get -qq -y -u dist-upgrade

if [ "$APT_INCLUDES_LATE" ] ; then
  chroot_exec apt-get -qq -y install "$(echo "$APT_INCLUDES_LATE" |tr , ' ')"
fi

if [ -d packages ] ; then
  for package in packages/*.deb ; do
    cp "$package" "${R}"/tmp
    chroot_exec dpkg --unpack /tmp/"$(basename "$package")"
  done
fi
chroot_exec apt-get -qq -y -f install

chroot_exec apt-get -qq -y check
