#
# Build and Setup fbturbo Xorg driver
#

# Load utility functions
. ./functions.sh

if [ "$ENABLE_NEXMON" = true ] ; then

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
# Build nexmon firmware outside the build system, if we can.
cd "${R}"/tmp/nexmon
# Disable statistics
touch DISABLE_STATISTICS
# Setup Enviroment
source setup_env.sh
# Make nexmon
make

# Make ancient isl build
cd buildtools/isl-0.10
CC="$CROSS_COMPILE"
./configure
make

# build patches
cd ${NEXMON_ROOT}/patches/bcm43430a1/7_45_41_46/nexmon
# Make sure we use the cross compiler to build the firmware.
# We use the x86 cross compiler because we're building on amd64
#unset CROSS_COMPILE
#export CROSS_COMPILE=${NEXMON_ROOT}/buildtools/gcc-arm-none-eabi-5_4-2016q2-linux-x86/bin/arm-none-eabi-
make clean
# We do this so we don't have to install the ancient isl version into /usr/local/lib on systems.
LD_LIBRARY_PATH=${NEXMON_ROOT}/buildtools/isl-0.10/.libs make ARCH=arm CC="$CROSS_COMPILE"
cd ${NEXMON_ROOT}/patches/bcm43455c0/7_45_154/nexmon
make clean
LD_LIBRARY_PATH=${NEXMON_ROOT}/buildtools/isl-0.10/.libs make ARCH=arm CC="$CROSS_COMPILE"
# RPi0w->3B firmware
mkdir -p "${basedir}"/kali-${architecture}/lib/firmware/brcm
cp ${NEXMON_ROOT}/patches/bcm43430a1/7_45_41_46/nexmon/brcmfmac43430-sdio.bin "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43430-sdio.nexmon.bin
cp ${NEXMON_ROOT}/patches/bcm43430a1/7_45_41_46/nexmon/brcmfmac43430-sdio.bin "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43430-sdio.bin
#wget https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43430-sdio.txt -O "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43430-sdio.txt
# RPi3B+ firmware
cp ${NEXMON_ROOT}/patches/bcm43455c0/7_45_154/nexmon/brcmfmac43455-sdio.bin "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43455-sdio.nexmon.bin
cp ${NEXMON_ROOT}/patches/bcm43455c0/7_45_154/nexmon/brcmfmac43455-sdio.bin "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43455-sdio.bin
#wget https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.txt -O "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43455-sdio.txt
# Make a backup copy of the rpi firmware in case people don't want to use the nexmon firmware.
# The firmware used on the RPi is not the same firmware that is in the firmware-brcm package which is why we do this.
#wget https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43430-sdio.bin -O "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43430-sdio.rpi.bin
#wget https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.bin -O "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43455-sdio.rpi.bin
# This is required for any wifi to work on the RPi 3B+
#wget https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.clm_blob -O "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43455-sdio.clm_blob
