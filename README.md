# rpi2-gen-image
## Introduction
`rpi2-gen-image.sh` is an advanced Debian Linux bootstrapping shell script for generating Debian OS images for the Raspberry 2 (RPi2) computer. The script at this time only supports the bootstrapping of the current stable Debian 8 "jessie" release.

## Build dependencies
The following list of Debian packages must be installed on the build system because they are essentially required for the bootstrapping process. The script will check if all required packages are installed and missing packages will be installed automatically if confirmed by the user.

  ```debootstrap debian-archive-keyring qemu-user-static dosfstools rsync bmap-tools whois git-core```

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
 ```

#### APT settings:
##### `APT_SERVER`="ftp.debian.org"
Set Debian packages server address. Choose a server from the list of Debian worldwide [mirror sites](https://www.debian.org/mirror/list). Using a nearby server will probably speed-up all required downloads within the bootstrapping process.

##### `APT_PROXY`=""
Set Proxy server address. Using a local Proxy-Cache like `apt-cacher-ng` will speed-up the bootstrapping process because all required Debian packages will only be downloaded from the Debian mirror site once.

##### `APT_INCLUDES`=""
A comma seperated list of additional packages to be installed during bootstrapping.

#### General system settings:
##### `HOSTNAME`="rpi2-jessie"
Set system host name. It's recommended that the host name is unique in the corresponding subnet.

##### `PASSWORD`="raspberry"
Set system `root` password. The same password is used for the created user `pi`. It's **STRONGLY** recommended that you choose a custom password.

##### `DEFLOCAL`="en_US.UTF-8"
Set default system locale. This setting can also be changed inside the running OS using the `dpkg-reconfigure locales` command. The script variant `minbase` (ENABLE_MINBASE=true) doesn't install `locales`.

##### `TIMEZONE`="Europe/Berlin"
Set default system timezone. All available timezones can be found in the `/usr/share/zoneinfo/` directory. This setting can also be changed inside the running OS using the `dpkg-reconfigure tzdata` command.

##### `EXPANDROOT`=true
Expand the root partition and filesystem automatically on first boot.

#### Keyboard settings:
These options are used to configure keyboard layout in `/etc/default/keyboard` for console and Xorg. These settings can also be changed inside the running OS using the `dpkg-reconfigure keyboard-configuration` command.

##### `XKBMODEL`=""
Set the name of the model of your keyboard type.

##### `XKBLAYOUT`=""
Set the supported keyboard layout(s).

##### `XKBVARIANT`=""
Set the supported variant(s) of the keyboard layout(s).

##### `XKBOPTIONS`=""
Set extra xkb configuration options.

#### Networking settings (DHCP)
This setting is used to set up networking auto configuration in `/etc/systemd/network/eth.network`.

#####`ENABLE_DHCP`=true
Set the system to use DHCP. This requires an DHCP server.

#### Networking settings (static)
These settings are used to set up a static networking configuration in /etc/systemd/network/eth.network. The following static networking settings are only supported if `ENABLE_DHCP` was set to `false`.

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

#### Advanced sytem features:
##### `ENABLE_MINBASE`=false
Use debootstrap script variant `minbase` which only includes essential packages and apt. This will reduce the disk usage by about 65 MB.

##### `ENABLE_UBOOT`=false
Replace default RPi2 second stage bootloader (bootcode.bin) with U-Boot bootloader. U-Boot can boot images via the network using the BOOTP/TFTP protocol.

##### `ENABLE_FBTURBO`=false
Install and enable the hardware accelerated Xorg video driver `fbturbo`. Please note that this driver is currently limited to hardware accelerated window moving and scrolling.

##### `ENABLE_IPTABLES`=false
Enable iptables IPv4/IPv6 firewall. Simplified ruleset: Allow all outgoing connections. Block all incoming connections except to OpenSSH service.

##### `ENABLE_USER`=true
Create pi user with password raspberry

##### `ENABLE_ROOT`=true
Set root user password so root login will be enabled

##### `ENABLE_ROOT_SSH`=true
Enable password root login via SSH. May be a security risk with default
password, use only in trusted environments.

##### `ENABLE_HARDNET`=false
Enable IPv4/IPv6 network stack hardening settings.

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
