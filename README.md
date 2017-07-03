barnacleos/build
================

Tool used to create the [BarnacleOS](https://github.com/barnacleos) images.
Based on [pi-gen](https://github.com/rpi-distro/pi-gen) tool used to create
the official [raspberrypi.org](https://raspberrypi.org) Raspbian images.



Dependencies
------------

On Debian-based systems:

```bash
apt-get install quilt parted qemu-user-static debootstrap zerofree zip \
dosfstools libcap2-bin grep rsync
```

The file `depends` contains a list of tools needed. The format of this
file is `<tool>[:<debian-package>]`.
