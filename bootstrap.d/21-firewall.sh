#
# Setup Firewall
#

# Load utility functions
. ./functions.sh

if [ "$ENABLE_IPTABLES" = true ] ; then
  # Create iptables configuration directory
  mkdir -p "$R/etc/iptables"

  # Create iptables systemd service
  install_readonly files/iptables/iptables.service $R/etc/systemd/system/iptables.service

  # Create flush-table script called by iptables service
  install_exec files/iptables/flush-iptables.sh $R/etc/iptables/flush-iptables.sh

  # Create iptables rule file
  install_readonly files/iptables/iptables.rules $R/etc/iptables/iptables.rules

  # Reload systemd configuration and enable iptables service
  chroot_exec systemctl daemon-reload
  chroot_exec systemctl enable iptables.service

  if [ "$ENABLE_IPV6" = true ] ; then
    # Create ip6tables systemd service
    install_readonly files/iptables/ip6tables.service $R/etc/systemd/system/ip6tables.service

    # Create ip6tables file
    install_exec files/iptables/flush-ip6tables.sh $R/etc/iptables/flush-ip6tables.sh

    install_readonly files/iptables/ip6tables.rules $R/etc/iptables/ip6tables.rules

    # Reload systemd configuration and enable iptables service
    chroot_exec systemctl daemon-reload
    chroot_exec systemctl enable ip6tables.service
  fi
fi

if [ "$ENABLE_SSHD" = false ] ; then
 # Remove SSHD related iptables rules
 sed -i "/^#/! {/SSH/ s/^/# /}" $R/etc/iptables/iptables.rules 2> /dev/null
 sed -i "/^#/! {/SSH/ s/^/# /}" $R/etc/iptables/ip6tables.rules 2> /dev/null
fi
