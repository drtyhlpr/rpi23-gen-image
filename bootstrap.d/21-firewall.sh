#
# Setup Firewall
#

# Load utility functions
. ./functions.sh

if [ "$ENABLE_IPTABLES" = true ] ; then
  # Create iptables configuration directory
  mkdir -p "${ETC_DIR}/iptables"
  
  if [ "$KERNEL_NF" = false ] ; then
    # iptables-save and -restore are slaves of iptables and thus are set accordingly
    chroot_exec update-alternatives --verbose --set iptables /usr/sbin/iptables-legacy    
  fi
  
  # Install iptables systemd service
  install_readonly files/iptables/iptables.service "${ETC_DIR}/systemd/system/iptables.service"

  # Install flush-table script called by iptables service
  install_exec files/iptables/flush-iptables.sh "${ETC_DIR}/iptables/flush-iptables.sh"

  # Install iptables rule file
  install_readonly files/iptables/iptables.rules "${ETC_DIR}/iptables/iptables.rules"

  # Reload systemd configuration and enable iptables service
  chroot_exec systemctl daemon-reload
  chroot_exec systemctl enable iptables.service

  if [ "$ENABLE_IPV6" = true ] ; then
    if [ "$KERNEL_NF" = false ] ; then
      # iptables-save and -restore are slaves of iptables and thus are set accordingly
      chroot_exec update-alternatives --verbose --set ip6tables /usr/sbin/ip6tables-legacy 
	fi

    # Install ip6tables systemd service
    install_readonly files/iptables/ip6tables.service "${ETC_DIR}/systemd/system/ip6tables.service"

    # Install ip6tables file
    install_exec files/iptables/flush-ip6tables.sh "${ETC_DIR}/iptables/flush-ip6tables.sh"

    install_readonly files/iptables/ip6tables.rules "${ETC_DIR}/iptables/ip6tables.rules"

    # Reload systemd configuration and enable iptables service
    chroot_exec systemctl daemon-reload
    chroot_exec systemctl enable ip6tables.service
  fi
  
  if [ "$SSH_ENABLE" = false ] ; then
   # Remove SSHD related iptables rules
   sed -i "/^#/! {/SSH/ s/^/# /}" "${ETC_DIR}/iptables/iptables.rules" 2> /dev/null
   sed -i "/^#/! {/SSH/ s/^/# /}" "${ETC_DIR}/iptables/ip6tables.rules" 2> /dev/null
  fi
fi
