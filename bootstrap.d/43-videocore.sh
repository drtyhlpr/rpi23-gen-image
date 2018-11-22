#
# Setup videocore - Raspberry Userland
#

# Load utility functions
. ./functions.sh

if [ "$ENABLE_VIDEOCORE" = true ] ; then
  # Copy existing videocore sources into chroot directory
  if [ -n "$VIDEOCORESRC_DIR" ] && [ -d "$VIDEOCORESRC_DIR" ] ; then
    # Copy local videocore sources
    cp -r "${VIDEOCORESRC_DIR}" "${R}/tmp/userland"
  else
    # Create temporary directory for videocore sources
    temp_dir=$(as_nobody mktemp -d)

    # Fetch videocore sources
    as_nobody git -C "${temp_dir}" clone "${VIDEOCORE_URL}"

    # Copy downloaded videocore sources
    mv "${temp_dir}/userland" "${R}/tmp/"

    # Set permissions of the U-Boot sources
    chown -R root:root "${R}/tmp/userland"

    # Remove temporary directory for U-Boot sources
    rm -fr "${temp_dir}"
  fi
  
  # Create build dir
  mkdir "${R}"/tmp/userland/build

  # push us to build directory
  cd "${R}"/tmp/userland/build

  if [ "$RELEASE_ARCH" = "arm64" ] ; then
  cmake -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_BUILD_TYPE=release -DARM64=ON -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ -DCMAKE_ASM_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS} -U_FORTIFY_SOURCE" -DCMAKE_ASM_FLAGS="${CMAKE_ASM_FLAGS} -c" -DVIDEOCORE_BUILD_DIR="${R}" "${R}/tmp/userland"
  fi

  if [ "$RELEASE_ARCH" = "armel" ] ; then
  cmake -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_BUILD_TYPE=release -DCMAKE_C_COMPILER=arm-linux-gnueabi-gcc -DCMAKE_CXX_COMPILER=arm-linux-gnueabi-g++ -DCMAKE_ASM_COMPILER=arm-linux-gnueabi-gcc -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS} -U_FORTIFY_SOURCE" -DCMAKE_ASM_FLAGS="${CMAKE_ASM_FLAGS} -c" -DCMAKE_SYSTEM_PROCESSOR="arm" -DVIDEOCORE_BUILD_DIR="${R}" "${R}/tmp/userland"
  fi

  if [ "$RELEASE_ARCH" = "armhf" ] ; then
  cmake -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_BUILD_TYPE=release -DCMAKE_TOOLCHAIN_FILE="${R}"/tmp/userland/makefiles/cmake/toolchains/arm-linux-gnueabihf.cmake -DVIDEOCORE_BUILD_DIR="${R}" "${R}/tmp/userland"
  fi

  #build userland
  make -j "$(nproc)"

  #back to root of scriptdir
  cd "${WORKDIR}"
fi
