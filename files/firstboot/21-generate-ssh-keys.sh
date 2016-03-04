logger -t "rc.firstboot" "Generating SSH host keys"
rm -f /etc/ssh/ssh_host_*
ssh-keygen -q -t rsa -N "" -f /etc/ssh/ssh_host_rsa_key
ssh-keygen -q -t dsa -N "" -f /etc/ssh/ssh_host_dsa_key
ssh-keygen -q -t ecdsa -N "" -f /etc/ssh/ssh_host_ecdsa_key
ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key

systemctl restart sshd
