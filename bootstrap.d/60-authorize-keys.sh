. ./functions.sh

#
# Authorize the same SSH users, that are authorized to use the build system.
#
# This script will authorize the SSH-keys authorized for the current user of the 
# build server, for the root account in the image, if AUTHORIZE_SSH_KEYS is set.
#

if [ "${AUTHORIZE_SSH_KEYS}" = true ]
then
    echo "Authorizing SSH keys..."
    mkdir "${R}/root/.ssh/"
    install \
            -o root \
            -g root \
            -m 600 \
            ~/.ssh/authorized_keys \
            "${R}/root/.ssh/authorized_keys"
fi

