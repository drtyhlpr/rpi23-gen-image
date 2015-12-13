# rpi2-gen-image
## Introduction
`rpi2-gen-image.sh` is an advanced Debian Linux bootstrapping shell script for generating Debian OS images for the Raspberry 2 (RPi2) computer. The script at this time only supports the bootstrapping of the current stable Debian 8 "jessie" release.

## Build dependencies
The following list of Debian packages must be installed on the build system because they are essentially required for the bootstrapping process. The script will check if all required packages are installed and missing packages will be installed automatically if confirmed by the user.

  ```debootstrap debian-archive-keyring qemu-user-static dosfstools rsync bmap-tools whois git-core```

## Command-line parameters
The script accepts certain command-line parameters to enable or disable specific OS features, services and configuration settings. These parameters are passed to the `rpi2-gen-image.sh` script via (simple) shell-variables. Unlike enviroment shell-variables (simple) shell-variables are defined at the beginning of the command-line call of the `rpi2-gen-image.sh` script.

#####Command-line examples:
```shell
ENABLE_UBOOT=true ./rpi2-gen-image.sh
ENABLE_CONSOLE=false ENABLE_IPV6=false ./rpi2-gen-image.sh
ENABLE_HARDNET=true ENABLE_IPTABLES=true /rpi2-gen-image.sh
APT_SERVER=ftp.de.debian.org APT_PROXY="http://127.0.0.1:3142/" ./rpi2-gen-image.sh
 ```

#### APT settings:
##### `APT_SERVER`="ftp.debian.org"
Set Debian packages server address. Choose a server from the list of Debian wordwide [mirror sites](https://www.debian.org/mirror/list). Using a nearby server will probably speed-up all required downloads within the bootstrapping process.

##### `APT_PROXY`=""
Set Proxy server address. Using a local Proxy-Cache like `apt-cacher-ng` will speed-up the bootstrapping process because all required Debian packages will only be downloaded from the Debian mirror site once.

#### General system settings:
##### `HOSTNAME`="rpi2-jessie"
Set system host name. It is recommended that the host name is unique in the corresponding subnet.  

##### `PASSWORD`="raspberry"
Set system root password. It is **STRONGLY** recommended that you choose a custom password. 

##### `DEFLOCAL`="en_US.UTF-8"
Set default system locale and keyboard layout. This setting can also be changed inside the running OS using the `dpkg-reconfigure locales` command.  

##### `TIMEZONE`="Europe/Berlin"
Set default system timezone. All available timezones can be found in the `/usr/share/zoneinfo/` directory. This setting can also be changed inside the running OS using the `dpkg-reconfigure tzdata` command.

#### Basic system features:
##### `ENABLE_CONSOLE`=true
Enable console output

##### `ENABLE_IPV6`=true
Enable IPv6 support

##### `ENABLE_SSHD`=true
Install and enable OpenSSH service

##### `ENABLE_SOUND`=true
Enable sound hardware and install Advanced Linux Sound Architecture

##### `ENABLE_HWRANDOM`=true
Enable Hardware Random Number Generator

##### `ENABLE_MINGPU`=false
Minimize the amount of shared memory reserverd for the GPU

##### `ENABLE_DBUS`=true
Install and enable D-Bus message bus

##### `ENABLE_XORG`=false
Install Xorg open-source X Window System

##### `ENABLE_FLUXBOX`=false
Install Fluxbox window manager for the X Window System

#### Advanced sytem features:
##### `ENABLE_UBOOT`=false
Replace default RPi bootloader with U-Boot bootloader

##### `ENABLE_IPTABLES`=false
Enable iptables IPv4/IPv6 firewall

##### `ENABLE_HARDNET`=false
Enable IPv4/IPv6 network stack hardening settings

## Flashing the image file
After the image file was succesfully created by the `rpi2-gen-image.sh` script it can be copied to the microSD card that will be used by the RPi2 computer. This can be performed by using the tools `bmaptool` or `dd`. Using `bmaptool` will probably speed-up the copy process because `bmaptool` copies more wisely than `dd`.

#####Flashing examples:
```shell
bmaptool copy ./images/jessie/2015-12-13-debian-jessie.img /dev/mmcblk0
dd bs=4M if=./images/jessie/2015-12-13-debian-jessie.img of=/dev/mmcblk
```
