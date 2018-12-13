#
# Build and Setup RPi2/3 Kernel
#

# Load utility functions
. ./functions.sh

# Need to use kali kernel src if nexmon is enabled
if [ "$ENABLE_NEXMON" = true ] ; then
  KERNEL_URL="${KALI_KERNEL_URL}"
  # Clear Branch and KernelSRC_DIR if using nexmon. Everyone will forget to clone kali kernel instead of nomrla kernel
  KERNEL_BRANCH=""
  KERNELSRC_DIR=""
fi

# Fetch and build latest raspberry kernel
if [ "$BUILD_KERNEL" = true ] ; then
  # Setup source directory
  mkdir -p "${KERNEL_DIR}"

  # Copy existing kernel sources into chroot directory
  if [ -n "$KERNELSRC_DIR" ] && [ -d "$KERNELSRC_DIR" ] ; then
    # Copy kernel sources and include hidden files
    cp -r "${KERNELSRC_DIR}/". "${KERNEL_DIR}"

    # Clean the kernel sources
    if [ "$KERNELSRC_CLEAN" = true ] && [ "$KERNELSRC_PREBUILT" = false ] ; then
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" mrproper
    fi
  else # KERNELSRC_DIR=""
    # Create temporary directory for kernel sources
    temp_dir=$(as_nobody mktemp -d)

    # Fetch current RPi2/3 kernel sources
    if [ -z "${KERNEL_BRANCH}" ] ; then
      as_nobody -H git -C "${temp_dir}" clone --depth=1 "${KERNEL_URL}" linux
    else
      as_nobody -H git -C "${temp_dir}" clone --depth=1 --branch "${KERNEL_BRANCH}" "${KERNEL_URL}" linux
    fi

    # Copy downloaded kernel sources
    cp -r "${temp_dir}/linux/"* "${KERNEL_DIR}"

    # Remove temporary directory for kernel sources
    rm -fr "${temp_dir}"

    # Set permissions of the kernel sources
    chown -R root:root "${R}/usr/src"
  fi

  # Calculate optimal number of kernel building threads
  if [ "$KERNEL_THREADS" = "1" ] && [ -r /proc/cpuinfo ] ; then
    KERNEL_THREADS=$(grep -c processor /proc/cpuinfo)
  fi

  # Configure and build kernel
  if [ "$KERNELSRC_PREBUILT" = false ] ; then
    # Remove device, network and filesystem drivers from kernel configuration
    if [ "$KERNEL_REDUCE" = true ] ; then
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" "${KERNEL_DEFCONFIG}"
      sed -i\
      -e "s/\(^CONFIG_SND.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_SOUND.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_AC97.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_VIDEO_.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_MEDIA_TUNER.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_DVB.*\=\)[ym]/\1n/"\
      -e "s/\(^CONFIG_REISERFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_JFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_XFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_GFS2.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_OCFS2.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_BTRFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_HFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_JFFS2.*\=\)[ym]/\1n/"\
      -e "s/\(^CONFIG_UBIFS.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_SQUASHFS.*\=\)[ym]/\1n/"\
      -e "s/\(^CONFIG_W1.*\=\)[ym]/\1n/"\
      -e "s/\(^CONFIG_HAMRADIO.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_CAN.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_IRDA.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_BT_.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_WIMAX.*\=\)[ym]/\1n/"\
      -e "s/\(^CONFIG_6LOWPAN.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_IEEE802154.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_NFC.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_FB_TFT=.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_TOUCHSCREEN.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_USB_GSPCA_.*\=\).*/\1n/"\
      -e "s/\(^CONFIG_DRM.*\=\).*/\1n/"\
      "${KERNEL_DIR}/.config"
    fi

    if [ "$KERNELSRC_CONFIG" = true ] ; then
      # Load default raspberry kernel configuration
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" "${KERNEL_DEFCONFIG}"

      #Switch to KERNELSRC_DIR so we can use set_kernel_config
      cd "${KERNEL_DIR}" || exit
	  
	  #Fix SD_DRIVER f* up in Raspberry PI upstream kernel 
	  # use correct driver MMC_BCM2835_MMC instead of MMC_BCM2835_SDHOST - variable naming is bs
	  set_kernel_config CONFIG_MMC_BCM2835 n
	  set_kernel_config CONFIG_MMC_SDHCI_IPROC n
	  set_kernel_config CONFIG_USB_DWC2 n
	  sed -i "s|depends on MMC_BCM2835_MMC && MMC_BCM2835_DMA|depends on MMC_BCM2835_MMC|" "${KERNEL_DIR}"/drivers/mmc/host/Kconfig

	  # enable ZSWAP see https://askubuntu.com/a/472227 or https://wiki.archlinux.org/index.php/zswap
      if [ "$KERNEL_ZSWAP" = true ] ; then
        set_kernel_config CONFIG_ZPOOL y
        set_kernel_config CONFIG_ZSWAP y
        set_kernel_config CONFIG_ZBUD y
        set_kernel_config CONFIG_Z3FOLD y
        set_kernel_config CONFIG_ZSMALLOC y
        set_kernel_config CONFIG_PGTABLE_MAPPING y
		set_kernel_config CONFIG_LZO_COMPRESS y

	  fi

      # enable basic KVM support; see https://www.raspberrypi.org/forums/viewtopic.php?f=63&t=210546&start=25#p1300453
	  if [ "$KERNEL_VIRT" = true ] && { [ "$RPI_MODEL" = 2 ] || [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 3P ] ; } ; then
		set_kernel_config CONFIG_HAVE_KVM_IRQCHIP y
        set_kernel_config CONFIG_HAVE_KVM_ARCH_TLB_FLUSH_ALL y
        set_kernel_config CONFIG_HAVE_KVM_CPU_RELAX_INTERCEPT y
        set_kernel_config CONFIG_HAVE_KVM_EVENTFD y
        set_kernel_config CONFIG_HAVE_KVM_IRQFD y
        set_kernel_config CONFIG_HAVE_KVM_IRQ_ROUTING y
        set_kernel_config CONFIG_HAVE_KVM_MSI y
        set_kernel_config CONFIG_KVM y
        set_kernel_config CONFIG_KVM_ARM_HOST y
        set_kernel_config CONFIG_KVM_ARM_PMU y
        set_kernel_config CONFIG_KVM_COMPAT y
        set_kernel_config CONFIG_KVM_GENERIC_DIRTYLOG_READ_PROTECT y
        set_kernel_config CONFIG_KVM_MMIO y
        set_kernel_config CONFIG_KVM_VFIO y
        set_kernel_config CONFIG_VHOST m
        set_kernel_config CONFIG_VHOST_CROSS_ENDIAN_LEGACY y
        set_kernel_config CONFIG_VHOST_NET m
        set_kernel_config CONFIG_VIRTUALIZATION y
		
		set_kernel_config CONFIG_MMU_NOTIFIER y
		
		# erratum
		set_kernel_config ARM64_ERRATUM_834220 y
		
		# https://sourceforge.net/p/kvm/mailman/message/18440797/
		set_kernel_config CONFIG_PREEMPT_NOTIFIERS y
	  fi

      # enable apparmor,integrity audit,
	  if [ "$KERNEL_SECURITY" = true ] ; then

        # security filesystem, security models and audit
        set_kernel_config CONFIG_SECURITYFS y
        set_kernel_config CONFIG_SECURITY y
        set_kernel_config CONFIG_AUDIT y

        # harden strcpy and memcpy
        set_kernel_config CONFIG_HARDENED_USERCOPY y
        set_kernel_config CONFIG_HAVE_HARDENED_USERCOPY_ALLOCATOR y
        set_kernel_config CONFIG_FORTIFY_SOURCE y

        # integrity sub-system
        set_kernel_config CONFIG_INTEGRITY y
        set_kernel_config CONFIG_INTEGRITY_ASYMMETRIC_KEYS y
        set_kernel_config CONFIG_INTEGRITY_AUDIT y
        set_kernel_config CONFIG_INTEGRITY_SIGNATURE y
        set_kernel_config CONFIG_INTEGRITY_TRUSTED_KEYRING y
		set_kernel_config CONFIG_SYSTEM_TRUSTED_KEYS ""

        # This option provides support for retaining authentication tokens and access keys in the kernel.
        set_kernel_config CONFIG_KEYS=y
        set_kernel_config CONFIG_KEYS_COMPAT=y

        # Apparmor
        set_kernel_config CONFIG_SECURITY_APPARMOR_BOOTPARAM_VALUE 0
        set_kernel_config CONFIG_SECURITY_APPARMOR_HASH_DEFAULT y
        set_kernel_config CONFIG_DEFAULT_SECURITY_APPARMOR y
        set_kernel_config CONFIG_SECURITY_APPARMOR y
        set_kernel_config CONFIG_SECURITY_APPARMOR_HASH y
        set_kernel_config CONFIG_DEFAULT_SECURITY "apparmor"

        # restrictions on unprivileged users reading the kernel
        set_kernel_config CONFIG_SECURITY_DMESG_RESTRICT=y

        # network security hooks
        set_kernel_config CONFIG_SECURITY_NETWORK y
        set_kernel_config CONFIG_SECURITY_NETWORK_XFRM=y
        set_kernel_config CONFIG_SECURITY_PATH=y
        set_kernel_config CONFIG_SECURITY_YAMA=y

        # New Options
        if [ "$KERNEL_NF" = true ] ; then
          set_kernel_config CONFIG_IP_NF_SECURITY m
          set_kernel_config CONFIG_NETLABEL y
          set_kernel_config CONFIG_IP6_NF_SECURITY m
        fi
        set_kernel_config CONFIG_SECURITY_SELINUX n
        set_kernel_config CONFIG_SECURITY_SMACK n
        set_kernel_config CONFIG_SECURITY_TOMOYO n
        set_kernel_config CONFIG_SECURITY_APPARMOR_DEBUG n
        set_kernel_config CONFIG_SECURITY_LOADPIN n
        set_kernel_config CONFIG_HARDENED_USERCOPY_PAGESPAN n
        set_kernel_config CONFIG_IMA n
        set_kernel_config CONFIG_EVM n
        set_kernel_config CONFIG_FANOTIFY_ACCESS_PERMISSIONS y
        set_kernel_config CONFIG_NFSD_V4_SECURITY_LABEL y
        set_kernel_config CONFIG_PKCS7_MESSAGE_PARSER y
        set_kernel_config CONFIG_SYSTEM_TRUSTED_KEYRING y
        set_kernel_config CONFIG_SYSTEM_TRUSTED_KEYS y
        set_kernel_config CONFIG_SYSTEM_EXTRA_CERTIFICATE y
        set_kernel_config CONFIG_SECONDARY_TRUSTED_KEYRING y
        set_kernel_config CONFIG_IMA_KEYRINGS_PERMIT_SIGNED_BY_BUILTIN_OR_SECONDARY n
		set_kernel_config CONFIG_SYSTEM_TRUSTED_KEYS m
		set_kernel_config CONFIG_SYSTEM_EXTRA_CERTIFICATE_SIZE 4096

        set_kernel_config CONFIG_ARM64_CRYPTO y
        set_kernel_config CONFIG_CRYPTO_SHA256_ARM64 m
        set_kernel_config CONFIG_CRYPTO_SHA512_ARM64 m
        set_kernel_config CONFIG_CRYPTO_SHA1_ARM64_CE m
        set_kernel_config CRYPTO_GHASH_ARM64_CE m
        set_kernel_config CRYPTO_SHA2_ARM64_CE m
        set_kernel_config CONFIG_CRYPTO_CRCT10DIF_ARM64_CE m
        set_kernel_config CONFIG_CRYPTO_CRC32_ARM64_CE m
        set_kernel_config CONFIG_CRYPTO_AES_ARM64 m
        set_kernel_config CONFIG_CRYPTO_AES_ARM64_CE m
        set_kernel_config CONFIG_CRYPTO_AES_ARM64_CE_CCM y
        set_kernel_config CONFIG_CRYPTO_AES_ARM64_CE_BLK y
        set_kernel_config CONFIG_CRYPTO_AES_ARM64_NEON_BLK m
        set_kernel_config CONFIG_CRYPTO_CHACHA20_NEON m
        set_kernel_config CONFIG_CRYPTO_AES_ARM64_BS m
		echo SYSTEM_TRUSTED_KEYS >> .config
      fi

      # Netfilter kernel support See https://github.com/raspberrypi/linux/issues/2177#issuecomment-354647406
      if [ "$KERNEL_NF" = true ] ; then
        set_kernel_config CONFIG_IP_NF_TARGET_SYNPROXY m
        set_kernel_config CONFIG_NETFILTER_XT_TARGET_AUDIT m
        set_kernel_config CONFIG_NETFILTER_XT_MATCH_CGROUP m
        set_kernel_config CONFIG_NETFILTER_XT_MATCH_IPCOMP m
        set_kernel_config CONFIG_NETFILTER_XT_MATCH_SOCKET m
        set_kernel_config CONFIG_NFT_FIB_INET m
        set_kernel_config CONFIG_NFT_FIB_IPV4 m
        set_kernel_config CONFIG_NFT_FIB_IPV6 m
        set_kernel_config CONFIG_NFT_FIB_NETDEV m
        set_kernel_config CONFIG_NFT_OBJREF m
        set_kernel_config CONFIG_NFT_RT m
        set_kernel_config CONFIG_NFT_SET_BITMAP m
        set_kernel_config CONFIG_NF_CONNTRACK_TIMEOUT y
        set_kernel_config CONFIG_NF_LOG_ARP m
        set_kernel_config CONFIG_NF_SOCKET_IPV4 m
        set_kernel_config CONFIG_NF_SOCKET_IPV6 m
        set_kernel_config CONFIG_BRIDGE_EBT_BROUTE m
        set_kernel_config CONFIG_BRIDGE_EBT_T_FILTER m
        set_kernel_config CONFIG_BRIDGE_NF_EBTABLES m
        set_kernel_config CONFIG_IP6_NF_IPTABLES m
        set_kernel_config CONFIG_IP6_NF_MATCH_AH m
        set_kernel_config CONFIG_IP6_NF_MATCH_EUI64 m
        set_kernel_config CONFIG_IP6_NF_NAT m
        set_kernel_config CONFIG_IP6_NF_TARGET_MASQUERADE m
        set_kernel_config CONFIG_IP6_NF_TARGET_NPT m
        set_kernel_config CONFIG_IP_NF_SECURITY m
        set_kernel_config CONFIG_IP_SET_BITMAP_IPMAC m
        set_kernel_config CONFIG_IP_SET_BITMAP_PORT m
        set_kernel_config CONFIG_IP_SET_HASH_IP m
        set_kernel_config CONFIG_IP_SET_HASH_IPMARK m
        set_kernel_config CONFIG_IP_SET_HASH_IPPORT m
        set_kernel_config CONFIG_IP_SET_HASH_IPPORTIP m
        set_kernel_config CONFIG_IP_SET_HASH_IPPORTNET m
        set_kernel_config CONFIG_IP_SET_HASH_MAC m
        set_kernel_config CONFIG_IP_SET_HASH_NET m
        set_kernel_config CONFIG_IP_SET_HASH_NETIFACE m
        set_kernel_config CONFIG_IP_SET_HASH_NETNET m
        set_kernel_config CONFIG_IP_SET_HASH_NETPORT m
        set_kernel_config CONFIG_IP_SET_HASH_NETPORTNET m
        set_kernel_config CONFIG_IP_SET_LIST_SET m
        set_kernel_config CONFIG_NETFILTER_XTABLES m
        set_kernel_config CONFIG_NETFILTER_XTABLES m
        set_kernel_config CONFIG_NFT_BRIDGE_META m
        set_kernel_config CONFIG_NFT_BRIDGE_REJECT m
        set_kernel_config CONFIG_NFT_CHAIN_NAT_IPV4 m
        set_kernel_config CONFIG_NFT_CHAIN_NAT_IPV6 m
        set_kernel_config CONFIG_NFT_CHAIN_ROUTE_IPV4 m
        set_kernel_config CONFIG_NFT_CHAIN_ROUTE_IPV6 m
        set_kernel_config CONFIG_NFT_COMPAT m
        set_kernel_config CONFIG_NFT_COUNTER m
        set_kernel_config CONFIG_NFT_CT m
        set_kernel_config CONFIG_NFT_DUP_IPV4 m
        set_kernel_config CONFIG_NFT_DUP_IPV6 m
        set_kernel_config CONFIG_NFT_DUP_NETDEV m
        set_kernel_config CONFIG_NFT_EXTHDR m
        set_kernel_config CONFIG_NFT_FWD_NETDEV m
        set_kernel_config CONFIG_NFT_HASH m
        set_kernel_config CONFIG_NFT_LIMIT m
        set_kernel_config CONFIG_NFT_LOG m
        set_kernel_config CONFIG_NFT_MASQ m
        set_kernel_config CONFIG_NFT_MASQ_IPV4 m
        set_kernel_config CONFIG_NFT_MASQ_IPV6 m
        set_kernel_config CONFIG_NFT_META m
        set_kernel_config CONFIG_NFT_NAT m
        set_kernel_config CONFIG_NFT_NUMGEN m
        set_kernel_config CONFIG_NFT_QUEUE m
        set_kernel_config CONFIG_NFT_QUOTA m
        set_kernel_config CONFIG_NFT_REDIR m
        set_kernel_config CONFIG_NFT_REDIR_IPV4 m
        set_kernel_config CONFIG_NFT_REDIR_IPV6 m
        set_kernel_config CONFIG_NFT_REJECT m
        set_kernel_config CONFIG_NFT_REJECT_INET m
        set_kernel_config CONFIG_NFT_REJECT_IPV4 m
        set_kernel_config CONFIG_NFT_REJECT_IPV6 m
        set_kernel_config CONFIG_NFT_SET_HASH m
        set_kernel_config CONFIG_NFT_SET_RBTREE m
        set_kernel_config CONFIG_NF_CONNTRACK_IPV4 m
        set_kernel_config CONFIG_NF_CONNTRACK_IPV6 m
        set_kernel_config CONFIG_NF_DEFRAG_IPV4 m
        set_kernel_config CONFIG_NF_DEFRAG_IPV6 m
        set_kernel_config CONFIG_NF_DUP_IPV4 m
        set_kernel_config CONFIG_NF_DUP_IPV6 m
        set_kernel_config CONFIG_NF_DUP_NETDEV m
        set_kernel_config CONFIG_NF_LOG_BRIDGE m
        set_kernel_config CONFIG_NF_LOG_IPV4 m
        set_kernel_config CONFIG_NF_LOG_IPV6 m
        set_kernel_config CONFIG_NF_NAT_IPV4 m
        set_kernel_config CONFIG_NF_NAT_IPV6 m
        set_kernel_config CONFIG_NF_NAT_MASQUERADE_IPV4 m
        set_kernel_config CONFIG_NF_NAT_MASQUERADE_IPV6 m
        set_kernel_config CONFIG_NF_NAT_PPTP m
        set_kernel_config CONFIG_NF_NAT_PROTO_GRE m
        set_kernel_config CONFIG_NF_NAT_REDIRECT m
        set_kernel_config CONFIG_NF_NAT_SIP m
        set_kernel_config CONFIG_NF_NAT_SNMP_BASIC m
        set_kernel_config CONFIG_NF_NAT_TFTP m
        set_kernel_config CONFIG_NF_REJECT_IPV4 m
        set_kernel_config CONFIG_NF_REJECT_IPV6 m
        set_kernel_config CONFIG_NF_TABLES m
        set_kernel_config CONFIG_NF_TABLES_ARP m
        set_kernel_config CONFIG_NF_TABLES_BRIDGE m
        set_kernel_config CONFIG_NF_TABLES_INET m
        set_kernel_config CONFIG_NF_TABLES_IPV4 m
        set_kernel_config CONFIG_NF_TABLES_IPV6 m
        set_kernel_config CONFIG_NF_TABLES_NETDEV m
      fi

	  # Enables BPF syscall for systemd-journald see https://github.com/torvalds/linux/blob/master/init/Kconfig#L848 or https://groups.google.com/forum/#!topic/linux.gentoo.user/_2aSc_ztGpA
	  if [ "$KERNEL_BPF" = true ] ; then
        set_kernel_config CONFIG_BPF_SYSCALL y
		set_kernel_config CONFIG_BPF_EVENTS y
		set_kernel_config CONFIG_BPF_STREAM_PARSER y
	    set_kernel_config CONFIG_CGROUP_BPF y
	  fi

	  # KERNEL_DEFAULT_GOV was set by user 
	  if [ "$KERNEL_DEFAULT_GOV" != powersave ] && [ -n "$KERNEL_DEFAULT_GOV" ] ; then

	    case "$KERNEL_DEFAULT_GOV" in
          performance)
	        set_kernel_config CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE y
            ;;
          userspace)
            set_kernel_config CONFIG_CPU_FREQ_DEFAULT_GOV_USERSPACE y
            ;;
          ondemand)
		    set_kernel_config CONFIG_CPU_FREQ_DEFAULT_GOV_ONDEMAND y
            ;;
          conservative)
		    set_kernel_config CONFIG_CPU_FREQ_DEFAULT_GOV_CONSERVATIVE y
		    ;;
          shedutil)
		    set_kernel_config CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL y
            ;;
          *)
            echo "error: unsupported default cpu governor"
            exit 1
            ;;
        esac

            # unset previous default governor
	    unset_kernel_config CONFIG_CPU_FREQ_DEFAULT_GOV_POWERSAVE
	  fi

	  #Revert to previous directory
	  cd "${WORKDIR}" || exit

      # Set kernel configuration parameters to enable qemu emulation
      if [ "$ENABLE_QEMU" = true ] ; then
        echo "CONFIG_FHANDLE=y" >> "${KERNEL_DIR}"/.config
        echo "CONFIG_LBDAF=y" >> "${KERNEL_DIR}"/.config

        if [ "$ENABLE_CRYPTFS" = true ] ; then
          {
            echo "CONFIG_EMBEDDED=y"
            echo "CONFIG_EXPERT=y"
            echo "CONFIG_DAX=y"
            echo "CONFIG_MD=y"
            echo "CONFIG_BLK_DEV_MD=y"
            echo "CONFIG_MD_AUTODETECT=y"
            echo "CONFIG_BLK_DEV_DM=y"
            echo "CONFIG_BLK_DEV_DM_BUILTIN=y"
            echo "CONFIG_DM_CRYPT=y"
            echo "CONFIG_CRYPTO_BLKCIPHER=y"
            echo "CONFIG_CRYPTO_CBC=y"
            echo "CONFIG_CRYPTO_XTS=y"
            echo "CONFIG_CRYPTO_SHA512=y"
            echo "CONFIG_CRYPTO_MANAGER=y"
          } >> "${KERNEL_DIR}"/.config
        fi
      fi

      # Copy custom kernel configuration file
      if [ -n "$KERNELSRC_USRCONFIG" ] ; then
        cp "$KERNELSRC_USRCONFIG" "${KERNEL_DIR}"/.config
      fi

      # Set kernel configuration parameters to their default values
      if [ "$KERNEL_OLDDEFCONFIG" = true ] ; then
        make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
      fi

      # Start menu-driven kernel configuration (interactive)
      if [ "$KERNEL_MENUCONFIG" = true ] ; then
        make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" menuconfig
      fi
	# end if "$KERNELSRC_CONFIG" = true
    fi

    # Use ccache to cross compile the kernel
    if [ "$KERNEL_CCACHE" = true ] ; then
      cc="ccache ${CROSS_COMPILE}gcc"
    else
      cc="${CROSS_COMPILE}gcc"
    fi

    # Cross compile kernel and dtbs
    make -C "${KERNEL_DIR}" -j"${KERNEL_THREADS}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="${cc}" "${KERNEL_BIN_IMAGE}" dtbs

    # Cross compile kernel modules
    if grep -q "CONFIG_MODULES=y" "${KERNEL_DIR}/.config" ; then
      make -C "${KERNEL_DIR}" -j"${KERNEL_THREADS}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="${cc}" modules
    fi
  # end if "$KERNELSRC_PREBUILT" = false
  fi

  # Check if kernel compilation was successful
  if [ ! -r "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/${KERNEL_BIN_IMAGE}" ] ; then
    echo "error: kernel compilation failed! (kernel image not found)"
    cleanup
    exit 1
  fi

  # Install kernel modules
  if [ "$ENABLE_REDUCE" = true ] ; then
    if grep -q "CONFIG_MODULES=y" "${KERNEL_DIR}/.config" ; then
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=../../.. modules_install
    fi
  else
    if grep -q "CONFIG_MODULES=y" "${KERNEL_DIR}/.config" ; then
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH=../../.. modules_install
    fi

    # Install kernel firmware
    if grep -q "^firmware_install:" "${KERNEL_DIR}/Makefile" ; then
      make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_FW_PATH=../../../lib firmware_install
    fi
  fi

  # Install kernel headers
  if [ "$KERNEL_HEADERS" = true ] && [ "$KERNEL_REDUCE" = false ] ; then
    make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_HDR_PATH=../.. headers_install
  fi

  # Prepare boot (firmware) directory
  mkdir "${BOOT_DIR}"

  # Get kernel release version
  KERNEL_VERSION=$(cat "${KERNEL_DIR}/include/config/kernel.release")

  # Copy kernel configuration file to the boot directory
  install_readonly "${KERNEL_DIR}/.config" "${R}/boot/config-${KERNEL_VERSION}"

  # Prepare device tree directory
  mkdir "${BOOT_DIR}/overlays"

  # Ensure the proper .dtb is located
  if [ "$KERNEL_ARCH" = "arm" ] ; then
    for dtb in "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/"*.dtb ; do
      if [ -f "${dtb}" ] ; then
        install_readonly "${dtb}" "${BOOT_DIR}/"
      fi
    done
  else
    for dtb in "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/broadcom/"*.dtb ; do
      if [ -f "${dtb}" ] ; then
        install_readonly "${dtb}" "${BOOT_DIR}/"
      fi
    done
  fi

  # Copy compiled dtb device tree files
  if [ -d "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/overlays" ] ; then
    for dtb in "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/overlays/"*.dtbo ; do
      if [ -f "${dtb}" ] ; then
        install_readonly "${dtb}" "${BOOT_DIR}/overlays/"
      fi
    done

    if [ -f "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/overlays/README" ] ; then
      install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/overlays/README" "${BOOT_DIR}/overlays/README"
    fi
  fi

  if [ "$ENABLE_UBOOT" = false ] ; then
    # Convert and copy kernel image to the boot directory
    "${KERNEL_DIR}/scripts/mkknlimg" "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/${KERNEL_BIN_IMAGE}" "${BOOT_DIR}/${KERNEL_IMAGE}"
  else
    # Copy kernel image to the boot directory
    install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/${KERNEL_BIN_IMAGE}" "${BOOT_DIR}/${KERNEL_IMAGE}"
  fi

  # Remove kernel sources
  if [ "$KERNEL_REMOVESRC" = true ] ; then
    rm -fr "${KERNEL_DIR}"
  else
    # Prepare compiled kernel modules
    if grep -q "CONFIG_MODULES=y" "${KERNEL_DIR}/.config" ; then
      if grep -q "^modules_prepare:" "${KERNEL_DIR}/Makefile" ; then
        make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" modules_prepare
      fi

      # Create symlinks for kernel modules
      chroot_exec ln -sf /usr/src/linux "/lib/modules/${KERNEL_VERSION}/build"
      chroot_exec ln -sf /usr/src/linux "/lib/modules/${KERNEL_VERSION}/source"
    fi
  fi

else # BUILD_KERNEL=false
  if [ "$SET_ARCH" = 64 ] && { [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 3P ] ; } ; then

	# Use Sakakis modified kernel if ZSWAP is active
    if [ "$KERNEL_ZSWAP" = true ] || [ "$KERNEL_VIRT" = true ] || [ "$KERNEL_NF" = true ] || [ "$KERNEL_BPF" = true ] ; then
	  RPI3_64_KERNEL_URL="${RPI3_64_BIS_KERNEL_URL}"
	fi

    # Create temporary directory for dl
    temp_dir=$(as_nobody mktemp -d)

    # Fetch kernel dl
    as_nobody wget -O "${temp_dir}"/kernel.tar.xz -c "$RPI3_64_KERNEL_URL" 

    #extract download
    tar -xJf "${temp_dir}"/kernel.tar.xz -C "${temp_dir}"

    #move extracted kernel to /boot/firmware
    mkdir "${R}/boot/firmware"
    cp "${temp_dir}"/boot/* "${R}"/boot/firmware/
    cp -r "${temp_dir}"/lib/* "${R}"/lib/

    # Remove temporary directory for kernel sources
    rm -fr "${temp_dir}"

    # Set permissions of the kernel sources
    chown -R root:root "${R}/boot/firmware"
    chown -R root:root "${R}/lib/modules"
  fi

  # Install Kernel from hypriot comptabile with all Raspberry PI
  if [ "$SET_ARCH" = 32 ] ; then
    # Create temporary directory for dl
    temp_dir=$(as_nobody mktemp -d)

    # Fetch kernel
    as_nobody wget -O "${temp_dir}"/kernel.deb -c "$RPI_32_KERNEL_URL"

    # Copy downloaded U-Boot sources
    mv "${temp_dir}"/kernel.deb "${R}"/tmp/kernel.deb

    # Set permissions
    chown -R root:root "${R}"/tmp/kernel.deb

	# Install kernel
	chroot_exec dpkg -i /tmp/kernel.deb

	# move /boot to /boot/firmware to fit script env.
	#mkdir "${BOOT_DIR}"
	mkdir "${temp_dir}"/firmware
	mv  "${R}"/boot/* "${temp_dir}"/firmware/
	mv "${temp_dir}"/firmware "${R}"/boot/

	#same for kernel headers
	if [ "$KERNEL_HEADERS" = true ] ; then
	  # Fetch kernel header
	  as_nobody wget -O "${temp_dir}"/kernel-header.deb -c "$RPI_32_KERNELHEADER_URL"
	  mv "${temp_dir}"/kernel-header.deb "${R}"/tmp/kernel-header.deb
	  chown -R root:root "${R}"/tmp/kernel-header.deb
	  # Install kernel header
	  chroot_exec dpkg -i /tmp/kernel-header.deb
	  rm -f "${R}"/tmp/kernel-header.deb
	fi

    # Remove temporary directory and files
    rm -fr "${temp_dir}"
	rm -f "${R}"/tmp/kernel.deb
  fi

  # Check if kernel installation was successful
  KERNEL="$(ls -1 "${R}"/boot/firmware/kernel* | sort | tail -n 1)"
  if [ -z "$KERNEL" ] ; then
    echo "error: kernel installation failed! (/boot/kernel* not found)"
    cleanup
    exit 1
  fi
fi
