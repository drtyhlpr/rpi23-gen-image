# rpi2-gen-image
## Introduction
`rpi2-gen-image.sh` is an advanced Debian Linux bootstrapping shell script for generating Debian OS images for the Raspberry 2 (RPi2) computer. The script at this time supports the bootstrapping of the Debian releases "jessie" and "stretch".

## Build dependencies
The following list of Debian packages must be installed on the build system because they are essentially required for the bootstrapping process. The script will check if all required packages are installed and missing packages will be installed automatically if confirmed by the user.

  ```debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git```

## Command-line parameters
The script accepts certain command-line parameters to enable or disable specific OS features, services and configuration settings. These parameters are passed to the `rpi2-gen-image.sh` script via (simple) shell-variables. Unlike environment shell-variables (simple) shell-variables are defined at the beginning of the command-line call of the `rpi2-gen-image.sh` script.

#####Command-line examples:
```shell
ENABLE_UBOOT=true ./rpi2-gen-image.sh
ENABLE_CONSOLE=false ENABLE_IPV6=false ./rpi2-gen-image.sh
ENABLE_WM=xfce4 ENABLE_FBTURBO=true ENABLE_MINBASE=true ./rpi2-gen-image.sh
ENABLE_HARDNET=true ENABLE_IPTABLES=true /rpi2-gen-image.sh
APT_SERVER=ftp.de.debian.org APT_PROXY="http://127.0.0.1:3142/" ./rpi2-gen-image.sh
ENABLE_MINBASE=true ./rpi2-gen-image.sh
BUILD_KERNEL=true ENABLE_MINBASE=true ENABLE_IPV6=false ./rpi2-gen-image.sh
BUILD_KERNEL=true KERNELSRC_DIR=/tmp/linux ./rpi2-gen-image.sh
ENABLE_MINBASE=true ENABLE_REDUCE=true ENABLE_MINGPU=true BUILD_KERNEL=true ./rpi2-gen-image.sh
ENABLE_CRYPTFS=true CRYPTFS_PASSWORD=changeme EXPANDROOT=false ENABLE_MINBASE=true ENABLE_REDUCE=true ENABLE_MINGPU=true BUILD_KERNEL=true ./rpi2-gen-image.sh
RELEASE=stretch BUILD_KERNEL=true ./rpi2-gen-image.sh
```

#### APT settings:
##### `APT_SERVER`="ftp.debian.org"
Set Debian packages server address. Choose a server from the list of Debian worldwide [mirror sites](https://www.debian.org/mirror/list). Using a nearby server will probably speed-up all required downloads within the bootstrapping process.

##### `APT_PROXY`=""
Set Proxy server address. Using a local Proxy-Cache like `apt-cacher-ng` will speed-up the bootstrapping process because all required Debian packages will only be downloaded from the Debian mirror site once.

##### `APT_INCLUDES`=""
A comma separated list of additional packages to be installed during bootstrapping.

#### General system settings:
##### `RELEASE`="jessie"
Set the desired Debian release name. The script at this time supports the bootstrapping of the Debian releases "jessie" and "stretch". `BUILD_KERNEL`=true will automatically be set if the Debian release `stretch` is used.

##### `HOSTNAME`="rpi2-jessie"
Set system host name. It's recommended that the host name is unique in the corresponding subnet.

##### `PASSWORD`="raspberry"
Set system `root` password. The same password is used for the created user `pi`. It's **STRONGLY** recommended that you choose a custom password.

##### `DEFLOCAL`="en_US.UTF-8"
Set default system locale. This setting can also be changed inside the running OS using the `dpkg-reconfigure locales` command. Please note that on using this parameter the script will automatically install the required packages `locales`, `keyboard-configuration` and `console-setup`.

##### `TIMEZONE`="Europe/Berlin"
Set default system timezone. All available timezones can be found in the `/usr/share/zoneinfo/` directory. This setting can also be changed inside the running OS using the `dpkg-reconfigure tzdata` command.

##### `EXPANDROOT`=true
Expand the root partition and filesystem automatically on first boot.

#### Keyboard settings:
These options are used to configure keyboard layout in `/etc/default/keyboard` for console and Xorg. These settings can also be changed inside the running OS using the `dpkg-reconfigure keyboard-configuration` command.

##### `XKB_MODEL`=""
Set the name of the model of your keyboard type.

##### `XKB_LAYOUT`=""
Set the supported keyboard layout(s).

##### `XKB_VARIANT`=""
Set the supported variant(s) of the keyboard layout(s).

##### `XKB_OPTIONS`=""
Set extra xkb configuration options.

#### Networking settings (DHCP):
This parameter is used to set up networking auto configuration in `/etc/systemd/network/eth.network`. The default location of network configuration files in the Debian `stretch` release was changed to `/lib/systemd/network`.`

#####`ENABLE_DHCP`=true
Set the system to use DHCP. This requires an DHCP server.

#### Networking settings (static):
These parameters are used to set up a static networking configuration in `/etc/systemd/network/eth.network`. The following static networking parameters are only supported if `ENABLE_DHCP` was set to `false`. The default location of network configuration files in the Debian `stretch` release was changed to `/lib/systemd/network`.

#####`NET_ADDRESS`=""
Set a static IPv4 or IPv6 address and its prefix, separated by "/", eg. "192.169.0.3/24".

#####`NET_GATEWAY`=""
Set the IP address for the default gateway.

#####`NET_DNS_1`=""
Set the IP address for the first DNS server.

#####`NET_DNS_2`=""
Set the IP address for the second DNS server.

#####`NET_DNS_DOMAINS`=""
Set the default DNS search domains to use for non fully qualified host names.

#####`NET_NTP_1`=""
Set the IP address for the first NTP server.

#####`NET_NTP_2`=""
Set the IP address for the second NTP server.

#### Basic system features:
##### `ENABLE_CONSOLE`=true
Enable serial console interface. Recommended if no monitor or keyboard is connected to the RPi2. In case of problems fe. if the network (auto) configuration failed - the serial console can be used to access the system.

##### `ENABLE_IPV6`=true
Enable IPv6 support. The network interface configuration is managed via systemd-networkd.

##### `ENABLE_SSHD`=true
Install and enable OpenSSH service. The default configuration of the service doesn't allow `root` to login. Please use the user `pi` instead and `su -` or `sudo` to execute commands as root.

##### `ENABLE_NONFREE`=false
Allow the installation of non-free Debian packages that do not comply with the DFSG. This is required to install closed-source firmware binary blobs.

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
Install a user defined window manager for the X Window System. To make sure all X related package dependencies are getting installed `ENABLE_XORG` will automatically get enabled if `ENABLE_WM` is used. The `rpi2-gen-image.sh` script has been tested with the following list of window managers: `blackbox`, `openbox`, `fluxbox`, `jwm`, `dwm`, `xfce4`, `awesome`.

#### Advanced system features:
##### `ENABLE_MINBASE`=false
Use debootstrap script variant `minbase` which only includes essential packages and apt. This will reduce the disk usage by about 65 MB.

##### `ENABLE_REDUCE`=false
Reduce the disk space usage by deleting packages and files. See `REDUCE_*` parameters for detailed information.

##### `ENABLE_UBOOT`=false
Replace default RPi2 second stage bootloader (bootcode.bin) with U-Boot bootloader. U-Boot can boot images via the network using the BOOTP/TFTP protocol.

##### `ENABLE_FBTURBO`=false
Install and enable the hardware accelerated Xorg video driver `fbturbo`. Please note that this driver is currently limited to hardware accelerated window moving and scrolling.

##### `ENABLE_IPTABLES`=false
Enable iptables IPv4/IPv6 firewall. Simplified ruleset: Allow all outgoing connections. Block all incoming connections except to OpenSSH service.

##### `ENABLE_USER`=true
Create non-root user with password raspberry. Unless overridden with `USER_NAME`=user, username will be `pi`.

##### `USER_NAME`=pi
Non-root user to create.  Ignored if `ENABLE_USER`=false

##### `ENABLE_ROOT`=true
Set root user password so root login will be enabled

##### `ENABLE_ROOT_SSH`=true
Enable password root login via SSH. May be a security risk with default
password, use only in trusted environments.

##### `ENABLE_HARDNET`=false
Enable IPv4/IPv6 network stack hardening settings.

##### `ENABLE_SPLITFS`=false
Enable having root partition on an USB drive by creating two image files: one for the `/boot/firmware` mount point, and another for `/`.

##### `CHROOT_SCRIPTS`=""
Path to a directory with scripts that should be run in the chroot before the image is finally built. Every executable file in this directory is run in lexicographical order.

##### `ENABLE_INITRAMFS`=false
Create an initramfs that that will be loaded during the Linux startup process. `ENABLE_INITRAMFS` will automatically get enabled if `ENABLE_CRYPTFS`=true. This parameter will be ignored if `BUILD_KERNEL`=false.

##### `ENABLE_IFNAMES`=true
Enable automatic assignment of predictable, stable network interface names for all local Ethernet, WLAN interfaces. This might create complex and long interface names. This parameter is only supported if the Debian release `stretch` is used.

#### Kernel compilation:
##### `BUILD_KERNEL`=false
Build and install the latest RPi2 Linux kernel. Currently only the default RPi2 kernel configuration is used.

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
Path to a directory of [RaspberryPi Linux kernel sources](https://github.com/raspberrypi/linux) that will be copied, configured, build and installed inside the chroot.

##### `KERNELSRC_CLEAN`=false
Clean the existing kernel sources directory `KERNELSRC_DIR` (using `make mrproper`) after it was copied to the chroot and before the compilation of the kernel has started. This parameter will be ignored if no `KERNELSRC_DIR` was specified or if `KERNELSRC_PREBUILT`=true.

##### `KERNELSRC_CONFIG`=true
Run `make bcm2709_defconfig` (and optional `make menuconfig`) to configure the kernel sources before building. This parameter is automatically set to `true` if no existing kernel sources directory was specified using `KERNELSRC_DIR`. This parameter is ignored if `KERNELSRC_PREBUILT`=true.

##### `KERNELSRC_PREBUILT`=false
With this parameter set to true the script expects the existing kernel sources directory to be already successfully cross-compiled. The parameters `KERNELSRC_CLEAN`, `KERNELSRC_CONFIG` and `KERNEL_MENUCONFIG` are ignored and no kernel compilation tasks are performed.

##### `FIRMWAREDIR`=""
The directory containing a local copy of the firmware from the [RaspberryPi firmware project](https://github.com/raspberrypi/firmware). Default is to download the latest firmware directly from the project.

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

## Understanding the script
The functions of this script that are required for the different stages of the bootstrapping are split up into single files located inside the `bootstrap.d` directory. During the bootstrapping every script in this directory gets executed in lexicographical order:

| Script | Description |
| --- | --- |
| `10-bootstrap.sh` | Debootstrap basic system |
| `11-apt.sh` | Setup APT repositories |
| `12-locale.sh` | Setup Locales and keyboard settings |
| `13-kernel.sh` | Build and install RPi2 Kernel |
| `20-networking.sh` | Setup Networking |
| `21-firewall.sh` | Setup Firewall |
| `30-security.sh` | Setup Users and Security settings |
| `31-logging.sh` | Setup Logging |
| `41-uboot.sh` | Build and Setup U-Boot |
| `42-fbturbo.sh` | Build and Setup fbturbo Xorg driver |
| `50-firstboot.sh` | First boot actions |
| `99-reduce.sh` | Reduce the disk space usage |

All the required configuration files that will be copied to the generated OS image are located inside the `files` directory. It is not recommended to modify these configuration files manually.

| Directory | Description |
| --- | --- |
| `apt` | APT management configuration files |
| `boot` | Boot and RPi2 configuration files |
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

Debian custom packages, i.e. those not in the debian repositories, can be installed by placing them in the `packages` directory. They are installed immediately after packages from the repositories are installed. Any dependencies listed in the custom packages will be downloaded automatically from the repositories. Do not list these custom packages in `APT_INCLUDES`.

Scripts in the custom.d directory will be executed after all other installation is complete but before the image is created.

## Logging of the bootstrapping process
All information related to the bootstrapping process and the commands executed by the `rpi2-gen-image.sh` script can easily be saved into a logfile. The common shell command `script` can be used for this purpose:

```shell
script -c 'APT_SERVER=ftp.de.debian.org ./rpi2-gen-image.sh' ./build.log
```

## Flashing the image file
After the image file was successfully created by the `rpi2-gen-image.sh` script it can be copied to the microSD card that will be used by the RPi2 computer. This can be performed by using the tools `bmaptool` or `dd`. Using `bmaptool` will probably speed-up the copy process because `bmaptool` copies more wisely than `dd`.

#####Flashing examples:
```shell
bmaptool copy ./images/jessie/2015-12-13-debian-jessie.img /dev/mmcblk0
dd bs=4M if=./images/jessie/2015-12-13-debian-jessie.img of=/dev/mmcblk0
```
If you have set `ENABLE_SPLITFS`, copy the `-frmw` image on the microSD card, then the `-root` one on the USB drive:
```shell
bmaptool copy ./images/jessie/2015-12-13-debian-jessie-frmw.img /dev/mmcblk0
bmaptool copy ./images/jessie/2015-12-13-debian-jessie-root.img /dev/sdc
```
