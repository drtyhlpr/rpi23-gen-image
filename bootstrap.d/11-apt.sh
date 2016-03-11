#
# Setup APT repositories
#

. ./functions.sh

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

# Upgrade collabora package index and install collabora keyring
echo "deb https://repositories.collabora.co.uk/debian ${RELEASE} rpi2" >$R/etc/apt/sources.list
chroot_exec apt-get -qq -y update
chroot_exec apt-get -qq -y --force-yes install collabora-obs-archive-keyring

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
chroot_exec apt-get -qq -y update
chroot_exec apt-get -qq -y -u dist-upgrade
