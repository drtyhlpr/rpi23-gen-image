# rpi2-gen-image
 Advanced debian "jessie" bootstrap script for RPi2
 
# examples
```shell
ENABLE_UBOOT=true ./rpi2-gen-image.sh
ENABLE_CONSOLE=false ENABLE_IPV6=false ./rpi2-gen-image.sh
ENABLE_HARDNET=true ENABLE_IPTABLES=true /rpi2-gen-image.sh
APT_SERVER=ftp.de.debian.org APT_PROXY="http://127.0.0.1:3142/" ./rpi2-gen-image.sh
 ```
