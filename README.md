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
* [System configuration](#system-configuration)
* [Connect to Wi-Fi](#connect-to-wi-fi)



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

#### WARNING

> During the execution of `sudo ./run ./build.sh` host directories `/dev`,
> `/dev/pts`, `/proc` and `/sys` are binded info `rootfs/` to provide
> environment for chroot. They are unmounted in the end of script.
> However, script may fail, so they will remain mounted. If you run
> `sudo rm -rf rootfs/`, you can corrupt your host operating system
> state and you will have to reboot. Please be careful.



System configuration
--------------------

The following information can be helpful when you connect to BarnacleOS:

* Root password is disabled
* User `user` has access via SSH with password `password`
* SSH host keys are generated at first startup,
  so fingerprint is different for each installation of the same image
* User has passwordless sudo



Connect to Wi-Fi
----------------

```
wpa_passphrase "your-wi-fi-ssid" "your-wi-fi-passphrase" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf
sudo ifup wlan0
```
