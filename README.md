branacleos/build
================

Tool used to create the BarnacleOS images.



Dependencies
------------

On Debian-based systems:

```bash
apt-get install quilt parted realpath qemu-user-static debootstrap zerofree pxz zip \
dosfstools bsdtar libcap2-bin grep rsync
```

The file `depends` contains a list of tools needed. The format of this
package is `<tool>[:<debian-package>]`.



Stage Anatomy
-------------

### Raspbian Stage Overview

The build of Raspbian is divided up into several stages for logical clarity
and modularity. This causes some initial complexity, but it simplifies
maintenance and allows for more easy customization.

 - **Stage 0** - bootstrap. The primary purpose of this stage is to create a
   usable filesystem. This is accomplished largely through the use of
   `debootstrap`, which creates a minimal filesystem suitable for use as a
   base.tgz on Debian systems. This stage also configures apt settings and
   installs `raspberrypi-bootloader` which is missed by debootstrap. The
   minimal core is installed but not configured, and the system will not quite
   boot yet.

 - **Stage 1** - truly minimal system. This stage makes the system bootable by
   installing system files like `/etc/fstab`, configures the bootloader, makes
   the network operable, and installs packages like raspi-config. At this
   stage the system should boot to a local console from which you have the
   means to perform basic tasks needed to configure and install the system.
   This is as minimal as a system can possibly get, and its arguably not
   really usable yet in a traditional sense yet. Still, if you want minimal,
   this is minimal and the rest you could reasonably do yourself as sysadmin.

 - **Stage 2** - lite system. This stage produces the Raspbian-Lite image. It
   installs some optimized memory functions, sets timezone and charmap
   defaults, installs fake-hwclock and ntp, wifi and bluetooth support,
   dphys-swapfile, and other basics for managing the hardware. It also
   creates necessary groups and gives the pi user access to sudo and the
   standard console hardware permission groups.

   There are a few tools that may not make a whole lot of sense here for
   development purposes on a minimal system such as basic python and lua
   packages as well as the `build-essential` package. They are lumped right
   in with more essential packages presently, though they need not be with
   pi-gen. These are understandable for Raspbian's target audience, but if
   you were looking for something between truly minimal and Raspbian-lite,
   here's where you start trimming.

### Stage specification

If you wish to build up to a specified stage (such as building up to stage 2
for a lite system), place an empty file named `SKIP` in each of the `./stage`
directories you wish not to include.

Then remove the `EXPORT*` files from `./stage2` (if building a minimal system).
