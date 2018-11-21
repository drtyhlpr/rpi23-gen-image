# rpi23-gen-image
## Introduction
`rpi23-gen-image.sh` is an advanced Debian Linux bootstrapping shell script for generating Debian OS images for Raspberry Pi 2 (RPi2) and Raspberry Pi 3 (RPi3) computers. The script at this time supports the bootstrapping of the Debian (armhf) releases `stretch` and `buster`. Raspberry Pi 3 images are generated for 32-bit mode only. Raspberry Pi 3 64-bit images can be generated using custom configuration parameters (```templates/rpi3-stretch-arm64-4.14.y```).

## Build dependencies
The following list of Debian packages must be installed on the build system because they are essentially required for the bootstrapping process. The script will check if all required packages are installed and missing packages will be installed automatically if confirmed by the user.

  ```debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git bc psmisc dbus sudo```

It is recommended to configure the `rpi23-gen-image.sh` script to build and install the latest Raspberry Pi Linux kernel. For the RPi3 this is mandatory. Kernel compilation and linking will be performed on the build system using an ARM (armhf) cross-compiler toolchain.

The script has been tested using the default `crossbuild-essential-armhf` toolchain meta package on Debian Linux `stretch` build systems. Please check the [Debian CrossToolchains Wiki](https://wiki.debian.org/CrossToolchains) for further information.

## Command-line parameters
The script accepts certain command-line parameters to enable or disable specific OS features, services and configuration settings. These parameters are passed to the `rpi23-gen-image.sh` script via (simple) shell-variables. Unlike environment shell-variables (simple) shell-variables are defined at the beginning of the command-line call of the `rpi23-gen-image.sh` script.

##### Command-line examples:
```shell
ENABLE_UBOOT=true ./rpi23-gen-image.sh
ENABLE_CONSOLE=false ENABLE_IPV6=false ./rpi23-gen-image.sh
ENABLE_WM=xfce4 ENABLE_FBTURBO=true ENABLE_MINBASE=true ./rpi23-gen-image.sh
ENABLE_HARDNET=true ENABLE_IPTABLES=true /rpi23-gen-image.sh
APT_SERVER=ftp.de.debian.org APT_PROXY="http://127.0.0.1:3142/" ./rpi23-gen-image.sh
ENABLE_MINBASE=true ./rpi23-gen-image.sh
BUILD_KERNEL=true ENABLE_MINBASE=true ENABLE_IPV6=false ./rpi23-gen-image.sh
BUILD_KERNEL=true KERNELSRC_DIR=/tmp/linux ./rpi23-gen-image.sh
ENABLE_MINBASE=true ENABLE_REDUCE=true ENABLE_MINGPU=true BUILD_KERNEL=true ./rpi23-gen-image.sh
ENABLE_CRYPTFS=true CRYPTFS_PASSWORD=changeme EXPANDROOT=false ENABLE_MINBASE=true ENABLE_REDUCE=true ENABLE_MINGPU=true BUILD_KERNEL=true ./rpi23-gen-image.sh
RELEASE=stretch BUILD_KERNEL=true ./rpi23-gen-image.sh
RPI_MODEL=3 ENABLE_WIRELESS=true ENABLE_MINBASE=true BUILD_KERNEL=true ./rpi23-gen-image.sh
RELEASE=stretch RPI_MODEL=3 ENABLE_WIRELESS=true ENABLE_MINBASE=true BUILD_KERNEL=true ./rpi23-gen-image.sh
```

## Configuration template files
To avoid long lists of command-line parameters and to help to store the favourite parameter configurations the `rpi23-gen-image.sh` script supports so called configuration template files (`CONFIG_TEMPLATE`=template). These are simple text files located in the `./templates` directory that contain the list of configuration parameters that will be used. New configuration template files can be added to the `./templates` directory.

##### Command-line examples:
```shell
CONFIG_TEMPLATE=rpi3stretch ./rpi23-gen-image.sh
CONFIG_TEMPLATE=rpi2stretch ./rpi23-gen-image.sh
```

## Supported parameters and settings
#### APT settings:
##### `APT_SERVER`="ftp.debian.org"
Set Debian packages server address. Choose a server from the list of Debian worldwide [mirror sites](https://www.debian.org/mirror/list). Using a nearby server will probably speed-up all required downloads within the bootstrapping process.

##### `APT_PROXY`=""
Set Proxy server address. Using a local Proxy-Cache like `apt-cacher-ng` will speed-up the bootstrapping process because all required Debian packages will only be downloaded from the Debian mirror site once. If `apt-cacher-ng` is running on default `http://127.0.0.1:3142` it is autodetected and you don't need to set this.

##### `APT_INCLUDES`=""
A comma separated list of additional packages to be installed by debootstrap during bootstrapping.

##### `APT_INCLUDES_LATE`=""
A comma separated list of additional packages to be installed by apt after bootstrapping and after APT sources are set up.  This is useful for packages with pre-depends, which debootstrap do not handle well.

---

#### General system settings:
##### `SET_ARCH`=32
Set Architecture to default 32bit. If you want to to compile 64bit (RPI3 or RPI3+) set it to `64`. This option will set every needed crosscompiler or boeard specific option for a successful build.
If you want to change e.g. cross-compiler -> Templates always override defaults

##### `RPI_MODEL`=2
Specifiy the target Raspberry Pi hardware model. The script at this time supports the following Raspberry Pi models:
`0`  = Used for Raspberry Pi 0 and Raspberry Pi 0 W
`1`  = Used for Pi 1 model A and B
`1P` = Used for Pi 1 model B+ and A+
`2`  = Used for Pi 2 model B
`3`  = Used for Pi 3 model B
`3P` = Used for Pi 3 model B+
`BUILD_KERNEL`=true will automatically be set if the Raspberry Pi model `3` or `3P` is used.

##### `RELEASE`="buster"
Set the desired Debian release name. The script at this time supports the bootstrapping of the Debian releases `stretch` and `buster`.

##### `RELEASE_ARCH`="armhf"
Set the desired Debian release architecture.

##### `HOSTNAME`="rpi$RPI_MODEL-$RELEASE"
Set system host name. It's recommended that the host name is unique in the corresponding subnet.

##### `PASSWORD`="raspberry"
Set system `root` password. It's **STRONGLY** recommended that you choose a custom password.

##### `USER_PASSWORD`="raspberry"
Set password for the created non-root user `USER_NAME`=pi. Ignored if `ENABLE_USER`=false. It's **STRONGLY** recommended that you choose a custom password.

##### `DEFLOCAL`="en_US.UTF-8"
Set default system locale. This setting can also be changed inside the running OS using the `dpkg-reconfigure locales` command. Please note that on using this parameter the script will automatically install the required packages `locales`, `keyboard-configuration` and `console-setup`.

##### `TIMEZONE`="Europe/Berlin"
Set default system timezone. All available timezones can be found in the `/usr/share/zoneinfo/` directory. This setting can also be changed inside the running OS using the `dpkg-reconfigure tzdata` command.

##### `EXPANDROOT`=true
Expand the root partition and filesystem automatically on first boot.

##### `ENABLE_QEMU`=false
Generate kernel (`vexpress_defconfig`), file system image (`qcow2`) and DTB files that can be used for QEMU full system emulation (`vexpress-A15`). The output files are stored in the `$(pwd)/images/qemu` directory. You can find more information about running the generated image in the QEMU section of this readme file.

---

#### Keyboard settings:
These options are used to configure keyboard layout in `/etc/default/keyboard` for console and Xorg. These settings can also be changed inside the running OS using the `dpkg-reconfigure keyboard-configuration` command.

##### `XKB_MODEL`=""
Set the name of the model of your keyboard type.

##### `XKB_LAYOUT`=""
Set the supported keyboard layout(s).

##### `XKB_VARIANT`=""
Set the supported variant(s) of the keyboard layout(s).

##### `XKB_OPTIONS`=""
Set extra xkb configuration options.

---

#### Networking settings (DHCP):
This parameter is used to set up networking auto configuration in `/etc/systemd/network/eth.network`. The default location of network configuration files in the Debian `stretch` release was changed to `/lib/systemd/network`.`

##### `ENABLE_DHCP`=true
Set the system to use DHCP. This requires an DHCP server.

---

#### Networking settings (static):
These parameters are used to set up a static networking configuration in `/etc/systemd/network/eth.network`. The following static networking parameters are only supported if `ENABLE_DHCP` was set to `false`. The default location of network configuration files in the Debian `stretch` release was changed to `/lib/systemd/network`.

##### `NET_ADDRESS`=""
Set a static IPv4 or IPv6 address and its prefix, separated by "/", eg. "192.169.0.3/24".

##### `NET_GATEWAY`=""
Set the IP address for the default gateway.

##### `NET_DNS_1`=""
Set the IP address for the first DNS server.

##### `NET_DNS_2`=""
Set the IP address for the second DNS server.

##### `NET_DNS_DOMAINS`=""
Set the default DNS search domains to use for non fully qualified host names.

##### `NET_NTP_1`=""
Set the IP address for the first NTP server.

##### `NET_NTP_2`=""
Set the IP address for the second NTP server.

---

#### Basic system features:
##### `ENABLE_CONSOLE`=true
Enable serial console interface. Recommended if no monitor or keyboard is connected to the RPi2/3. In case of problems fe. if the network (auto) configuration failed - the serial console can be used to access the system.

##### `ENABLE_I2C`=false
Enable I2C interface on the RPi2/3. Please check the [RPi2/3 pinout diagrams](https://elinux.org/RPi_Low-level_peripherals) to connect the right GPIO pins.

##### `ENABLE_SPI`=false
Enable SPI interface on the RPi2/3. Please check the [RPi2/3 pinout diagrams](https://elinux.org/RPi_Low-level_peripherals) to connect the right GPIO pins.

##### `ENABLE_IPV6`=true
Enable IPv6 support. The network interface configuration is managed via systemd-networkd.

##### `ENABLE_SSHD`=true
Install and enable OpenSSH service. The default configuration of the service doesn't allow `root` to login. Please use the user `pi` instead and `su -` or `sudo` to execute commands as root.

##### `ENABLE_NONFREE`=false
Allow the installation of non-free Debian packages that do not comply with the DFSG. This is required to install closed-source firmware binary blobs.

##### `ENABLE_WIRELESS`=false
Download and install the [closed-source firmware binary blob](https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm) that is required to run the internal wireless interface of the Raspberry Pi model `3`. This parameter is ignored if the specified `RPI_MODEL` is not `3`.

##### `ENABLE_RSYSLOG`=true
If set to false, disable and uninstall rsyslog (so logs will be available only
in journal files)

##### `ENABLE_SOUND`=true
Enable sound hardware and install Advanced Linux Sound Architecture.

##### `ENABLE_HWRANDOM`=true
Enable Hardware Random Number Generator. Strong random numbers are important for most network based communications that use encryption. It's recommended to be enabled.

##### `ENABLE_MINGPU`=false
Minimize the amount of shared memory reserved for the GPU. It doesn't seem to be possible to fully disable the GPU.

##### `ENABLE_DBUS`=true
Install and enable D-Bus message bus. Please note that systemd should work without D-bus but it's recommended to be enabled.

##### `ENABLE_XORG`=false
Install Xorg open-source X Window System.

##### `ENABLE_WM`=""
Install a user defined window manager for the X Window System. To make sure all X related package dependencies are getting installed `ENABLE_XORG` will automatically get enabled if `ENABLE_WM` is used. The `rpi23-gen-image.sh` script has been tested with the following list of window managers: `blackbox`, `openbox`, `fluxbox`, `jwm`, `dwm`, `xfce4`, `awesome`.

##### `ENABLE_SYSVINIT`=false
Support for halt,init,poweroff,reboot,runlevel,shutdown,telinit commands

---

#### Advanced system features:
##### `ENABLE_MINBASE`=false
Use debootstrap script variant `minbase` which only includes essential packages and apt. This will reduce the disk usage by about 65 MB.

##### `ENABLE_REDUCE`=false
Reduce the disk space usage by deleting packages and files. See `REDUCE_*` parameters for detailed information.

##### `ENABLE_UBOOT`=false
Replace the default RPi2/3 second stage bootloader (bootcode.bin) with [U-Boot bootloader](https://git.denx.de/?p=u-boot.git;a=summary). U-Boot can boot images via the network using the BOOTP/TFTP protocol.

##### `UBOOTSRC_DIR`=""
Path to a directory (`u-boot`) of [U-Boot bootloader sources](https://git.denx.de/?p=u-boot.git;a=summary) that will be copied, configured, build and installed inside the chroot.

##### `ENABLE_FBTURBO`=false
Install and enable the [hardware accelerated Xorg video driver](https://github.com/ssvb/xf86-video-fbturbo) `fbturbo`. Please note that this driver is currently limited to hardware accelerated window moving and scrolling.

##### `FBTURBOSRC_DIR`=""
Path to a directory (`xf86-video-fbturbo`) of [hardware accelerated Xorg video driver sources](https://github.com/ssvb/xf86-video-fbturbo) that will be copied, configured, build and installed inside the chroot.

##### `ENABLE_VIDEOCORE`=false
Install and enable the [Source code for ARM side libraries for interfacing to Raspberry Pi GPU](https://github.com/raspberrypi/userland) `vcgencmd`. Please note that this driver is currently limited to hardware accelerated window moving and scrolling.

##### `VIDEOCORESRC_DIR`=""
Path to a directory (`userland`) of [Source code for ARM side libraries for interfacing to Raspberry Pi GPU](https://github.com/raspberrypi/userland) that will be copied, configured, build and installed inside the chroot.

##### `ENABLE_IPTABLES`=false
Enable iptables IPv4/IPv6 firewall. Simplified ruleset: Allow all outgoing connections. Block all incoming connections except to OpenSSH service.

##### `ENABLE_USER`=true
Create non-root user with password `USER_PASSWORD`=raspberry. Unless overridden with `USER_NAME`=user, username will be `pi`.

##### `USER_NAME`=pi
Non-root user to create.  Ignored if `ENABLE_USER`=false

##### `ENABLE_ROOT`=false
Set root user password so root login will be enabled

##### `ENABLE_HARDNET`=false
Enable IPv4/IPv6 network stack hardening settings.

##### `ENABLE_SPLITFS`=false
Enable having root partition on an USB drive by creating two image files: one for the `/boot/firmware` mount point, and another for `/`.

##### `CHROOT_SCRIPTS`=""
Path to a directory with scripts that should be run in the chroot before the image is finally built. Every executable file in this directory is run in lexicographical order.

##### `ENABLE_INITRAMFS`=false
Create an initramfs that that will be loaded during the Linux startup process. `ENABLE_INITRAMFS` will automatically get enabled if `ENABLE_CRYPTFS`=true. This parameter will be ignored if `BUILD_KERNEL`=false.

##### `ENABLE_IFNAMES`=true
Enable automatic assignment of predictable, stable network interface names for all local Ethernet, WLAN interfaces. This might create complex and long interface names.

##### `DISABLE_UNDERVOLT_WARNINGS`=
Disable RPi2/3 under-voltage warnings and overlays. Setting the parameter to `1` will disable the warning overlay. Setting it to `2` will additionally allow RPi2/3 turbo mode when low-voltage is present.

---

#### SSH settings:
##### `SSH_ENABLE_ROOT`=false
Enable password root login via SSH. This may be a security risk with default password, use only in trusted environments. `ENABLE_ROOT` must be set to `true`.

##### `SSH_DISABLE_PASSWORD_AUTH`=false
Disable password based SSH authentication. Only public key based SSH (v2) authentication will be supported.

##### `SSH_LIMIT_USERS`=false
Limit the users that are allowed to login via SSH. Only allow user `USER_NAME`=pi and root if `SSH_ENABLE_ROOT`=true to login. This parameter will be ignored if `dropbear` SSH is used (`REDUCE_SSHD`=true).

##### `SSH_ROOT_PUB_KEY`=""
Add SSH (v2) public key(s) from specified file to `authorized_keys` file to enable public key based SSH (v2) authentication of user `root`. The specified file can also contain multiple SSH (v2) public keys. SSH protocol version 1 is not supported. `ENABLE_ROOT` **and** `SSH_ENABLE_ROOT` must be set to `true`.

##### `SSH_USER_PUB_KEY`=""
Add SSH (v2) public key(s) from specified file to `authorized_keys` file to enable public key based SSH (v2) authentication of user `USER_NAME`=pi. The specified file can also contain multiple SSH (v2) public keys. SSH protocol version 1 is not supported.

---

#### Kernel compilation:
##### `BUILD_KERNEL`=true
Build and install the latest RPi2/3 Linux kernel. Currently only the default RPi2/3 kernel configuration is used.

##### `CROSS_COMPILE`="arm-linux-gnueabihf-"
This sets the cross compile enviornment for the compiler.

##### `KERNEL_ARCH`="arm"
This sets the kernel architecture for the compiler.

##### `KERNEL_IMAGE`="kernel7.img"
Name of the image file in the boot partition. If not set, `KERNEL_IMAGE` will be set to "kernel8.img" automatically if building for arm64.

##### `KERNEL_BRANCH`=""
Name of the requested branch from the GIT location for the RPi Kernel. Default is using the current default branch from the GIT site.

##### `QEMU_BINARY`="/usr/bin/qemu-arm-static"
Sets the QEMU enviornment for the Debian archive. If not set, `QEMU_BINARY` will be set to "/usr/bin/qemu-aarch64-static" automatically if building for arm64.

##### `KERNEL_DEFCONFIG`="bcm2709_defconfig"
Sets the default config for kernel compiling. If not set, `KERNEL_DEFCONFIG` will be set to "bcmrpi3\_defconfig" automatically if building for arm64.

##### `KERNEL_REDUCE`=false
Reduce the size of the generated kernel by removing unwanted device, network and filesystem drivers (experimental).

##### `KERNEL_THREADS`=1
Number of parallel kernel building threads. If the parameter is left untouched the script will automatically determine the number of CPU cores to set the number of parallel threads to speed the kernel compilation.

##### `KERNEL_HEADERS`=true
Install kernel headers with built kernel.

##### `KERNEL_MENUCONFIG`=false
Start `make menuconfig` interactive menu-driven kernel configuration. The script will continue after `make menuconfig` was terminated.

##### `KERNEL_OLDDEFCONFIG`=false
Run `make olddefconfig` to automatically set all new kernel configuration options to their recommended default values.

##### `KERNEL_CCACHE`=false
Compile the kernel using ccache. This speeds up kernel recompilation by caching previous compilations and detecting when the same compilation is being done again.

##### `KERNEL_REMOVESRC`=true
Remove all kernel sources from the generated OS image after it was built and installed.

##### `KERNELSRC_DIR`=""
Path to a directory (`linux`) of [RaspberryPi Linux kernel sources](https://github.com/raspberrypi/linux) that will be copied, configured, build and installed inside the chroot.

##### `KERNELSRC_CLEAN`=false
Clean the existing kernel sources directory `KERNELSRC_DIR` (using `make mrproper`) after it was copied to the chroot and before the compilation of the kernel has started. This parameter will be ignored if no `KERNELSRC_DIR` was specified or if `KERNELSRC_PREBUILT`=true.

##### `KERNELSRC_CONFIG`=true
Run `make bcm2709_defconfig` (and optional `make menuconfig`) to configure the kernel sources before building. This parameter is automatically set to `true` if no existing kernel sources directory was specified using `KERNELSRC_DIR`. This parameter is ignored if `KERNELSRC_PREBUILT`=true.

##### `KERNELSRC_USRCONFIG`=""
Copy own config file to kernel `.config`. If `KERNEL_MENUCONFIG`=true then running after copy.

##### `KERNELSRC_PREBUILT`=false
With this parameter set to true the script expects the existing kernel sources directory to be already successfully cross-compiled. The parameters `KERNELSRC_CLEAN`, `KERNELSRC_CONFIG`, `KERNELSRC_USRCONFIG` and `KERNEL_MENUCONFIG` are ignored and no kernel compilation tasks are performed.

##### `RPI_FIRMWARE_DIR`=""
The directory (`firmware`) containing a local copy of the firmware from the [RaspberryPi firmware project](https://github.com/raspberrypi/firmware). Default is to download the latest firmware directly from the project.

---

#### Reduce disk usage:
The following list of parameters is ignored if `ENABLE_REDUCE`=false.

##### `REDUCE_APT`=true
Configure APT to use compressed package repository lists and no package caching files.

##### `REDUCE_DOC`=true
Remove all doc files (harsh). Configure APT to not include doc files on future `apt-get` package installations.

##### `REDUCE_MAN`=true
Remove all man pages and info files (harsh).  Configure APT to not include man pages on future `apt-get` package installations.

##### `REDUCE_VIM`=false
Replace `vim-tiny` package by `levee` a tiny vim clone.

##### `REDUCE_BASH`=false
Remove `bash` package and switch to `dash` shell (experimental).

##### `REDUCE_HWDB`=true
Remove PCI related hwdb files (experimental).

##### `REDUCE_SSHD`=true
Replace `openssh-server` with `dropbear`.

##### `REDUCE_LOCALE`=true
Remove all `locale` translation files.

---

#### Encrypted root partition:
##### `ENABLE_CRYPTFS`=false
Enable full system encryption with dm-crypt. Setup a fully LUKS encrypted root partition (aes-xts-plain64:sha512) and generate required initramfs. The /boot directory will not be encrypted. This parameter will be ignored if `BUILD_KERNEL`=false. `ENABLE_CRYPTFS` is experimental. SSH-to-initramfs is currently not supported but will be soon - feel free to help.

##### `CRYPTFS_PASSWORD`=""
Set password of the encrypted root partition. This parameter is mandatory if `ENABLE_CRYPTFS`=true.

##### `CRYPTFS_MAPPING`="secure"
Set name of dm-crypt managed device-mapper mapping.

##### `CRYPTFS_CIPHER`="aes-xts-plain64:sha512"
Set cipher specification string. `aes-xts*` ciphers are strongly recommended.

##### `CRYPTFS_XTSKEYSIZE`=512
Sets key size in bits. The argument has to be a multiple of 8.

---

#### Build settings:
##### `BASEDIR`=$(pwd)/images/${RELEASE}
Set a path to a working directory used by the script to generate an image.

##### `IMAGE_NAME`=${BASEDIR}/${DATE}-${KERNEL_ARCH}-${KERNEL_BRANCH}-rpi${RPI_MODEL}-${RELEASE}-${RELEASE_ARCH}
Set a filename for the output file(s). Note: the script will create $IMAGE_NAME.img if `ENABLE_SPLITFS`=false or $IMAGE_NAME-frmw.img and $IMAGE_NAME-root.img if `ENABLE_SPLITFS`=true. Note 2: If the KERNEL_BRANCH is not set, the word "CURRENT" is used.

## Understanding the script
The functions of this script that are required for the different stages of the bootstrapping are split up into single files located inside the `bootstrap.d` directory. During the bootstrapping every script in this directory gets executed in lexicographical order:

| Script | Description |
| --- | --- |
| `10-bootstrap.sh` | Debootstrap basic system |
| `11-apt.sh` | Setup APT repositories |
| `12-locale.sh` | Setup Locales and keyboard settings |
| `13-kernel.sh` | Build and install RPi2/3 Kernel |
| `14-fstab.sh` | Setup fstab and initramfs |
| `15-rpi-config.sh` | Setup RPi2/3 config and cmdline |
| `20-networking.sh` | Setup Networking |
| `21-firewall.sh` | Setup Firewall |
| `30-security.sh` | Setup Users and Security settings |
| `31-logging.sh` | Setup Logging |
| `32-sshd.sh` | Setup SSH and public keys |
| `41-uboot.sh` | Build and Setup U-Boot |
| `42-fbturbo.sh` | Build and Setup fbturbo Xorg driver |
| `50-firstboot.sh` | First boot actions |
| `99-reduce.sh` | Reduce the disk space usage |

All the required configuration files that will be copied to the generated OS image are located inside the `files` directory. It is not recommended to modify these configuration files manually.

| Directory | Description |
| --- | --- |
| `apt` | APT management configuration files |
| `boot` | Boot and RPi2/3 configuration files |
| `dpkg` | Package Manager configuration |
| `etc` | Configuration files and rc scripts |
| `firstboot` | Scripts that get executed on first boot  |
| `initramfs` | Initramfs scripts |
| `iptables` | Firewall configuration files |
| `locales` | Locales configuration |
| `modules` | Kernel Modules configuration |
| `mount` | Fstab configuration |
| `network` | Networking configuration files |
| `sysctl.d` | Swapping and Network Hardening configuration |
| `xorg` | fbturbo Xorg driver configuration |

## Custom packages and scripts
Debian custom packages, i.e. those not in the debian repositories, can be installed by placing them in the `packages` directory. They are installed immediately after packages from the repositories are installed. Any dependencies listed in the custom packages will be downloaded automatically from the repositories. Do not list these custom packages in `APT_INCLUDES`.

Scripts in the custom.d directory will be executed after all other installation is complete but before the image is created.

## Logging of the bootstrapping process
All information related to the bootstrapping process and the commands executed by the `rpi23-gen-image.sh` script can easily be saved into a logfile. The common shell command `script` can be used for this purpose:

```shell
script -c 'APT_SERVER=ftp.de.debian.org ./rpi23-gen-image.sh' ./build.log
```

## Flashing the image file
After the image file was successfully created by the `rpi23-gen-image.sh` script it can be copied to the microSD card that will be used by the RPi2/3 computer. This can be performed by using the tools `bmaptool` or `dd`. Using `bmaptool` will probably speed-up the copy process because `bmaptool` copies more wisely than `dd`.

##### Flashing examples:
```shell
bmaptool copy ./images/buster/2017-01-23-rpi3-buster.img /dev/mmcblk0
dd bs=4M if=./images/buster/2017-01-23-rpi3-buster.img of=/dev/mmcblk0
```
If you have set `ENABLE_SPLITFS`, copy the `-frmw` image on the microSD card, then the `-root` one on the USB drive:
```shell
bmaptool copy ./images/buster/2017-01-23-rpi3-buster-frmw.img /dev/mmcblk0
bmaptool copy ./images/buster/2017-01-23-rpi3-buster-root.img /dev/sdc
```

## QEMU emulation
Start QEMU full system emulation:
```shell
qemu-system-arm -m 2048M -M vexpress-a15 -cpu cortex-a15 -kernel kernel7.img -no-reboot -dtb vexpress-v2p-ca15_a7.dtb -sd ${IMAGE_NAME}.qcow2 -append "root=/dev/mmcblk0p2 rw rootfstype=ext4 console=tty1"
```

Start QEMU full system emulation and output to console:
```shell
qemu-system-arm -m 2048M -M vexpress-a15 -cpu cortex-a15 -kernel kernel7.img -no-reboot -dtb vexpress-v2p-ca15_a7.dtb -sd ${IMAGE_NAME}.qcow2 -append "root=/dev/mmcblk0p2 rw rootfstype=ext4 console=ttyAMA0,115200 init=/bin/systemd" -serial stdio
```

Start QEMU full system emulation with SMP and output to console:
```shell
qemu-system-arm -m 2048M -M vexpress-a15 -cpu cortex-a15 -smp cpus=2,maxcpus=2 -kernel kernel7.img -no-reboot -dtb vexpress-v2p-ca15_a7.dtb -sd ${IMAGE_NAME}.qcow2 -append "root=/dev/mmcblk0p2 rw rootfstype=ext4 console=ttyAMA0,115200 init=/bin/systemd" -serial stdio
```

Start QEMU full system emulation with cryptfs, initramfs and output to console:
```shell
qemu-system-arm -m 2048M -M vexpress-a15 -cpu cortex-a15 -kernel kernel7.img -no-reboot -dtb vexpress-v2p-ca15_a7.dtb -sd ${IMAGE_NAME}.qcow2 -initrd "initramfs-${KERNEL_VERSION}" -append "root=/dev/mapper/secure cryptdevice=/dev/mmcblk0p2:secure rw rootfstype=ext4 console=ttyAMA0,115200 init=/bin/systemd" -serial stdio
```

## External links and references
* [Debian worldwide mirror sites](https://www.debian.org/mirror/list)
* [Debian Raspberry Pi 2 Wiki](https://wiki.debian.org/RaspberryPi2)
* [Debian CrossToolchains Wiki](https://wiki.debian.org/CrossToolchains)
* [Official Raspberry Pi Firmware on github](https://github.com/raspberrypi/firmware)
* [Official Raspberry Pi Kernel on github](https://github.com/raspberrypi/linux)
* [U-BOOT git repository](https://git.denx.de/?p=u-boot.git;a=summary)
* [Xorg DDX driver fbturbo](https://github.com/ssvb/xf86-video-fbturbo)
* [RPi3 Wireless interface firmware](https://github.com/RPi-Distro/firmware-nonfree/tree/master/brcm80211/brcm)
* [Collabora RPi2 Kernel precompiled](https://repositories.collabora.co.uk/debian/)
