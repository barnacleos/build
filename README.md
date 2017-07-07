barnacleos/build
================

Tool used to create the [BarnacleOS](https://github.com/barnacleos) images.
Based on [pi-gen](https://github.com/rpi-distro/pi-gen) tool used to create
the official [raspberrypi.org](https://raspberrypi.org) Raspbian images.



Dependencies
------------

On Debian-based systems:

```bash
apt-get install bash quilt parted qemu-user-static debootstrap zerofree zip \
dosfstools libcap2-bin grep rsync
```

The file `depends` contains a list of tools needed. The format of this
file is `<tool>[:<debian-package>]`.



Network configuration
---------------------

* Hostname:  `barnacleos`
* FQDN:      `barnacleos.local`
* Subnet:    `192.168.82.0/24` (netmask `255.255.255.0`)
* Gateway:   `192.168.82.1`
* Broadcast: `192.168.82.255`
* IP range:  `192.168.82.2` to `192.168.82.254`



System configuration
--------------------

* Root login via SSH is disabled

* Root password is disabled

* User `user` has access via SSH with password `password`

* SSH host keys are generated at first startup,
  so fingerprint is different for each installation of the same image

* User has passwordless sudo
