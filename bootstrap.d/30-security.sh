#
# Setup users and security settings
#

# Load utility functions
. ./functions.sh

# Generate crypt(3) password string
ENCRYPTED_PASSWORD=`mkpasswd -m sha-512 ${PASSWORD}`

# Set up default user
if [ "$ENABLE_USER" = true ] ; then
  chroot_exec adduser --gecos pi --add_extra_groups --disabled-password pi
  chroot_exec usermod -a -G sudo -p "${ENCRYPTED_PASSWORD}" pi
fi

# Set up root password or not
if [ "$ENABLE_ROOT" = true ]; then
  chroot_exec usermod -p "${ENCRYPTED_PASSWORD}" root

  if [ "$ENABLE_ROOT_SSH" = true ]; then
    sed -i 's|[#]*PermitRootLogin.*|PermitRootLogin yes|g' $R/etc/ssh/sshd_config
  fi
else
  chroot_exec usermod -p \'!\' root
fi

# Enable serial console systemd style
if [ "$ENABLE_CONSOLE" = true ] ; then
  chroot_exec systemctl enable serial-getty\@ttyAMA0.service
fi
