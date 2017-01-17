#
# Authorize SSH keys.
#

# Add a given key file for a given user to a given home directory.
#
# Syntax:
#   authorize <user> <home-directory> <key-file>
#
authorize() {
    [ -n "${3}" ] || return 64
    echo "Authorizing SSH keys for ${1}..."
    install -D -o root -g root -m 600 "${3}" "${R}/${2}/.ssh/authorized_keys"
    chroot_exec chown -R "${1}:${1}" "/${2}/.ssh/authorized_keys"
}

##
#
# Main routine.
#
##

authorize root root "${SSH_ROOT_KEYS}"
authorize "${USER_NAME}" "home/${USER_NAME}" "${SSH_USER_KEYS}"

