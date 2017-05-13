# Configuration template file used by rpi23-gen-image.sh
# Debian Stretch using the Arm64 for kernel compilation and Debian distribution.

RPI_MODEL=3
RELEASE=stretch
BUILD_KERNEL=true
KERNEL_ARCH=arm64
RELEASE_ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-
QEMU_BINARY=/usr/bin/qemu-aarch64-static
KERNEL_DEFCONFIG=bcmrpi3_defconfig
KERNEL_BIN_IMAGE=Image
KERNEL_IMAGE=kernel8.img
KERNEL_BRANCH=rpi-4.11.y
ENABLE_WIRELESS=true
