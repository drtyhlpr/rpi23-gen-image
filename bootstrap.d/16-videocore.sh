#
# Setup videocore - Raspberry Userland
#

# Load utility functions
. ./functions.sh

if [ "$ENABLE_VIDEOCORE" = true ] ; then
  # Copy existing videocore sources into chroot directory
  if [ -n "$VIDEOCORESRC_DIR" ] && [ -d "$VIDEOCORESRC_DIR" ] ; then
    # Copy local U-Boot sources
    cp -r "${VIDEOCORESRC_DIR}" "${R}/tmp"
  else
    # Create temporary directory for U-Boot sources
    temp_dir=$(as_nobody mktemp -d)

    # Fetch U-Boot sources
    as_nobody git -C "${temp_dir}" clone "${VIDEOCORE_URL}"

    # Copy downloaded U-Boot sources
    mv "${temp_dir}/userland" "${R}/tmp/"

    # Set permissions of the U-Boot sources
    chown -R root:root "${R}/tmp/userland"

    # Remove temporary directory for U-Boot sources
    rm -fr "${temp_dir}"
  fi

  cmake -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_BUILD_TYPE=release -DARM64=ON -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ -DCMAKE_ASM_COMPILER=aarch64-linux-gnu-gcc -DVIDEOCORE_BUILD_DIR="${R}"/opt/vc
  make -j $(nproc)
  chroot_exec PATH=${PATH}:/opt/vc/bin
fi
