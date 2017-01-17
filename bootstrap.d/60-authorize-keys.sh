#
# Authorize SSH keys.
#

if [ -n "${SSH_ROOT_KEYS}" ]
then
    echo "Authorizing SSH keys..."
    mkdir "${R}/root/.ssh/"
    install \
            -o root \
            -g root \
            -m 600 \
            "${SSH_ROOT_KEYS}" \
            "${R}/root/.ssh/authorized_keys"
fi

