#
# Setup SSH settings and public keys
#

# Load utility functions
. ./functions.sh

if [ "$ENABLE_SSHD" = true ] ; then
  DROPBEAR_ARGS=""

  if [ "$SSH_ENABLE_ROOT" = false ] ; then
    if [ "$ENABLE_REDUCE" = false ] || [ "$REDUCE_SSHD" = false ] ; then
      # User root is not allowed to log in
      sed -i "s|[#]*PermitRootLogin.*|PermitRootLogin no|g" "${ETC_DIR}/ssh/sshd_config"
    else
      # User root is not allowed to log in
      DROPBEAR_ARGS="-w"
    fi
  fi

  if [ "$ENABLE_ROOT" = true ] && [ "$SSH_ENABLE_ROOT" = true ] ; then
    if [ "$ENABLE_REDUCE" = false ] || [ "$REDUCE_SSHD" = false ] ; then
      # Permit SSH root login
      sed -i "s|[#]*PermitRootLogin.*|PermitRootLogin yes|g" "${ETC_DIR}/ssh/sshd_config"
    else
      # Permit SSH root login
      DROPBEAR_ARGS=""
    fi

    # Add SSH (v2) public key for user root
    if [ ! -z "$SSH_ROOT_PUB_KEY" ] ; then
      # Create root SSH config directory
      mkdir -p "${R}/root/.ssh"

      # Set permissions of root SSH config directory
      chroot_exec chmod 700 "/root/.ssh"
      chroot_exec chown root:root "/root/.ssh"

      # Add SSH (v2) public key(s) to authorized_keys file
      cat "$SSH_ROOT_PUB_KEY" >> "${R}/root/.ssh/authorized_keys"

      # Set permissions of root SSH authorized_keys file
      chroot_exec chmod 600 "/root/.ssh/authorized_keys"
      chroot_exec chown root:root "/root/.ssh/authorized_keys"

      if [ "$ENABLE_REDUCE" = false ] || [ "$REDUCE_SSHD" = false ] ; then
        # Allow SSH public key authentication
        sed -i "s|[#]*PubkeyAuthentication.*|PubkeyAuthentication yes|g" "${ETC_DIR}/ssh/sshd_config"
      fi
    fi
  fi

  if [ "$ENABLE_USER" = true ] ; then
    # Add SSH (v2) public key for user $USER_NAME
    if [ ! -z "$SSH_USER_PUB_KEY" ] ; then
      # Create $USER_NAME SSH config directory
      mkdir -p "${R}/home/${USER_NAME}/.ssh"

      # Set permissions of $USER_NAME SSH config directory
      chroot_exec chmod 700 "/home/${USER_NAME}/.ssh"
      chroot_exec chown ${USER_NAME}:${USER_NAME} "/home/${USER_NAME}/.ssh"

      # Add SSH (v2) public key(s) to authorized_keys file
      cat "$SSH_USER_PUB_KEY" >> "${R}/home/${USER_NAME}/.ssh/authorized_keys"

      # Set permissions of $USER_NAME SSH config directory
      chroot_exec chmod 600 "/home/${USER_NAME}/.ssh/authorized_keys"
      chroot_exec chown ${USER_NAME}:${USER_NAME} "/home/${USER_NAME}/.ssh/authorized_keys"

      if [ "$ENABLE_REDUCE" = false ] || [ "$REDUCE_SSHD" = false ] ; then
        # Allow SSH public key authentication
        sed -i "s|[#]*PubkeyAuthentication.*|PubkeyAuthentication yes|g" "${ETC_DIR}/ssh/sshd_config"
      fi
    fi
  fi

  # Limit the users that are allowed to login via SSH
  if [ "$SSH_LIMIT_USERS" = true ] && [ "$ENABLE_REDUCE" = false ] ; then
    allowed_users=""
    if [ "$ENABLE_ROOT" = true ] && [ "$SSH_ENABLE_ROOT" = true ] ; then
      allowed_users="root"
    fi

    if [ "$ENABLE_USER" = true ] ; then
      allowed_users="${allowed_users} ${USER_NAME}"
    fi

    if [ ! -z "$allowed_users" ] ; then
      echo "AllowUsers ${allowed_users}" >> "${ETC_DIR}/ssh/sshd_config"
    fi
  fi

  # Disable password-based authentication
  if [ "$SSH_DISABLE_PASSWORD_AUTH" = true ] ; then
    if [ "$ENABLE_ROOT" = true ] && [ "$SSH_ENABLE_ROOT" = true ] ; then
      if [ "$ENABLE_REDUCE" = false ] || [ "$REDUCE_SSHD" = false ] ; then
        sed -i "s|[#]*PermitRootLogin.*|PermitRootLogin without-password|g" "${ETC_DIR}/ssh/sshd_config"
      else
        DROPBEAR_ARGS="-g"
      fi
    fi

    if [ "$ENABLE_REDUCE" = false ] || [ "$REDUCE_SSHD" = false ] ; then
      sed -i "s|[#]*PasswordAuthentication.*|PasswordAuthentication no|g" "${ETC_DIR}/ssh/sshd_config"
      sed -i "s|[#]*ChallengeResponseAuthentication no.*|ChallengeResponseAuthentication no|g" "${ETC_DIR}/ssh/sshd_config"
      sed -i "s|[#]*UsePAM.*|UsePAM no|g" "${ETC_DIR}/ssh/sshd_config"
    else
      DROPBEAR_ARGS="${DROPBEAR_ARGS} -s"
    fi
  fi

  # Update dropbear SSH configuration
  if [ "$ENABLE_REDUCE" = true ] && [ "$REDUCE_SSHD" = true ] ; then
    sed "s|^DROPBEAR_EXTRA_ARGS=.*|DROPBEAR_EXTRA_ARGS=\"${DROPBEAR_ARGS}\"|g" "${ETC_DIR}/default/dropbear"
  fi
fi
