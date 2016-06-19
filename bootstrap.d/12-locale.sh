#
# Setup Locales and keyboard settings
#

# Load utility functions
. ./functions.sh

# Install and setup timezone
echo ${TIMEZONE} > "${ETCDIR}/timezone"
chroot_exec dpkg-reconfigure -f noninteractive tzdata

# Install and setup default locale and keyboard configuration
if [ $(echo "$APT_INCLUDES" | grep ",locales") ] ; then
  # Set locale choice in debconf db, even though dpkg-reconfigure ignores and overwrites them due to some bug
  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=684134 https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=685957
  # ... so we have to set locales manually
  if [ "$DEFLOCAL" = "en_US.UTF-8" ] ; then
    chroot_exec echo "locales locales/locales_to_be_generated multiselect ${DEFLOCAL} UTF-8" | debconf-set-selections
  else
    # en_US.UTF-8 should be available anyway : https://www.debian.org/doc/manuals/debian-reference/ch08.en.html#_the_reconfiguration_of_the_locale
    chroot_exec echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8, ${DEFLOCAL} UTF-8" | debconf-set-selections
    sed -i "/en_US.UTF-8/s/^#//" "${ETCDIR}/locale.gen"
  fi

  sed -i "/${DEFLOCAL}/s/^#//" "${ETCDIR}/locale.gen"
  chroot_exec echo "locales locales/default_environment_locale select ${DEFLOCAL}" | debconf-set-selections
  chroot_exec locale-gen
  chroot_exec update-locale LANG="${DEFLOCAL}"

  # Install and setup default keyboard configuration
  if [ "$XKB_MODEL" != "" ] ; then
    sed -i "s/^XKBMODEL.*/XKBMODEL=\"${XKB_MODEL}\"/" "${ETCDIR}/default/keyboard"
  fi
  if [ "$XKB_LAYOUT" != "" ] ; then
    sed -i "s/^XKBLAYOUT.*/XKBLAYOUT=\"${XKB_LAYOUT}\"/" "${ETCDIR}/default/keyboard"
  fi
  if [ "$XKB_VARIANT" != "" ] ; then
    sed -i "s/^XKBVARIANT.*/XKBVARIANT=\"${XKB_VARIANT}\"/" "${ETCDIR}/default/keyboard"
  fi
  if [ "$XKB_OPTIONS" != "" ] ; then
    sed -i "s/^XKBOPTIONS.*/XKBOPTIONS=\"${XKB_OPTIONS}\"/" "${ETCDIR}/default/keyboard"
  fi
  chroot_exec dpkg-reconfigure -f noninteractive keyboard-configuration

  # Install and setup font console
  case "${DEFLOCAL}" in
    *UTF-8)
      sed -i 's/^CHARMAP.*/CHARMAP="UTF-8"/' "${ETCDIR}/default/console-setup"
      ;;
    *)
      sed -i 's/^CHARMAP.*/CHARMAP="guess"/' "${ETCDIR}/default/console-setup"
      ;;
  esac
  chroot_exec dpkg-reconfigure -f noninteractive console-setup
else # (no locales were installed)
  # Install POSIX default locale
  install_readonly files/locales/locale "${ETCDIR}/default/locale"
fi
