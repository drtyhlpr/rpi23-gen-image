# rpi23-gen-image
## Introduction
`rpi23-gen-image.sh` is an advanced Debian Linux bootstrapping shell script for generating Debian OS images for Raspberry Pi 2 (RPi2) and Raspberry Pi 3 (RPi3) computers. The script at this time supports the bootstrapping of the Debian (armhf) releases `jessie`, `stretch` and `buster`. Raspberry Pi 3 images are generated for 32-bit mode only. Raspberry Pi 3 64-bit images can be generated using custom configuration parameters (```templates/rpi3-stretch-arm64-4.11.y```).

## Build dependencies
The following list of Debian packages must be installed on the build system because they are essentially required for the bootstrapping process. The script will check if all required packages are installed and missing packages will be installed automatically if confirmed by the user.

  ```debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git bc psmisc dbus sudo```

It is recommended to configure the `rpi23-gen-image.sh` script to build and install the latest Raspberry Pi Linux kernel. For the RPi3 this is mandatory. Kernel compilation and linking will be performed on the build system using an ARM (armhf) cross-compiler toolchain.

The script has been tested using the default `crossbuild-essential-armhf` toolchain meta package on Debian Linux `jessie` and `stretch` build systems. Please check the [Debian CrossToolchains Wiki](https://wiki.debian.org/CrossToolchains) for further information.

If a Debian Linux `jessie` build system is used it will be required to add the [Debian Cross-toolchains repository](http://emdebian.org/tools/debian/) first:

```
echo "deb http://emdebian.org/tools/debian/ jessie main" > /etc/apt/sources.list.d/crosstools.list
sudo -u nobody wget -O - http://emdebian.org/tools/debian/emdebian-toolchain-archive.key | apt-key add -
dpkg --add-architecture armhf
apt-get update
```

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
Set Proxy server address. Using a local Proxy-Cache like `apt-cacher-ng` will speed-up the bootstrapping process because all required Debian packages will only be downloaded from the Debian mirror site once.

##### `APT_INCLUDES`=""
A comma separated list of additional packages to be installed by debootstrap during bootstrapping.

##### `APT_INCLUDES_LATE`=""
A comma separated list of additional packages to be installed by apt after bootstrapping and after APT sources are set up.  This is useful for packages with pre-depends, which debootstrap do not handle well.

---

#### General system settings:
##### `RPI_MODEL`=2
Specifiy the target Raspberry Pi hardware model. The script at this time supports the Raspberry Pi models `2` and `3`. `BUILD_KERNEL`=true will automatically be set if the Raspberry Pi model `3` is used.

##### `RELEASE`="jessie"
Set the desired Debian release name. The script at this time supports the bootstrapping of the Debian releases "jessie", "stretch" and "buster". `BUILD_KERNEL`=true will automatically be set if the Debian releases `stretch` or `buster` are used.

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
Enable I2C interface on the RPi2/3. Please check the [RPi2/3 pinout diagrams](http://elinux.org/RPi_Low-level_peripherals) to connect the right GPIO pins.

##### `ENABLE_SPI`=false
Enable SPI interface on the RPi2/3. Please check the [RPi2/3 pinout diagrams](http://elinux.org/RPi_Low-level_peripherals) to connect the right GPIO pins.

##### `ENABLE_IPV6`=true
Enable IPv6 support. The network interface configuration is managed via systemd-networkd.

##### `ENABLE_SSHD`=true
Install and enable OpenSSH service. The default configuration of the service doesn't allow `root` to login. Please use the user `pi` instead and `su -` or `sudo` to execute commands as root.

##### `ENABLE_NONFREE`=false
Allow the installation of non-free Debian packages that do not comply with the DFSG. This is required to install closed-source firmware binary blobs.

##### `ENABLE_WIRELESS`=false
Download and install the [closed-source firmware binary blob](https://github.com/RPi-Distro/firmware-nonfree/tree/master/brcm80211/brcm) that is required to run the internal wireless interface of the Raspberry Pi model `3`. This parameter is ignored if the specified `RPI_MODEL` is not `3`.

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

---

#### Advanced system features:
##### `ENABLE_MINBASE`=false
Use debootstrap script variant `minbase` which only includes essential packages and apt. This will reduce the disk usage by about 65 MB.

##### `ENABLE_REDUCE`=false
Reduce the disk space usage by deleting packages and files. See `REDUCE_*` parameters for detailed information.

##### `ENABLE_UBOOT`=false
Replace the default RPi2/3 second stage bootloader (bootcode.bin) with [U-Boot bootloader](http://git.denx.de/?p=u-boot.git;a=summary). U-Boot can boot images via the network using the BOOTP/TFTP protocol.

##### `UBOOTSRC_DIR`=""
Path to a directory (`u-boot`) of [U-Boot bootloader sources](http://git.denx.de/?p=u-boot.git;a=summary) that will be copied, configured, build and installed inside the chroot.

##### `ENABLE_FBTURBO`=false
Install and enable the [hardware accelerated Xorg video driver](https://github.com/ssvb/xf86-video-fbturbo) `fbturbo`. Please note that this driver is currently limited to hardware accelerated window moving and scrolling.

##### `FBTURBOSRC_DIR`=""
Path to a directory (`xf86-video-fbturbo`) of [hardware accelerated Xorg video driver sources](https://github.com/ssvb/xf86-video-fbturbo) that will be copied, configured, build and installed inside the chroot.

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
Enable automatic assignment of predictable, stable network interface names for all local Ethernet, WLAN interfaces. This might create complex and long interface names. This parameter is only supported if the Debian releases `stretch` or `buster` are used.

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
##### `BUILD_KERNEL`=false
Build and install the latest RPi2/3 Linux kernel. Currently only the default RPi2/3 kernel configuration is used. `BUILD_KERNEL`=true will automatically be set if the Raspberry Pi model `3` is used.

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
bmaptool copy ./images/jessie/2017-01-23-rpi3-jessie.img /dev/mmcblk0
dd bs=4M if=./images/jessie/2017-01-23-rpi3-jessie.img of=/dev/mmcblk0
```
If you have set `ENABLE_SPLITFS`, copy the `-frmw` image on the microSD card, then the `-root` one on the USB drive:
```shell
bmaptool copy ./images/jessie/2017-01-23-rpi3-jessie-frmw.img /dev/mmcblk0
bmaptool copy ./images/jessie/2017-01-23-rpi3-jessie-root.img /dev/sdc
```
## Weekly image builds
The image files are provided by JRWR'S I/O PORT and are built once a Sunday at midnight UTC!
* [Debian Stretch Raspberry Pi2/3 Weekly Image Builds](https://jrwr.io/doku.php?id=projects:debianpi)

## External links and references
* [Debian worldwide mirror sites](https://www.debian.org/mirror/list)
* [Debian Raspberry Pi 2 Wiki](https://wiki.debian.org/RaspberryPi2)
* [Debian CrossToolchains Wiki](https://wiki.debian.org/CrossToolchains)
* [Official Raspberry Pi Firmware on github](https://github.com/raspberrypi/firmware)
* [Official Raspberry Pi Kernel on github](https://github.com/raspberrypi/linux)
* [U-BOOT git repository](http://git.denx.de/?p=u-boot.git;a=summary)
* [Xorg DDX driver fbturbo](https://github.com/ssvb/xf86-video-fbturbo)
* [RPi3 Wireless interface firmware](https://github.com/RPi-Distro/firmware-nonfree/tree/master/brcm80211/brcm)
* [Collabora RPi2 Kernel precompiled](https://repositories.collabora.co.uk/debian/)



## 介绍
`rpi23-gen-image.sh` 是一个自动生成树莓派2/3系统镜像的脚本工具, 当前支持自动生成32位 armhf 架构的Debian, 发行版本`jessie`, `stretch` 和 `buster`. 树莓派3 64位镜像需要使用特定的配置参数 (```templates/rpi3-stretch-arm64-4.11.y```). 

## 构建环境所依赖的包
一定要安装好下列deb包, 他们是构建过程需要的核心包. 脚本会自动检查, 如果缺少,经用户确认后会自动安装. 

  ```debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git bc psmisc dbus sudo```

推荐通过配置 `rpi23-gen-image.sh` 脚本编译安装最新的树莓派 Linux 内核, 对于树莓派3, 只能如此. 在构建系统上使用 ARM (armhf) 交叉编译工具链编译内核. 

脚本已经在Debian Liux `jessie` 和`stretch` 构建系统下使用默认的 `crossbuild-essential-armhf` 工具链进行过测试. 获取更多信息请查看 [Debian 交叉工具链 Wiki](https://wiki.debian.org/CrossToolchains) . 

如果使用Debian Linux `jessie` 构建系统, 先要添加交叉编译工具链的源 [Debian 交叉工具链仓库](http://emdebian.org/tools/debian/):

```
echo "deb http://emdebian.org/tools/debian/ jessie main" > /etc/apt/sources.list.d/crosstools.list
sudo -u nobody wget -O - http://emdebian.org/tools/debian/emdebian-toolchain-archive.key | apt-key add -
dpkg --add-architecture armhf
apt-get update
```

## 命令行参数
脚本可以使用特定的命令行参数来允许或禁止操作系统的某些特性、服务和配置信息. 这些参数通过（简单）脚本变量传递给 `rpi23-gen-image.sh`. 不同于环境变量, （简单）脚本变量在调用`rpi23-gen-image.sh`的命令行前面定义. 

##### 命令行示例:
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

## 参数模板文件
为了避免冗长的命令行参数以及存储感兴趣的参数配置, `rpi23-gen-image.sh` 支持所谓的参数模板文件 (`CONFIG_TEMPLATE`=template). 这些文本文件位于 `./templates` 目录, 文件中含有将会使用的配置参数. 新的配置模板文件会被添加到 `./templates` 目录.

##### 命令行示例:
```shell
CONFIG_TEMPLATE=rpi3stretch ./rpi23-gen-image.sh
CONFIG_TEMPLATE=rpi2stretch ./rpi23-gen-image.sh
```

## 支持的参数和设置
#### APT 设置:
##### `APT_SERVER`="ftp.debian.org"
设置 Debian 仓库地址. 选择一个 [镜像站点](https://www.debian.org/mirror/list). 选一个近的镜像站点会加快镜像生成过程中所需文件的下载速度.

##### `APT_PROXY`=""
设置代理服务器地址. 使用本地缓存代理, 比如 `apt-cacher-ng` 可以缩短镜像生成时间, 因为所需要的 Debian 包文件只需下载一次. 

##### `APT_INCLUDES`=""
生成镜像过程中最先由debootstrap程序自动安装的附加包, 逗号分隔. 

##### `APT_INCLUDES_LATE`=""
生成镜像过程中最初的debootstrap完成后, 需要的使用apt命令安装的附加包, 逗号分隔. 特别用在含有 pre-depend 依赖关系的包的, 其依赖关系在打包过程中debootstrap程序中无法正确处理. 

---

#### 通用系统设置:
##### `RPI_MODEL`=2
指定树莓派型号. 当前支持树莓派 `2` 和 `3`. 设为 `3` 时 `BUILD_KERNEL` 自动设为true .

##### `RELEASE`="jessie"
设置 Debian 发行版. 脚本当前支持 Debian 发行版 "jessie", "stretch" 和 "buster" 的自动生成. 设为`stretch` 或 `buster`时 `BUILD_KERNEL` 自动设为true. 

##### `RELEASE_ARCH`="armhf"
设置期望的 Debian 发行架构.

##### `HOSTNAME`="rpi$RPI_MODEL-$RELEASE"
设置系统的主机名. 建议所在的子网中主机名是唯一的.

##### `PASSWORD`="raspberry"
设置系统的 `root` 用户密码.  **强烈**建议选择一个自定义密码 .

##### `USER_PASSWORD`="raspberry"
设置由 `USER_NAME`=pi 参数创建的普通用户的密码.  如果 `ENABLE_USER`=false 则忽略. **强烈**建议选择一个自定义密码.

##### `DEFLOCAL`="en_US.UTF-8"
设置系统默认 locale.  将来可以在运行的系统中执行 `dpkg-reconfigure locales` 命令更改此项设置. 设置这项脚本会自动安装 `locales`, `keyboard-configuration` 和 `console-setup` 三个包.

##### `TIMEZONE`="Europe/Berlin"
设置系统默认时区.  可以在`/usr/share/zoneinfo/` 目录中找到全部可用时区. 将来可以在运行的系统中执行 `dpkg-reconfigure tzdata` 命令更改此项设置.

##### `EXPANDROOT`=true
第一次运行时自动扩展根分区和文件系统. 

---

#### 键盘设置:
这些选项用来配置键盘布局文件 `/etc/default/keyboard` 影响控制台和X窗口. 将来可以在运行的系统中执行 `dpkg-reconfigure keyboard-configuration` 命令更改此项设置.

##### `XKB_MODEL`=""
设置键盘类型, 大陆常见pc104.

##### `XKB_LAYOUT`=""
设置键盘布局, 大陆常见us.

##### `XKB_VARIANT`=""
设置键盘布局变种.

##### `XKB_OPTIONS`=""
设置其它 XKB 配置选项.

---

#### 网络设置 (动态):
设置网络为自动获取IP地址. 配置文件位于 `/etc/systemd/network/eth.network`. 在Debian `stretch`中, 默认位置更改为 `/lib/systemd/network`.

##### `ENABLE_DHCP`=true
设置系统使用 DHCP 获取动态IP. 需要有一个 DHCP 服务器.

---

#### 网络设置 (静态):
设置系统为手动配置IP地址. 配置文件位于 `/etc/systemd/network/eth.network`. 在Debian `stretch` 中, 默认位置更改为 `/lib/systemd/network`.
当 `ENABLE_DHCP`=false 时下面这些静态IP设置才起作用. 

##### `NET_ADDRESS`=""
设置静态 IPv4 或 IPv6, 使用CIDR "/"形式, 如 "192.169.0.3/24".

##### `NET_GATEWAY`=""
设置默认网关的地址. 

##### `NET_DNS_1`=""
设置主域名服务器地址. 

##### `NET_DNS_2`=""
设置辅域名服务器地址. 

##### `NET_DNS_DOMAINS`=""
设置默认的域名搜索后缀, 当主机名称不是一个完整域名(FQDN)时使用. 

##### `NET_NTP_1`=""
设置主时间服务器地址. 

##### `NET_NTP_2`=""
设置辅时间服务器地址. 

---

#### 基本系统特性:
##### `ENABLE_CONSOLE`=true
允许串行控制台接口. 没有连接显示器键盘的树莓派推荐打开, 此时如果网络无法连接至树莓派, 可以使用串行控制台连至系统. 

##### `ENABLE_I2C`=false
允许树莓派2/3的 I2C 接口. 请对照 [树莓派2/3 引脚示意图](http://elinux.org/RPi_Low-level_peripherals) 正确连接 GPIO 引脚.

##### `ENABLE_SPI`=false
允许树莓派2/3的 SPI 接口. 请对照 [树莓派2/3 引脚示意图](http://elinux.org/RPi_Low-level_peripherals) 正确连接 GPIO 引脚.

##### `ENABLE_IPV6`=true
允许 IPv6 . 通过 systemd-networkd 配置管理网络接口.

##### `ENABLE_SSHD`=true
安装并且允许 OpenSSH 服务. 此服务默认禁止 `root` 用户远程登录. 使用普通用户 `pi` 远程登录然后使用 `su -` 或 `sudo` 来取得root权限.

##### `ENABLE_NONFREE`=false
允许安装仓库中的 non-free 类的软件包. 需要安装闭源的固件, 二进制大对象 blob. 

##### `ENABLE_WIRELESS`=false
下载安装树莓派3无线接口所需要的闭源固件 二进制blob [树莓派3无线接口固件](https://github.com/RPi-Distro/firmware-nonfree/tree/master/brcm80211/brcm). 如果 `RPI_MODEL` 不是 `3` 则忽略.

##### `ENABLE_RSYSLOG`=true
如果设置为 false, 禁用并卸载 rsyslog,  则只能通过日志文件查看logs. 

##### `ENABLE_SOUND`=true
允许声卡并且安装 ALSA.

##### `ENABLE_HWRANDOM`=true
允许硬件随机数发生器. 强随机数对大多数使用加密的网络通信是非常重要的. 推荐允许此设置. 

##### `ENABLE_MINGPU`=false
最小化显存 (16MB, no X), 目前无法完全禁用GPU.

##### `ENABLE_DBUS`=true
安装并允许 D-Bus 消息总线.  虽然 systemd 可以在没有 D-bus的情况下工作, 但是推荐允许D-Bus.

##### `ENABLE_XORG`=false
是否安装 Xorg, 开源 X11 系统.

##### `ENABLE_WM`=""
安装用户指定的X Window 窗口管理器. 如果设置了`ENABLE_WM`, 系统确定所有被依赖的X11相关软件包都安装好了以后`ENABLE_XORG`会自动设置为true,  `rpi23-gen-image.sh` 脚本已经通过下列窗口管理器的测试: `blackbox`, `openbox`, `fluxbox`, `jwm`, `dwm`, `xfce4`, `awesome`.

---

#### 高级系统特性:
##### `ENABLE_MINBASE`=false
使用 debootstrap 脚本变量 `minbase`, 只含有必不可少的核心包和apt. 体积大约 65 MB.

##### `ENABLE_REDUCE`=false
卸载包、删除文件以减小体积 详情查看 `REDUCE_*` 参数.

##### `ENABLE_UBOOT`=false
使用 [U-Boot](http://git.denx.de/?p=u-boot.git;a=summary) 替代树莓派2/3 默认的第二阶段引导器(bootcode.bin).  U-Boot 可以通过网络使用 BOOTP/TFTP 协议引导镜像文件.

##### `UBOOTSRC_DIR`=""
存放已下载 [U-Boot 源文件](http://git.denx.de/?p=u-boot.git;a=summary) 的目录(`u-boot`).

##### `ENABLE_FBTURBO`=false
安装并且允许 [硬件加速的 Xorg 显卡驱动](https://github.com/ssvb/xf86-video-fbturbo) `fbturbo`. 当前仅支持窗口的移动和滚动的硬件加速.

##### `FBTURBOSRC_DIR`=""
设置存放已下载的 [硬件加速的 Xorg 显卡驱动](https://github.com/ssvb/xf86-video-fbturbo) 的目录 (`xf86-video-fbturbo`) , 可以复制到chroot内配置、构建和安装.

##### `ENABLE_IPTABLES`=false
允许 iptables 防火墙. 使用最简单的规则集: 允许所有出站连接;禁止除OpenSSH外的所有入站连接.

##### `ENABLE_USER`=true
创建普通用户, 默认用户名`pi`, 默认密码raspberry.  可以使用 `USER_NAME`=user 更改默认用户名;使用 `USER_PASSWORD`=raspberry 更改默认密码. 

##### `USER_NAME`=pi
创建普通用户pi. 如果`ENABLE_USER`=false 此参数被忽略. 

##### `ENABLE_ROOT`=false
允许root用户登录, 需要设置 root 用户密码.

##### `ENABLE_HARDNET`=false
允许加固 IPv4/IPv6 协议栈, 防止DoS攻击.

##### `ENABLE_SPLITFS`=false
允许将根分区放在USB驱动器中. 将会生成两个镜像文件, 一个挂载为 `/boot/firmware` , 另一个挂载为 `/`.

##### `CHROOT_SCRIPTS`=""
设置自定义脚本目录的路径, 该目录中的脚本在镜像文件构建完成之前在chroot中运行. 这个目录里的可执行文件按着字典序运行.

##### `ENABLE_INITRAMFS`=false
创建 Linux 启动时加载的 initramfs .如果 `ENABLE_CRYPTFS`=true 那么 `ENABLE_INITRAMFS` 自动设为true . 如果 `BUILD_KERNEL`=false 此参数被忽略.

##### `ENABLE_IFNAMES`=true
允许一致/可预测网络接口命名, 支持 Debian 发行版 `stretch` 或 `buster` .

##### `DISABLE_UNDERVOLT_WARNINGS`=
禁止树莓派2/3 的低电压警告. 设为 `1` 禁止警告. 设为 `2` 额外允许低电压下的turbo增强模式. 

---

#### SSH 设置:
##### `SSH_ENABLE_ROOT`=false
允许root通过密码验证方式远程登录系统. 如果没有修改默认密码, 这将是个巨大的安全隐患. `ENABLE_ROOT` 必须设为 `true`.

##### `SSH_DISABLE_PASSWORD_AUTH`=false
禁用SSH的密码验证方式, 只支持SSH (v2)的公钥认证.

##### `SSH_LIMIT_USERS`=false
限制通过SSH远程登录的用户. 只允许由 `USER_NAME`=pi 参数创建的普通用户, 以及当 `SSH_ENABLE_ROOT`=true 时 root 用户远程登录. 如果使用的守护程序是 `dropbear` (通过 `REDUCE_SSHD`=true 设置) 则忽略此参数.

##### `SSH_ROOT_PUB_KEY`=""
从指定文件(可包含多个公钥)添加 SSH (v2) 公钥到 `authorized_keys` 文件, 使得 `root` 用户可以使用SSH (v2)的公钥验证方式远程登录, 不支持SSH (v1).  `ENABLE_ROOT` **和** `SSH_ENABLE_ROOT` 必须同时设为 `true`.

##### `SSH_USER_PUB_KEY`=""
从指定文件(可包含多个公钥)添加 SSH (v2) 公钥到 `authorized_keys` 文件, 使得由 `USER_NAME`=pi 参数创建的普通用户可以使用SSH (v2)的公钥验证方式远程登录, 不支持SSH (v1).

---

#### 内核编译:
##### `BUILD_KERNEL`=false
构建安装最新的树莓派 2/3 Linux 内核, 当前只支持默认内核配置. 如果设置为树莓派`3`那么自动设置`BUILD_KERNEL`=true .

##### `CROSS_COMPILE`="arm-linux-gnueabihf-"
设置交叉编译器.

##### `KERNEL_ARCH`="arm"
设置内核架构.

##### `KERNEL_IMAGE`="kernel7.img"
内核镜像名称, 如果没有设置, 编译32位内核默认“kernel7.img” 64位内核默认 "kernel8.img".

##### `KERNEL_BRANCH`=""
GIT里的树莓派内核源代码分支名称, 默认使用当前默认分支.

##### `QEMU_BINARY`="/usr/bin/qemu-arm-static"
设置构建系统中的QEMU程序位置. 如果没有设置, 32位内核默认 “/usr/bin/qemu-arm-static” 64位内核默认 "/usr/bin/qemu-aarch64-static". 

##### `KERNEL_DEFCONFIG`="bcm2709_defconfig"
设置编译内核的默认配置. 如果没有设置, 32位内核默认"bcm2709_defconfig" 64位内核默认"bcmrpi3\_defconfig".

##### `KERNEL_REDUCE`=false
缩小内核体积, 移除不想要的设备驱动、网络驱动和文件系统驱动 (实验性质).

##### `KERNEL_THREADS`=1
编译内核时的并发线程数量. 如果使用默认设置, 系统会自动检测CPU的内核数量, 设置线程数量, 加速内核编译. 

##### `KERNEL_HEADERS`=true
安装内核相应的头文件. 

##### `KERNEL_MENUCONFIG`=false
运行`make menuconfig`使用菜单界面配置内核. 退出配置菜单后脚本继续运行.

##### `KERNEL_REMOVESRC`=true
编译安装完成后, 删掉内核源代码, 产生的镜像不含内核源代码.

##### `KERNELSRC_DIR`=""
已下载好的 [Github上的树莓派官方内核](https://github.com/raspberrypi/linux) 源码所在目录 (`linux`) 的路径, 可以复制到chroot内配置、构建和安装.

##### `KERNELSRC_CLEAN`=false
当`KERNELSRC_DIR`被复制到 chroot 之后开始编译之前(使用 `make mrproper`)清理内核源代码. 如果 `KERNELSRC_DIR` 没有设置或者 `KERNELSRC_PREBUILT`=true时忽略此设置.

##### `KERNELSRC_CONFIG`=true
在编译前使用 `make bcm2709_defconfig` (也可以选择 `make menuconfig`) 配置内核源代码. 如果`KERNELSRC_DIR`指定的源码存放目录不存在,这个参数自动设为 `true` . 如果 `KERNELSRC_PREBUILT`=true 忽略此参数.

##### `KERNELSRC_USRCONFIG`=""
复制自己的配置文件到内核的 `.config`. 如果 `KERNEL_MENUCONFIG`=true 拷贝完成后自动运行 make menuconfig.

##### `KERNELSRC_PREBUILT`=false
如果这个参数设为true 表示内核源代码目录中包含成功交叉编译好的内核. 忽略 `KERNELSRC_CLEAN`, `KERNELSRC_CONFIG`, `KERNELSRC_USRCONFIG` and `KERNEL_MENUCONFIG` 这四个参数,不再执行交叉编译操作.

##### `RPI_FIRMWARE_DIR`=""
指定目录 (`firmware`) 含有已经从 [Github上的树莓派官方固件](https://github.com/raspberrypi/firmware)下载到本地的固件. 默认直接从网上下载最新的固件.

---

#### 缩小体积:
如果 `ENABLE_REDUCE`=false 则忽略下列参数.

##### `REDUCE_APT`=true
配置 APT,压缩仓库文件列表,不缓存下载的包文件.

##### `REDUCE_DOC`=true
移除所有的doc文档文件(harsh). 配置 APT, 将来使用`apt-get`安装deb包时不包括doc文件.

##### `REDUCE_MAN`=true
移除所有的man手册页和info文件 (harsh).  配置 APT, 将来使用`apt-get`安装deb包时不包括 man 文件.

##### `REDUCE_VIM`=false
使用vim的小型克隆 `levee` 替代 `vim-tiny`.

##### `REDUCE_BASH`=false
使用 `dash` 代替 `bash` (实验性质).

##### `REDUCE_HWDB`=true
移除与 PCI 相关的 hwdb 文件 (实验性质).

##### `REDUCE_SSHD`=true
使用`dropbear`代替 `openssh-server`.

##### `REDUCE_LOCALE`=true
移除所有的 `locale` 本地化文件.

---

#### 加密根分区:
##### `ENABLE_CRYPTFS`=false
使用dm-crypt进行全盘加密. 创建一个 LUKS 加密根分区 (加密方法 aes-xts-plain64:sha512) 并生成所需要的 initramfs.  /boot 目录不会被加密. 当`BUILD_KERNEL`=false时忽略此参数. `ENABLE_CRYPTFS` 这个参数当前是实验性质的. SSH-to-initramfs 当前不支持,正在进行中.

##### `CRYPTFS_PASSWORD`=""
设置根分区的加密密码. 如果 `ENABLE_CRYPTFS`=true,请务必设置此参数.

##### `CRYPTFS_MAPPING`="secure"
设置device-mapper映射名称.

##### `CRYPTFS_CIPHER`="aes-xts-plain64:sha512"
加密算法. 推荐 `aes-xts*`加密法.

##### `CRYPTFS_XTSKEYSIZE`=512
设置密钥长度,8的倍数,以bit为单位.

---

#### Build settings构建设置:
##### `BASEDIR`=$(pwd)/images/${RELEASE}
设置产生镜像的目录.

##### `IMAGE_NAME`=${BASEDIR}/${DATE}-${KERNEL_ARCH}-${KERNEL_BRANCH}-rpi${RPI_MODEL}-${RELEASE}-${RELEASE_ARCH}
设置镜像文件名. 如果`ENABLE_SPLITFS`=false则文件名$IMAGE_NAME.img 如果`ENABLE_SPLITFS`=true则文件名$IMAGE_NAME-frmw.img 和 $IMAGE_NAME-root.img. 如果没有设置 `KERNEL_BRANCH` 则使用 "CURRENT" .

## 理解脚本
制作镜像的每个阶段所实现的功能都由各自的脚本完成, 位于 `bootstrap.d` 目录. 按着字典序执行:

| 脚本 | 说明 |
| --- | --- |
| `10-bootstrap.sh` | 生成基本系统 |
| `11-apt.sh` | 设置 APT 仓库源 |
| `12-locale.sh` | 设置 Locales 和 keyboard |
| `13-kernel.sh` | 编译安装树莓派 2/3 内核 |
| `14-fstab.sh` | 设置 fstab 和 initramfs |
| `15-rpi-config.sh` | 设置 RPi2/3 config and cmdline |
| `20-networking.sh` | 设置网络 |
| `21-firewall.sh` | 设置防火墙 |
| `30-security.sh` | 设置用户以及安全相关 |
| `31-logging.sh` | 设置日志 |
| `32-sshd.sh` | 设置 SSH 和公钥 |
| `41-uboot.sh` | 编译设置 U-Boot |
| `42-fbturbo.sh` | 编译设置 fbturbo Xorg 驱动 |
| `50-firstboot.sh` | 首次启动执行的任务 |
| `99-reduce.sh` | 缩小体积 |

所有需要拷贝到镜像文件的配置文件都位于 `files` 目录. 最好不要手动更改这些配置文件.

| 目录 | 说明 |
| --- | --- |
| `apt` | APT 管理配置文件 |
| `boot` | 引导文件 树莓派2/3配置文件 |
| `dpkg` | 包管理配置文件 |
| `etc` | 配置文件以及 rc 启动脚本 |
| `firstboot` | 首次引导执行的脚本  |
| `initramfs` | Initramfs 脚本 |
| `iptables` | 防火墙配置文件 |
| `locales` | Locales 配置 |
| `modules` | 内核模块配置 |
| `mount` | Fstab 配置 |
| `network` | 网络配置文件 |
| `sysctl.d` | 交换文件以及IP协议加固配置文件 |
| `xorg` | fbturbo Xorg 驱动配置 |

## 自定义包和脚本
 `packages` 目录里放置自定义deb包, 比如系统仓库里没有的软件.在安装完系统仓库中的包之后安装. 自定义包所依赖的deb包会自动从系统仓库下载. 不要把自定义包添加到 `APT_INCLUDES` 参数中.
 `custom.d` 目录中的脚本会在其它安装都完成后, 创建镜像文件之前执行.

## 记录镜像产生过程的信息
所有镜像产生过程的信息、`rpi23-gen-image.sh` 脚本执行的命令都可以通过shell的 `script` 命令保存到日志文件中:

```shell
script -c 'APT_SERVER=ftp.de.debian.org ./rpi23-gen-image.sh' ./build.log
```

## 烧录镜像文件
`rpi23-gen-image.sh` 所生成的镜像文件需要使用 `bmaptool` 或 `dd` 烧录到 microSD 卡. `bmaptool` 速度快比 `dd` 聪明.

##### 烧录示例:
```shell
bmaptool copy ./images/jessie/2017-01-23-rpi3-jessie.img /dev/mmcblk0
dd bs=4M if=./images/jessie/2017-01-23-rpi3-jessie.img of=/dev/mmcblk0
```
如果设置过 `ENABLE_SPLITFS`, 烧录 `-frmw` 文件到 microSD 卡, 烧录 `-root` 文件到 USB 驱动器:
```shell
bmaptool copy ./images/jessie/2017-01-23-rpi3-jessie-frmw.img /dev/mmcblk0
bmaptool copy ./images/jessie/2017-01-23-rpi3-jessie-root.img /dev/sdc
```
## 每周镜像
这些镜像由JRWR'S I/O PORT提供, 每周日午夜UTC 0点编译!
* [Debian Stretch Raspberry Pi2/3 周构建镜像](https://jrwr.io/doku.php?id=projects:debianpi)

## External links and references外部链接, 各种资源
* [Debian 全世界镜像列表](https://www.debian.org/mirror/list)
* [Debian 树莓派 2 Wiki](https://wiki.debian.org/RaspberryPi2)
* [Debian 交叉工具链 Wiki](https://wiki.debian.org/CrossToolchains)
* [Github上的树莓派官方固件](https://github.com/raspberrypi/firmware)
* [Github上的树莓派官方内核](https://github.com/raspberrypi/linux)
* [U-BOOT git 仓库](http://git.denx.de/?p=u-boot.git;a=summary)
* [Xorg DDX fbturbo驱动](https://github.com/ssvb/xf86-video-fbturbo)
* [树莓派3无线接口固件](https://github.com/RPi-Distro/firmware-nonfree/tree/master/brcm80211/brcm)
* [Collabora 树莓派2预编译内核](https://repositories.collabora.co.uk/debian/)
