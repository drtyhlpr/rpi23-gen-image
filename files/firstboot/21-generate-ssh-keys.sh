logger -t "rc.firstboot" "Generating SSH host keys"

if [ -d "/etc/ssh/" ] ; then
  rm -f /etc/ssh/ssh_host_*
  systemctl stop sshd
  ssh-keygen -q -t rsa -N "" -f /etc/ssh/ssh_host_rsa_key
  ssh-keygen -q -t dsa -N "" -f /etc/ssh/ssh_host_dsa_key
  ssh-keygen -q -t ecdsa -N "" -f /etc/ssh/ssh_host_ecdsa_key
  ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
  systemctl start sshd
fi

if [ -d "/etc/dropbear/" ] ; then
  rm -f /etc/dropbear/dropbear_*
  systemctl stop dropbear
  dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
  dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
  dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
  systemctl start dropbear
fi
