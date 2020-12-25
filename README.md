# rpi23-gen-image
## Introduction
`rpi23-gen-image.sh` is an advanced Debian Linux bootstrapping shell script for generating Debian OS images for all Raspberry Pi computers. The script at this time supports the bootstrapping of the Debian (armhf/armel) releases `stretch` and `buster`. Raspberry Pi 0/1/2/3/4 images are generated for 32-bit mode only. Raspberry Pi 3 supports 64-bit images that can be generated using custom configuration parameters (```templates/rpi3-stretch-arm64-4.14.y```).

## Build dependencies
The following list of Debian packages must be installed on the build system because they are essentially required for the bootstrapping process. The script will check if all required packages are installed and missing packages will be installed automatically if confirmed by the user.

  ```debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git bc psmisc dbus sudo```

It is recommended to configure the `rpi23-gen-image.sh` script to build and install the latest Raspberry Pi Linux kernel. For the Raspberry 3 this is mandatory. Kernel compilation and linking will be performed on the build system using an ARM (armhf/armel/aarch64) cross-compiler toolchain.

The script has been tested using the default `crossbuild-essential-armhf` and `crossbuild-essential-armel` toolchain meta packages on Debian Linux `stretch` build systems. Please check the [Debian CrossToolchains Wiki](https://wiki.debian.org/CrossToolchains) for further information.

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
RELEASE=buster BUILD_KERNEL=true ./rpi23-gen-image.sh
RPI_MODEL=3 ENABLE_WIRELESS=true ENABLE_MINBASE=true BUILD_KERNEL=true ./rpi23-gen-image.sh
RELEASE=buster RPI_MODEL=3 ENABLE_WIRELESS=true ENABLE_MINBASE=true BUILD_KERNEL=true ./rpi23-gen-image.sh
```

## Configuration template files
To avoid long lists of command-line parameters and to help to store the favourite parameter configurations the `rpi23-gen-image.sh` script supports so called configuration template files (`CONFIG_TEMPLATE`=template). These are simple text files located in the `./templates` directory that contain the list of configuration parameters that will be used. New configuration template files can be added to the `./templates` directory.

##### Command-line examples:
```shell
CONFIG_TEMPLATE=rpi3stretch ./rpi23-gen-image.sh
CONFIG_TEMPLATE=rpi2stretch ./rpi23-gen-image.sh
```

## Working with the your template:
 * **A Pipe ("|") represents a logical OR**
 * **A valuetype of boolean represents the options true or false**
 * **Values without a default are required if you want do use that feature. It is possible that not every feature has a (working) sanity check.**
 * **If it's not working as expected, search your option in all the files in this repository (With e.g.grep or notepad++).**
 * **Check if your missing a required option while looking at the code**

## Supported parameters and settings

#### APT settings:
|Option|Value|default value|value format|desciption|
|---|---|---|---|---|
|APT_SERVER|string|ftp.debian.org|`URL`|Set Debian packages server address. Choose a server from the list of Debian worldwide [mirror sites](https://www.debian.org/mirror/list). Using a nearby server will probably speed-up all required downloads within the bootstrapping process.|
|APT_PROXY|string||`URL`|Set Proxy server address. Using a local Proxy-Cache like `apt-cacher-ng` will speed-up the bootstrapping process because all required Debian packages will only be downloaded from the Debian mirror site once. If `apt-cacher-ng` is running on default `http://127.0.0.1:3142` it is autodetected and you don't need to set this.|
|KEEP_APT_PROXY|boolean|false|`true`\|`false`|true=Keep the APT_PROXY settings used in the bootsrapping process in the generated image|
|APT_INCLUDES|string list||`packageA`,`packageB`,...|A comma-separated list of additional packages to be installed by debootstrap during bootstrapping.|
|APT_INCLUDES_LATE|string list||`packageA`,`packageB`,...|A comma-separated list of additional packages to be installed by apt after bootstrapping and after APT sources are set up.  This is useful for packages with pre-depends, which debootstrap do not handle well.|
|APT_EXCLUDES|string list||`packageA`,`packageB`,...|A comma-separated list of packages to exclude. Use carefully|
---

#### General system settings:
|Option|Value|default value|value format|desciption|
|---|---|---|---|---|
|SET_ARCH|integer|32|`32`\|`64`|Set Architecture to default 32bit. If you want to compile 64-bit (RPI3/RPI3+/RPI4) set it to `64`. This option will set every needed cross-compiler or board specific option for a successful build.|
|RPI_MODEL|string|3P|`0`\|`1`\|`1P`\|`2`\|`3`\|`3P`\|`4`|Set Architecture. This option will set most build options accordingly. Specify the target Raspberry Pi hardware model.|
|RELEASE|string|buster|`jessie`\|`buster`\|`stretch`<br>\|`bullseye`\|`testing`\|`stable`<br>\|`oldstable`|Set the desired Debian release name. The script at this time supports the bootstrapping of the Debian releases `stretch` and `buster`.|
|HOSTNAME|string|RPI_MODEL-RELEASE(e.g. RPI3-buster)|`SomeImageName.img`|Set system hostname. It's recommended that the hostname is unique in the corresponding subnet.|
|DEFLOCAL|string|en_US.UTF-8|`Locale.Charset`|Set default system locale. This setting can also be changed inside the running OS using the `dpkg-reconfigure locales` command. Please note that on using this parameter the script will automatically install the required packages `locales`, `keyboard-configuration` and `console-setup`.|
|TIMEZONE|string|Europe/Berlin|`Timezone`|Set default system timezone. All available timezones can be found in the `/usr/share/zoneinfo/` directory. This setting can also be changed inside the running OS using the `dpkg-reconfigure tzdata` command.|
|EXPANDROOT|boolean|true|`true`\|`false`|true=Expand the root partition and filesystem automatically on first boot|

---

#### User settings:
|Option|Value|default value|desciption|
|---|---|---|---|
|ENABLE_ROOT|boolean|false|true=root login if ROOT_PASSWORD is set|
|ROOT_PASSWORD|string|raspberry|Set password for `root` user. It's **STRONGLY** recommended that you choose a custom password.|
|ENABLE_USER|boolean|true|true=Create non-root user with password `USER_PASSWORD` and username `USER_NAME`|
|USER_NAME|string|pi|Set username for non-root user, if `ENABLE_USER` is true|
|USER_PASSWORD|string|raspberry|Set password for non-root user, if `ENABLE_USER` is true. It's **STRONGLY** recommended that you choose a custom password.|

---

#### Keyboard settings:

These options are used to configure keyboard layout in `/etc/default/keyboard` for console and Xorg. These settings can also be changed inside the running OS using the `dpkg-reconfigure keyboard-configuration` command.

|Option|Value|default value|value format|desciption|
|---|---|---|---|---|
|XKB_MODEL|string||`pc104`|Set the name of the model of your keyboard type|
|XKB_LAYOUT|string||`us`|Set the supported keyboard layout(s)|
|XKB_VARIANT|string||`basic`|Set the supported variant(s) of the keyboard layout(s)|
|XKB_OPTIONS|string||`grp:alt_shift_toggle`|Set extra xkb configuration options|

---

#### Networking settings:
ethernet setting go to `/etc/systemd/network/eth0.network`.
wifi settings go to `/etc/systemd/network/wlan0.network`.

The default location of network configuration files in the Debian `stretch` release was changed to `/lib/systemd/network`.`

|Option|Value|default value|desciption|
|---|---|---|---|
|ENABLE_IPV6|boolean|true|true=Enable IPv6 support via systemd-networkd|
|ENABLE_WIRELESS|boolean|false|true=Download and install the [closed-source firmware binary blob](https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm) that is required to run the internal wireless interface of the Raspberry Pi model `3`. This parameter is ignored if the specified `RPI_MODEL` is not `0`,`3`,`3P`,`4`|
|ENABLE_IPTABLES|boolean|false|true=Enable iptables IPv4/IPv6 firewall. Simplified ruleset: Allow all outgoing connections. Block all incoming connections except to OpenSSH service.|
|ENABLE_HARDNET|boolean|false|true=Enable IPv4/IPv6 network stack hardening settings|
|ENABLE_IFNAMES|boolean|true|true=creates complex and long interface names like e.g. encx8945924. Enable automatic assignment of predictable, stable network interface names for all NICs|

---

#### Networking settings (DHCP):


|Option|Value|default value|desciption|
|---|---|---|---|
|ENABLE_ETH_DHCP|boolean|true|Set the system to use DHCP on wired interface. This requires an DHCP server|
|ENABLE_WIFI_DHCP|boolean|true|Set the system to use DHCP on wifi interface. This requires an DHCP server. Requires ENABLE_WIRELESS|

---

#### Networking settings (ethernet static):
The following static networking parameters are only supported if `ENABLE_ETH_DHCP` was set to `false`.

|Option|Value|value format|desciption|
|---|---|---|---|
|NET_ETH_ADDRESS|string|`CIDR`|static IPv4 or IPv6 address and its prefix, separated by "/", eg. "192.169.0.3/24"|
|NET_ETH_GATEWAY|string|`IP`|default gateway|
|NET_ETH_DNS_1|string|`IP`|first DNS server|
|NET_ETH_DNS_2|string|`IP`|second DNS server|
|NET_ETH_DNS_DOMAINS|string|`example.local`|default DNS search domains to use for non fully qualified hostnames|
|NET_ETH_NTP_1|string|`IP`|first NTP server|
|NET_ETH_NTP_2|string|`IP`|second NTP server|

---

#### Networking settings (WIFI):

|Option|Value|value format|desciption|
|---|---|---|---|
|NET_WIFI_SSID|string|`yourwifiname`|WIFI SSID|
|NET_WIFI_PSK|string|`yourwifikeytojoinnetwork`|WPA/WPA2 PSK|

---

#### Networking settings (WIFI static):
The following static networking parameters are only supported if `ENABLE_WIFI_DHCP` was set to `false`.

|Option|Value|value format|desciption|
|---|---|---|---|
|NET_WIFI_ADDRESS|string|`CIDR`|static IPv4 or IPv6 address and its prefix, separated by "/", eg. "192.169.0.3/24"|
|NET_WIFI_GATEWAY|string|`IP`|default gateway|
|NET_WIFI_DNS_1|string|`IP`|first DNS server|
|NET_WIFI_DNS_2|string|`IP`|second DNS server|
|NET_WIFI_DNS_DOMAINS|string|`example.local`|default DNS search domains to use for non fully qualified hostnames|
|NET_WIFI_NTP_1|string|`IP`|first NTP server|
|NET_WIFI_NTP_2|string|`IP`|second NTP server|

---

#### Basic system features:

|Option|Value|default value|value format|desciption|
|---|---|---|---|---|
|ENABLE_CONSOLE|boolean|false|`true`\|`false`|true=Enable serial console interface.Recommended if no monitor or keyboard is connected to the RPi2/3. In case of problems fe. if the network (auto) configuration failed - the serial console can be used to access the system. On RPI `0` `3` `3P` the CPU speed is locked at lowest speed.|
|ENABLE_PRINTK|boolean|false|`true`\|`false`|true=Enables printing kernel messages to konsole. printk is `3 4 1 3` as in raspbian|
|ENABLE_BLUETOOTH|boolean|false|`true`\|`false`|true=Enable onboard Bluetooth interface on the RPi0/3/3P. See: [Configuring the GPIO serial port on Raspbian jessie and stretch](https://spellfoundry.com/2016/05/29/configuring-gpio-serial-port-raspbian-jessie-including-pi-3/)|
|ENABLE_MINIUART_OVERLAY|boolean|false|`true`\|`false`|true=Enable Bluetooth to use this. Adds overlay to swap UART0 with UART1. Enabling (slower) Bluetooth and full speed serial console. - RPI `0` `3` `3P` have a fast `hardware UART0` (ttyAMA0) and a `mini UART1` (ttyS0)! RPI `1` `1P` `2` only have a `hardware UART0`. `UART0` is considered better, because is faster and more stable than `mini UART1`. By default the Bluetooth modem is mapped to the `hardware UART0` and `mini UART` is used for console. The `mini UART` is a problem for the serial console, because its baudrate depends on the CPU frequency, which is changing on runtime. Resulting in a volatile baudrate and thus in an unusable serial console.|
|ENABLE_TURBO|boolean|false|`true`\|`false`|true=Enable Turbo mode. This setting locks cpu at the highest frequency. As setting ENABLE_CONSOLE=true locks RPI to lowest CPU speed, this is can be used additionally to lock cpu hat max speed. Need a good power supply and probably cooling for the Raspberry PI|
|ENABLE_I2C|boolean|true|`true`\|`false`|true=Enable I2C interface on the RPi 0/1/2/3. Please check the [RPi 0/1/2/3 pinout diagrams](https://elinux.org/RPi_Low-level_peripherals) to connect the right GPIO pins|
|ENABLE_SPI|boolean|true|`true`\|`false`|true=Enable SPI interface on the RPi 0/1/2/3. Please check the [RPi 0/1/2/3 pinout diagrams](https://elinux.org/RPi_Low-level_peripherals) to connect the right GPIO pins|
|SSH_ENABLE|boolean|true|`true`\|`false`|Install and enable OpenSSH service. The default configuration of the service doesn't allow `root` to login. Please use the user `pi` instead and `su -` or `sudo` to execute commands as root|
|ENABLE_NONFREE|boolean|false|`true`\|`false`|true=enable non-free\|false=disable non free. Edits /etc/apt/sources.list in your resulting image|
|ENABLE_RSYSLOG|boolean|false|`true`\|`false`|true=keep rsyslog\|false=remove rsyslog. If rsyslog is removed (false), logs will be available only in journal files)|
|ENABLE_SOUND|boolean|false|`true`\|`false`|true=Enable sound\|false=Disable sound|
|ENABLE_HWRANDOM|boolean|true|`true`\|`false`|true=Enable Hardware Random Number Generator(RNG)\|false=Disable Hardware RNG\|Strong random numbers are important for most network-based communications that use encryption. It's recommended to be enabled|
|ENABLE_MINGPU|boolean|false|`true`\|`false`|true=GPU 16MB RAM\|false=64MB RAM\|Minimize the amount of shared memory reserved for the GPU. It doesn't seem to be possible to fully disable the GPU. Also removes start.elf,fixup.dat,start_x.elf,fixup_x.dat form /boot|
|ENABLE_XORG|boolean|false|`true`\|`false`|true=Install Xorg X Window System|\false=install no Xorg|
|ENABLE_WM|string||`blackbox`, `openbox`, `fluxbox`,<br> `jwm`, `dwm`, `xfce4`, `awesome`|Install a user-defined window manager for the X Window System. To make sure all X related package dependencies are getting installed `ENABLE_XORG` will automatically set true if `ENABLE_WM` is used|
|ENABLE_SYSVINIT|boolean|false|`true`\|`false`|true=Support for halt,init,poweroff,reboot,runlevel,shutdown,init commands\|false=use systemd commands|
|ENABLE_SPLASH|boolean|true|`true`\|`false`|true=Enable default Raspberry Pi boot up rainbow splash screen|
|ENABLE_LOGO|boolean|true|`true`\|`false`|true=Enable default Raspberry Pi console logo (image of four raspberries in the top left corner)|
|ENABLE_SILENT_BOOT|boolean|false|`true`\|`false`|true=Set the verbosity of console messages shown during boot up to a strict minimum|
|DISABLE_UNDERVOLT_WARNINGS|integer||`1`\|`2`|Unset to keep default behaviour. Setting the parameter to `1` will disable the warning overlay. Setting it to `2` will additionally allow RPi2/3 turbo mode when low-voltage is present|

---

#### Advanced system features:

|Option|Value|default value|value format|desciption|
|---|---|---|---|---|
|ENABLE_DPHYSSWAP|boolean|true|`true`\|`false`|Enable swap. The size of the swapfile is chosen relative to the size of the root partition. It'll use the `dphys-swapfile` package for that|
|ENABLE_SYSTEMDSWAP|boolean|false|`true`\|`false`|Enables [Systemd-swap service](https://github.com/Nefelim4ag/systemd-swap). Usefull if `KERNEL_ZSWAP` is enabled|
|ENABLE_QEMU|boolean|false|`true`\|`false`|Generate kernel (`vexpress_defconfig`), file system image (`qcow2`) and DTB files that can be used for QEMU full system emulation (`vexpress-A15`). The output files are stored in the `$(pwd)/images/qemu` directory. You can find more information about running the generated image in the QEMU section of this readme file|
|QEMU_BINARY|string||`FullPathToQemuBinaryFile`|Sets the QEMU enviornment for the Debian archive. **Set by RPI_MODEL**|
|ENABLE_KEYGEN|boolean|false|`true`\|`false`|Recover your lost codec license|
|ENABLE_MINBASE|boolean|false|`true`\|`false`|Use debootstrap script variant `minbase` which only includes essential packages and apt. This will reduce the disk usage by about 65 MB|
|ENABLE_SPLITFS|boolean|false|`true`\|`false`|Enable having root partition on an USB drive by creating two image files: one for the `/boot/firmware` mount point, and another for `/`|
|ENABLE_INITRAMFS|boolean|false|`true`\|`false`|Create an initramfs that that will be loaded during the Linux startup process. `ENABLE_INITRAMFS` will automatically get enabled if `ENABLE_CRYPTFS`=true. This parameter will be ignored if `BUILD_KERNEL`=false|
|ENABLE_DBUS|boolean|true|`true`\|`false`|Install and enable D-Bus message bus. Please note that systemd should work without D-bus but it's recommended to be enabled|
|ENABLE_USBBOOT|boolean|false|`true`\|`false`|true=prepare image for usbboot. use with `ENABLE_SPLTFS`=true|
|CHROOT_SCRIPTS|string||`FullPathToScriptFolder`|Full path to a directory with scripts that should be run in the chroot before the image is finally built. Every executable file in this directory is run in lexicographical order|
|ENABLE_UBOOT|boolean|false|`true`\|`false`|Replace the default RPi 0/1/2/3 second stage bootloader (bootcode.bin) with [U-Boot bootloader](https://git.denx.de/?p=u-boot.git;a=summary). U-Boot can boot images via the network using the BOOTP/TFTP protocol. RPI4 needs tbd|
|UBOOTSRC_DIR|string||`FullPathToUBootFolder`|Full path to a directory named `u-boot` of [U-Boot bootloader sources](https://git.denx.de/?p=u-boot.git;a=summary) that will be copied, configured, build and installed inside the chroot|
|ENABLE_FBTURBO|boolean|false|`true`\|`false`|Install and enable the [hardware accelerated Xorg video driver](https://github.com/ssvb/xf86-video-fbturbo) `fbturbo`. Please note that this driver is currently limited to hardware accelerated window moving and scrolling|
|ENABLE_GR_ACCEL|boolean|false|`true`\|`false`|Install and enable [one of the 3D graphics accelerators for Raspi4](https://www.raspberrypi.org/documentation/configuration/config-txt/video.md) `vc4-fkms-v3d`.  Not compatible with `fbturbo` mutually excluded and installed for Raspberry4 only|
|FBTURBOSRC_DIR|string||`FullPathToFbTurboFolder`|Full path to a directory named `xf86-video-fbturbo` of [hardware accelerated Xorg video driver sources](https://github.com/ssvb/xf86-video-fbturbo) that will be copied, configured, build and installed inside the chroot|
|ENABLE_VIDEOCORE|boolean|false|`true`\|`false`|Install and enable the [ARM side libraries for interfacing to Raspberry Pi GPU](https://github.com/raspberrypi/userland) `vcgencmd`. Please note that this driver is currently limited to hardware accelerated window moving and scrolling|
|VIDEOCORESRC_DIR|string||`FullPathToVideoSrcFolder`|Full path to a directory named `userland` of [ARM side libraries for interfacing to Raspberry Pi GPU](https://github.com/raspberrypi/userland) that will be copied, configured, build and installed inside the chroot|
|ENABLE_NEXMON|boolean|false|`true`\|`false`|Install and enable the source code for a C-based firmware patching framework for Broadcom/Cypress WiFi chips that enables you to write your own firmware patches, for example, to enable monitor mode with radiotap headers and frame injection](https://github.com/seemoo-lab/nexmon.git)|
|NEXMONSRC_DIR|string||`FullPathToNexmonFolder`|Full path to a directory named `nexmon` of [Source code for ARM side libraries for interfacing to Raspberry Pi GPU](https://github.com/raspberrypi/userland) that will be copied, configured, build and installed inside the chroot|

---

#### SSH settings:

|Option|Value|default value|value format|desciption|
|---|---|---|---|---|
|SSH_ENABLE_ROOT|boolean|false|`true`\|`false`|Enable password-based root login via SSH. This may be a security risk with the default password set, use only in trusted environments. `ENABLE_ROOT` must be set to `true`|
|SSH_DISABLE_PASSWORD_AUTH|boolean|false|`true`\|`false`|Disable password-based SSH authentication. Only public key based SSH (v2) authentication will be supported|
|SSH_LIMIT_USERS|boolean|false|`true`\|`false`|Limit the users that are allowed to login via SSH. Only allow user `USER_NAME`=pi and root if `SSH_ENABLE_ROOT`=true to login. This parameter will be ignored if `dropbear` SSH is used (`REDUCE_SSHD`=true)|
|SSH_ROOT_PUB_KEY|string||`PathToYourROOT`<br>`RSAPublicKeyFile`|Full path to file. Add SSH (v2) public key(s) from specified file to `authorized_keys` file to enable public key based SSH (v2) authentication of user `root`. The specified file can also contain multiple SSH (v2) public keys. SSH protocol version 1 is not supported. `ENABLE_ROOT` **and** `SSH_ENABLE_ROOT` must be set to `true`|
|SSH_USER_PUB_KEY|string||`PathToYourUSER`<br>`RSAPublicKeyFile`|Full path to file. Add SSH (v2) public key(s) from specified file to `authorized_keys` file to enable public key based SSH (v2) authentication of user `USER_NAME`=pi. The specified file can also contain multiple SSH (v2) public keys. SSH protocol version 1 is not supported|

---

#### Kernel settings:

|Option|Value|default value|value format|desciption|
|---|---|---|---|---|
|BUILD_KERNEL||true|`true`\|`false`|Build and install the latest RPi 0/1/2/3/4 Linux kernel. The default RPi 0/1/2/3/ kernel configuration is used most of the time. ENABLE_NEXMON - Changes Kernel Source to [https://github.com/Re4son/](Kali Linux Kernel) Precompiled 32bit kernel for RPI0/1/2/3 by [https://github.com/hypriot/](hypriot) Precompiled 64bit kernel for RPI3/4 by [https://github.com/sakaki-/](sakaki)|
|CROSS_COMPILE|string|||This sets the cross-compile environment for the compiler. Set by RPI_MODEL|
|KERNEL_ARCH|string|||This sets the kernel architecture for the compiler. Set by RPI_MODEL|
|KERNEL_IMAGE|string|||Name of the image file in the boot partition. Set by RPI_MODEL|
|KERNEL_BRANCH|string|||Name of the requested branch from the GIT location for the RPi Kernel. Default is using the current default branch from the GIT site|
|KERNEL_DEFCONFIG|string|||Sets the default config for kernel compiling. Set by RPI_MODEL|
|KERNEL_THREADS|integer|1|`1`\|`2`\|`3`\|...|Number of threads to build the kernel. If not set, the script will automatically determine the maximum number of CPU cores to speed up kernel compilation|
|KERNEL_HEADERS|boolean|true|`true`\|`false`|Install kernel headers with the built kernel|
|KERNEL_MENUCONFIG|boolean|false|`true`\|`false`|Start `make menuconfig` interactive menu-driven kernel configuration. The script will continue after `make menuconfig` was terminated|
|KERNEL_OLDDEFCONFIG|boolean|false|`true`\|`false`|Run `make olddefconfig` to automatically set all new kernel configuration options to their recommended default values|
|KERNEL_CCACHE|boolean|false|`true`\|`false`|Compile the kernel using ccache. This speeds up kernel recompilation by caching previous compilations and detecting when the same compilation is being done again|
|KERNEL_REMOVESRC|boolean|true|`true`\|`false`|Remove all kernel sources from the generated OS image after it was built and installed|
|KERNELSRC_DIR|string||`FullPathToKernelSrcDir`|Full path to a directory named `linux` of [RaspberryPi Linux kernel sources](https://github.com/raspberrypi/linux) that will be copied, configured, build and installed inside the chroot|
|KERNELSRC_CLEAN|boolean|false|`true`\|`false`|Clean the existing kernel sources directory `KERNELSRC_DIR` (using `make mrproper`) after it was copied to the chroot and before the compilation of the kernel has started. This parameter will be ignored if no `KERNELSRC_DIR` was specified or if `KERNELSRC_PREBUILT`=true|
|KERNELSRC_CONFIG|boolean|true|`true`\|`false`|true=enable custom kernel options. This parameter is automatically set to `true` if no existing kernel sources directory was specified using `KERNELSRC_DIR`. This parameter is ignored if `KERNELSRC_PREBUILT`=true|
|KERNELSRC_USRCONFIG|string||`FullPathToUserKernel.config`|Copy own config file to kernel `.config`. If `KERNEL_MENUCONFIG`=true then running after copy|
|KERNELSRC_PREBUILT|boolean|false|`true`\|`false`|With this parameter set to true the script expects the existing kernel sources directory to be already successfully cross-compiled. The parameters `KERNELSRC_CLEAN`, `KERNELSRC_CONFIG`, `KERNELSRC_USRCONFIG` and `KERNEL_MENUCONFIG` are ignored and no kernel compilation tasks are performed|
|RPI_FIRMWARE_DIR|string||`FullPathToFolder`|Full path to a directory named `firmware`, containing a local copy of the firmware from the [RaspberryPi firmware project](https://github.com/raspberrypi/firmware). Default is to download the latest firmware directly from the project|
|KERNEL_DEFAULT_GOV|string|ondemand|`performance`\|`powersave`<br>\|`userspace`\|`ondemand`<br>\|`conservative`\|`schedutil`|Set the default cpu governor at kernel compilation|
|KERNEL_NF|boolean|false|`true`\|`false`|Enable Netfilter modules as kernel modules. You want that for iptables|
|KERNEL_VIRT|boolean|false|`true`\|`false`|Enable Kernel KVM support (/dev/kvm)|
|KERNEL_ZSWAP|boolean|false|`true`\|`false`|Enable Kernel Zswap support. Best use on high RAM load and mediocre CPU load usecases|
|KERNEL_BPF|boolean|true|`true`\|`false`|Allow attaching eBPF programs to a cgroup using the bpf syscall (CONFIG_BPF_SYSCALL CONFIG_CGROUP_BPF) [systemd wants it - File /lib/systemd/system/systemd-journald.server:36 configures an IP firewall (IPAddressDeny=all), but the local system does not support BPF/cgroup based firewalls]|
|KERNEL_SECURITY|boolean|false|`true`\|`false`|Enables Apparmor, integrity subsystem, auditing|
|KERNEL_BTRFS|boolean|false|`true`\|`false`|enable btrfs kernel support|
|KERNEL_POEHAT|boolean|false|`true`\|`false`|enable Enable RPI POE HAT fan kernel support|
|KERNEL_NSPAWN|boolean|false|`true`\|`false`|Enable per-interface network priority control - for systemd-nspawn|
|KERNEL_DHKEY|boolean|true|`true`\|`false`|Diffie-Hellman operations on retained keys - required for >keyutils-1.6|

---

#### Reduce disk usage:
The following list of parameters is ignored if `ENABLE_REDUCE`=false.

|Option|Value|default value|value format|desciption|
|---|---|---|---|---|
|ENABLE_REDUCE|boolean|false|`true`\|`false`|Reduce the disk space usage by deleting packages and files. See `REDUCE_*` parameters for detailed information|
|REDUCE_APT|boolean|true|`true`\|`false`|Configure APT to use compressed package repository lists and no package caching files|
|REDUCE_DOC|boolean|false|`true`\|`false`|Remove all doc files (harsh). Configure APT to not include doc files on future `apt-get` package installations|
|REDUCE_MAN|boolean|false|`true`\|`false`|Remove all man pages and info files (harsh).  Configure APT to not include man pages on future `apt-get` package installations|
|REDUCE_VIM|boolean|false|`true`\|`false`|Replace `vim-tiny` package by `levee` a tiny vim clone|
|REDUCE_BASH|boolean|false|`true`\|`false`|Remove `bash` package and switch to `dash` shell (experimental)|
|REDUCE_HWDB|boolean|false|`true`\|`false`|Remove PCI related hwdb files (experimental)|
|REDUCE_SSHD|boolean|false|`true`\|`false`|Replace `openssh-server` with `dropbear`|
|REDUCE_LOCALE|boolean|false|`true`\|`false`|Remove all `locale` translation files|
|REDUCE_KERNEL|boolean|false|`true`\|`false`|Reduce the size of the generated kernel by removing unwanted devices, network and filesystem drivers (experimental)|
---

#### Encrypted root partition:
#### On first boot, you will be asked to enter you password several time
#### See cryptsetup options for a more information about opttion values(https://wiki.archlinux.org/index.php/Dm-crypt/Device_encryption)

|Option|Value|default value|value format|desciption|
|---|---|---|---|---|
|ENABLE_CRYPTFS|boolean|false|`true`\|`false`|Enable full system encryption with dm-crypt. Setup a fully LUKS encrypted root partition (aes-xts-plain64:sha512) and generate required initramfs. The /boot directory will not be encrypted. This parameter will be ignored if `BUILD_KERNEL`=false. `ENABLE_CRYPTFS` is experimental|
|CRYPTFS_PASSWORD|string||`YourPasswordToUnlockCrypto`|Set password of the encrypted root partition. This parameter is mandatory if `ENABLE_CRYPTFS`=true|
|CRYPTFS_MAPPING|string|secure|`YourDevMNapperName`|crypsetup device-mapper name|
|CRYPTFS_CIPHER|string|aes-xts-plain64|`aes-cbc-essiv:sha256`|cryptsetup cipher `aes-xts*` ciphers are strongly recommended|
|CRYPTFS_HASH|string|sha256|`sha256`\|`sha512`|cryptsetup hash algorithm|
|CRYPTFS_XTSKEYSIZE|integer|256|`256`\|`512`||Sets key size in bits. The argument has to be a multiple of 8|
|CRYPTFS_DROPBEAR|boolean|false|`true`\|`false`|true=Enable Dropbear Initramfs support\|false=disable dropbear|
|CRYPTFS_DROPBEAR_PUBKEY|string||`PathToYourPublicDropbearKeyFile`|Full path to dropbear Public RSA-OpenSSH Key|

---

#### Build settings:
|Option|Value|default value|value format|desciption|
|---|---|---|---|---|
|BASEDIR|string||`FullPathToScriptRootDir`|If unset start from scriptroot or set to Full path to rpi123-gen-image directory|
|IMAGE_NAME|string||`YourImageName`|if unset creates a name after this template: rpi`RPI_MODEL`-`RELEASE`-`RELEASE_ARCH`|

---

## Understanding the script
The functions of this script that are required for the different stages of the bootstrapping are split up into single files located inside the `bootstrap.d` directory. During the bootstrapping every script in this directory gets executed in lexicographical order:

| Script | Description |
| --- | --- |
| `10-bootstrap.sh` | Debootstrap basic system |
| `11-apt.sh` | Setup APT repositories |
| `12-locale.sh` | Setup Locales and keyboard settings |
| `13-kernel.sh` | Build and install RPi 0/1/2/3 Kernel |
| `14-fstab.sh` | Setup fstab and initramfs |
| `15-rpi-config.sh` | Setup RPi 0/1/2/3 config and cmdline |
| `20-networking.sh` | Setup Networking |
| `21-firewall.sh` | Setup Firewall |
| `30-security.sh` | Setup Users and Security settings |
| `31-logging.sh` | Setup Logging |
| `32-sshd.sh` | Setup SSH and public keys |
| `41-uboot.sh` | Build and Setup U-Boot |
| `42-fbturbo.sh` | Build and Setup fbturbo Xorg driver |
| `43-videocore.sh` | Build and Setup videocore libraries |
| `50-firstboot.sh` | First boot actions |
| `99-reduce.sh` | Reduce the disk space usage |

All the required configuration files that will be copied to the generated OS image are located inside the `files` directory. It is not recommended to modify these configuration files manually.

| Directory | Description |
| --- | --- |
| `apt` | APT management configuration files |
| `boot` | Boot and RPi 0/1/2/3 configuration files |
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
After the image file was successfully created by the `rpi23-gen-image.sh` script it can be copied to the microSD card that will be used by the RPi 0/1/2/3 computer. This can be performed by using the tools `bmaptool` or `dd`. Using `bmaptool` will probably speed-up the copy process because `bmaptool` copies more wisely than `dd`.

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
* [RPi3 Wireless interface firmware](https://github.com/RPi-Distro/firmware-nonfree/tree/master/brcm)
* [Collabora RPi2 Kernel precompiled](https://repositories.collabora.co.uk/debian/)
