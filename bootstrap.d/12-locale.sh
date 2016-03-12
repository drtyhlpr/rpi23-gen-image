#
# Setup Locales and keyboard settings
#

# Load utility functions
. ./functions.sh

# Set up timezone
echo ${TIMEZONE} >$R/etc/timezone
chroot_exec dpkg-reconfigure -f noninteractive tzdata

# Set up default locale and keyboard configuration
if [ "$ENABLE_MINBASE" = false ] ; then
  # Set locale choice in debconf db, even though dpkg-reconfigure ignores and overwrites them due to some bug
  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=684134 https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=685957
  # ... so we have to set locales manually
  if [ "$DEFLOCAL" = "en_US.UTF-8" ] ; then
    chroot_exec echo "locales locales/locales_to_be_generated multiselect ${DEFLOCAL} UTF-8" | debconf-set-selections
  else
    # en_US.UTF-8 should be available anyway : https://www.debian.org/doc/manuals/debian-reference/ch08.en.html#_the_reconfiguration_of_the_locale
    chroot_exec echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8, ${DEFLOCAL} UTF-8" | debconf-set-selections
    sed -i "/en_US.UTF-8/s/^#//" $R/etc/locale.gen
  fi

  sed -i "/${DEFLOCAL}/s/^#//" $R/etc/locale.gen
  chroot_exec echo "locales locales/default_environment_locale select ${DEFLOCAL}" | debconf-set-selections
  chroot_exec locale-gen
  chroot_exec update-locale LANG=${DEFLOCAL}

  # Keyboard configuration, if requested
  if [ "$XKB_MODEL" != "" ] ; then
    sed -i "s/^XKBMODEL.*/XKBMODEL=\"${XKB_MODEL}\"/" $R/etc/default/keyboard
  fi
  if [ "$XKB_LAYOUT" != "" ] ; then
    sed -i "s/^XKBLAYOUT.*/XKBLAYOUT=\"${XKB_LAYOUT}\"/" $R/etc/default/keyboard
  fi
  if [ "$XKB_VARIANT" != "" ] ; then
    sed -i "s/^XKBVARIANT.*/XKBVARIANT=\"${XKB_VARIANT}\"/" $R/etc/default/keyboard
  fi
  if [ "$XKB_OPTIONS" != "" ] ; then
    sed -i "s/^XKBOPTIONS.*/XKBOPTIONS=\"${XKB_OPTIONS}\"/" $R/etc/default/keyboard
  fi
  chroot_exec dpkg-reconfigure -f noninteractive keyboard-configuration

  # Set up font console
  case "${DEFLOCAL}" in
    *UTF-8)
      sed -i 's/^CHARMAP.*/CHARMAP="UTF-8"/' $R/etc/default/console-setup
      ;;
    *)
      sed -i 's/^CHARMAP.*/CHARMAP="guess"/' $R/etc/default/console-setup
      ;;
  esac
  chroot_exec dpkg-reconfigure -f noninteractive console-setup
else # ENABLE_MINBASE=true
  # Set POSIX default locales
  install_readonly files/locales/locale $R/etc/default/locale
fi
