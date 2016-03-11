#
# Enable firewall based on iptables started by systemd service
#

. ./functions.sh

if [ "$ENABLE_IPTABLES" = true ] ; then
  # Create iptables configuration directory
  mkdir -p "$R/etc/iptables"

  # Create iptables systemd service
  install -o root -g root -m 644 files/iptables/iptables.service $R/etc/systemd/system/iptables.service

  # Create flush-table script called by iptables service
  install -o root -g root -m 755 files/iptables/flush-iptables.sh $R/etc/iptables/flush-iptables.sh

  # Create iptables rule file
  install -o root -g root -m 644 files/iptables/iptables.rules $R/etc/iptables/iptables.rules

  # Reload systemd configuration and enable iptables service
  chroot_exec systemctl daemon-reload
  chroot_exec systemctl enable iptables.service

  if [ "$ENABLE_IPV6" = true ] ; then
    # Create ip6tables systemd service
    install -o root -g root -m 644 files/iptables/ip6tables.service $R/etc/systemd/system/ip6tables.service

    # Create ip6tables file
    install -o root -g root -m 755 files/iptables/flush-ip6tables.sh $R/etc/iptables/flush-ip6tables.sh

    install -o root -g root -m 644 files/iptables/ip6tables.rules $R/etc/iptables/ip6tables.rules

    # Reload systemd configuration and enable iptables service
    chroot_exec systemctl daemon-reload
    chroot_exec systemctl enable ip6tables.service
  fi
fi

# Remove SSHD related iptables rules
if [ "$ENABLE_SSHD" = false ] ; then
 sed -e '/^#/! {/SSH/ s/^/# /}' -i $R/etc/iptables/iptables.rules 2> /dev/null
 sed -e '/^#/! {/SSH/ s/^/# /}' -i $R/etc/iptables/ip6tables.rules 2> /dev/null
fi
