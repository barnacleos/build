barnacleos/build
================

[![Build Status](https://travis-ci.org/barnacleos/build.svg)](https://travis-ci.org/barnacleos/build)

Tool used to create the [BarnacleOS](https://github.com/barnacleos) images.
Based on [pi-gen](https://github.com/rpi-distro/pi-gen) tool used to create
the official [raspberrypi.org](https://raspberrypi.org) Raspbian images.



Table of contents
-----------------

* [Dependencies](#dependencies)
* [Build](#build)
* [Network interfaces](#network-interfaces)
* [System configuration](#system-configuration)



Dependencies
------------

On Debian-based systems:

```bash
apt-get install bash quilt parted qemu-user-static debootstrap zerofree \
dosfstools libcap2-bin grep rsync
```



Build
-----

Run `sudo ./run ./build.sh && sudo ./run ./mkimg.sh` to build the image.
The following files will be created:

* `rootfs/` - the root file system (`/` and `/boot/` partitions)
* `deploy/BarnacleOS.img` - the image to write to SD card



Network interfaces
------------------

Some initial configuration may be required to use the default BarnacleOS
image, such as Wi-Fi drivers installation. It can be done via SSH. Network
interface `eth0` has default configurations to help you to connect.
It is configured by default to get IPv4 address from router via DHCP
without any assumptions about subnet configuration. You can just plug
your Raspberry Pi to router with Ethernet cable, discover which address
was given to it in router's web interface or with `nmap` utility and connect
to it via SSH.



System configuration
--------------------

The following information can be helpful when you connect to BarnacleOS router
and configure it:

* Root password is disabled
* User `user` has access via SSH with password `password`
* SSH host keys are generated at first startup,
  so fingerprint is different for each installation of the same image
* User has passwordless sudo
