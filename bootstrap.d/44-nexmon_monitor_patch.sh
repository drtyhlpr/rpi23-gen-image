#
# Build and Setup fbturbo Xorg driver
#

# Load utility functions
. ./functions.sh

# Build nexmon firmware outside the build system, if we can.
cd "${basedir}"
git clone https://github.com/seemoo-lab/nexmon.git "${basedir}"/nexmon --depth 1
cd "${basedir}"/nexmon
# Disable statistics
touch DISABLE_STATISTICS
source setup_env.sh
ls -lah /usr/lib/x86_64-linux-gnu/libl.a
ls -lah /usr/lib/x86_64-linux-gnu/libfl.a
make
cd buildtools/isl-0.10
CC=$CCgcc
./configure
make
sed -i -e 's/all:.*/all: $(RAM_FILE)/g' ${NEXMON_ROOT}/patches/bcm43430a1/7_45_41_46/nexmon/Makefile
sed -i -e 's/all:.*/all: $(RAM_FILE)/g' ${NEXMON_ROOT}/patches/bcm43455c0/7_45_154/nexmon/Makefile
cd ${NEXMON_ROOT}/patches/bcm43430a1/7_45_41_46/nexmon
# Make sure we use the cross compiler to build the firmware.
# We use the x86 cross compiler because we're building on amd64
unset CROSS_COMPILE
#export CROSS_COMPILE=${NEXMON_ROOT}/buildtools/gcc-arm-none-eabi-5_4-2016q2-linux-x86/bin/arm-none-eabi-
make clean
# We do this so we don't have to install the ancient isl version into /usr/local/lib on systems.
LD_LIBRARY_PATH=${NEXMON_ROOT}/buildtools/isl-0.10/.libs make ARCH=arm CC=${NEXMON_ROOT}/buildtools/gcc-arm-none-eabi-5_4-2016q2-linux-x86/bin/arm-none-eabi-
cd ${NEXMON_ROOT}/patches/bcm43455c0/7_45_154/nexmon
make clean
LD_LIBRARY_PATH=${NEXMON_ROOT}/buildtools/isl-0.10/.libs make ARCH=arm CC=${NEXMON_ROOT}/buildtools/gcc-arm-none-eabi-5_4-2016q2-linux-x86/bin/arm-none-eabi-
# RPi0w->3B firmware
mkdir -p "${basedir}"/kali-${architecture}/lib/firmware/brcm
cp ${NEXMON_ROOT}/patches/bcm43430a1/7_45_41_46/nexmon/brcmfmac43430-sdio.bin "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43430-sdio.nexmon.bin
cp ${NEXMON_ROOT}/patches/bcm43430a1/7_45_41_46/nexmon/brcmfmac43430-sdio.bin "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43430-sdio.bin
wget https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43430-sdio.txt -O "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43430-sdio.txt
# RPi3B+ firmware
cp ${NEXMON_ROOT}/patches/bcm43455c0/7_45_154/nexmon/brcmfmac43455-sdio.bin "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43455-sdio.nexmon.bin
cp ${NEXMON_ROOT}/patches/bcm43455c0/7_45_154/nexmon/brcmfmac43455-sdio.bin "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43455-sdio.bin
wget https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.txt -O "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43455-sdio.txt
# Make a backup copy of the rpi firmware in case people don't want to use the nexmon firmware.
# The firmware used on the RPi is not the same firmware that is in the firmware-brcm package which is why we do this.
wget https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43430-sdio.bin -O "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43430-sdio.rpi.bin
wget https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.bin -O "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43455-sdio.rpi.bin
# This is required for any wifi to work on the RPi 3B+
wget https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.clm_blob -O "${basedir}"/kali-${architecture}/lib/firmware/brcm/brcmfmac43455-sdio.clm_blob
