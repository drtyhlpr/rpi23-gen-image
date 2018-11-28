#!/bin/sh
#
# Build and Setup nexmon with monitor mode patch
#

# Load utility functions
. ./functions.sh

if [ "$ENABLE_NEXMON" = true ] && [ "$ENABLE_WIRELESS" = true ]; then
  # Copy existing nexmon sources into chroot directory
  if [ -n "$NEXMONSRC_DIR" ] && [ -d "$NEXMONSRC_DIR" ] ; then
    # Copy local U-Boot sources
    cp -r "${NEXMONSRC_DIR}" "${R}/tmp"
  else
    # Create temporary directory for nexmon sources
    temp_dir=$(as_nobody mktemp -d)

    # Fetch nexmon sources
    as_nobody git -C "${temp_dir}" clone "${NEXMON_URL}"

    # Copy downloaded nexmon sources
    mv "${temp_dir}/nexmon" "${R}"/tmp/

    # Set permissions of the nexmon sources
    chown -R root:root "${R}"/tmp/nexmon

    # Remove temporary directory for nexmon sources
    rm -fr "${temp_dir}"
  fi
	
  # Set script Root
  export NEXMON_ROOT="${R}"/tmp/nexmon

  # Build nexmon firmware outside the build system, if we can.
  cd "${NEXMON_ROOT}" || exit
  
  # Make ancient isl build
  cd buildtools/isl-0.10 || exit
  ./configure
  make
  cd ../.. || exit
  
  # Disable statistics
  touch DISABLE_STATISTICS
  
  # Setup Enviroment: see https://github.com/NoobieDog/nexmon/blob/master/setup_env.sh
  #ARCH="${KERNEL_ARCH}"
  #SUBARCH="${KERNEL_ARCH}"
  export KERNEL="${KERNEL_IMAGE}"
  export ARCH=arm
  export SUBARCH=arm
  export CC="${NEXMON_ROOT}"/buildtools/gcc-arm-none-eabi-5_4-2016q2-linux-x86/bin/arm-none-eabi-
  export CC="${CC}"gcc
  export CCPLUGIN="${NEXMON_ROOT}"/buildtools/gcc-nexmon-plugin/nexmon.so
  export ZLIBFLATE="zlib-flate -compress"
  export Q=@
  export NEXMON_SETUP_ENV=1
  export HOSTUNAME=$(uname -s)
  export PLATFORMUNAME=$(uname -m)
  #. ./setup_env.sh
  
  # Make nexmon
  make
  
  # Backup stock broadcom wlan driver - "${LIB_DIR}"/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac/brcmfmac.ko
  #brcmfmac_path=$(modinfo brcmfmac | grep -m 1 -oP "^filename:(\s*?)(.*)$" | sed -e 's/^filename:\(\s*\)\(.*\)$/\2/g')
  #brcmfmac_path="${LIB_DIR}"/modules/"${KERNEL_VERSION}"/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac/brcmfmac.ko
  #mv "${brcmfmac_path}" "${brcmfmac_path}".orig

  #
  
  # build patches
  if [ "$RPI_MODEL" = 0 ] || [ "$RPI_MODEL" = 3 ] ; then
    cd "${NEXMON_ROOT}"/patches/bcm43430a1/7_45_41_46/nexmon || exit
    make clean
	
    # We do this so we don't have to install the ancient isl version into /usr/local/lib on systems.
    LD_LIBRARY_PATH="${NEXMON_ROOT}"/buildtools/isl-0.10/.libs make ARCH="${KERNEL_ARCH}" CC="${NEXMON_ROOT}"/buildtools/gcc-arm-none-eabi-5_4-2016q2-linux-x86/bin/arm-none-eabi-
	
    # copy RPi0W & RPi3 firmware
	mv "${WLAN_FIRMWARE_DIR}"/brcmfmac43430-sdio.bin "${WLAN_FIRMWARE_DIR}"/brcmfmac43430-sdio.org.bin
    cp "${NEXMON_ROOT}"/patches/bcm43430a1/7_45_41_46/nexmon/brcmfmac43430-sdio.bin "${WLAN_FIRMWARE_DIR}"/brcmfmac43430-sdio.nexmon.bin
    cp -f "${NEXMON_ROOT}"/patches/bcm43430a1/7_45_41_46/nexmon/brcmfmac43430-sdio.bin "${WLAN_FIRMWARE_DIR}"/brcmfmac43430-sdio.bin
	
	cp "${NEXMON_ROOT}"/patches/bcm43430a1/7_45_41_46/nexmon/brcmfmac_4.14.y-nexmon/brcmfmac.ko "${brcmfmac_path}"
  fi
  
  if [ "$RPI_MODEL" = 3P ] ; then
    cd "${NEXMON_ROOT}"/patches/bcm43455c0/7_45_154/nexmon || exit
    make clean
	
	# We do this so we don't have to install the ancient isl version into /usr/local/lib on systems.
    LD_LIBRARY_PATH=${NEXMON_ROOT}/buildtools/isl-0.10/.libs make ARCH="${KERNEL_ARCH}" CC="${NEXMON_ROOT}"/buildtools/gcc-arm-none-eabi-5_4-2016q2-linux-x86/bin/arm-none-eabi-

    # RPi3B+ firmware
	mv "${WLAN_FIRMWARE_DIR}"/brcmfmac43455-sdio.bin "${WLAN_FIRMWARE_DIR}"/brcmfmac43455-sdio.org.bin
    cp "${NEXMON_ROOT}"/patches/bcm43455c0/7_45_154/nexmon/brcmfmac43455-sdio.bin "${WLAN_FIRMWARE_DIR}"/brcmfmac43455-sdio.nexmon.bin
    cp -f "${NEXMON_ROOT}"/patches/bcm43455c0/7_45_154/nexmon/brcmfmac43455-sdio.bin "${WLAN_FIRMWARE_DIR}"/brcmfmac43455-sdio.bin
  fi
  
#Revert to previous directory
cd "${WORKDIR}" || exit

fi
