#
# Setup users and security settings
#

# Load utility functions
. ./functions.sh

# Setup default user
if [ "$ENABLE_USER" = true ] ; then
  chroot_exec adduser --gecos "$USER_NAME" --add_extra_groups --disabled-password "$USER_NAME"
  chroot_exec usermod -a -G sudo "$USER_NAME"
  chroot_exec echo "'$USER_NAME:${USER_PASSWORD}' | chpasswd"
fi

# Setup root password or not
if [ "$ENABLE_ROOT" = true ] ; then
  chroot_exec echo "'root:${USER_PASSWORD}' | chpasswd"
else
  # Set no root password to disable root login
  chroot_exec usermod -L root
fi

