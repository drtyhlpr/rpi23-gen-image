#
# Setup APT repositories
#

# Load utility functions
. ./functions.sh

# Use proxy inside chroot
if [ -z "$APT_PROXY" ] ; then
  install_readonly files/apt/10proxy $R/etc/apt/apt.conf.d/10proxy
  sed -i -e "s/\"\"/\"${APT_PROXY}\"/" $R/etc/apt/apt.conf.d/10proxy
fi

# Pin package flash-kernel to repositories.collabora.co.uk
install_readonly files/apt/flash-kernel $R/etc/apt/preferences.d/flash-kernel

# Upgrade collabora package index and install collabora keyring
echo "deb https://repositories.collabora.co.uk/debian ${RELEASE} rpi2" >$R/etc/apt/sources.list
chroot_exec apt-get -qq -y update
chroot_exec apt-get -qq -y --force-yes install collabora-obs-archive-keyring

# Set up initial sources.list
install_readonly files/apt/sources.list $R/etc/apt/sources.list
sed -i -e "s/\/ftp.debian.org\//\/${APT_SERVER}\//" $R/etc/apt/sources.list
sed -i -e "s/ jessie/ ${RELEASE}/" $R/etc/apt/sources.list

# Upgrade package index and update all installed packages and changed dependencies
chroot_exec apt-get -qq -y update
chroot_exec apt-get -qq -y -u dist-upgrade
