barnacleos/build
================

Tool used to create the [BarnacleOS](https://github.com/barnacleos) images.
Based on [pi-gen](https://github.com/rpi-distro/pi-gen) tool used to create
the official [raspberrypi.org](https://raspberrypi.org) Raspbian images.



Table of contents
-----------------

* [Dependencies](#dependencies)
* [Build](#build)
* [Network interfaces](#network-interfaces)
  * [eth0](#eth0)
  * [eth1](#eth1)
* [System configuration](#system-configuration)
* [Internal network](#internal-network)



Dependencies
------------

On Debian-based systems:

```bash
apt-get install bash quilt parted qemu-user-static debootstrap zerofree zip \
dosfstools libcap2-bin grep rsync
```

The file `depends` contains a list of tools needed. The format of this
file is `<tool>[:<debian-package>]`.



Build
-----

Run `sudo ./build.sh` to build the image. The following files will be created:

* `rootfs/` - the root file system (`/` and `/boot/` partitions)
* `deploy/BarnacleOS-YYYY-MM-DD.img` - the image to write to SD card
* `deploy/BarnacleOS-YYYY-MM-DD.zip` - ZIP archive with the image



Network interfaces
------------------

Each network interface of Raspberry Pi can be used to connect to the Internet or
to be the gateway for [the internal network](#internal-network).
The [barnaconfig](https://github.com/barnacleos/barnaconfig) utility can be used
to configure the role of each network interface.

However some initial configuration may be required to use the default BarnacleOS
image, such as Wi-Fi drivers installation. It can be done via SSH. Network
interfaces [eth0](#eth0) and [eth1](#eth1) have default configurations to help
you to connect.

### eth0

`eth0` is configured by default to get IPv4 address from router via DHCP
without any assumptions about subnet configuration. You can just plug
your Raspberry Pi to router with Ethernet cable, discover which address
was given to it in router's web interface or with `nmap` utility and connect
to it via SSH.

Let's say your router has address `192.168.0.1`, subnet is `192.168.0.0/24`
(netmask `255.255.255.0`), your computer has address `192.168.0.2`.
Do the following:

```
$ sudo apt-get install nmap
$ nmap -sn 192.168.0.0/24
Starting Nmap 6.47 ( http://nmap.org ) at 2017-07-09 15:39 UTC
Nmap scan report for 192.168.0.1
Host is up (0.0039s latency).
Nmap scan report for 192.168.0.2
Host is up (0.00078s latency).
Nmap scan report for 192.168.0.3
Host is up (0.00104s latence).
Nmap done: 256 IP addresses (3 hosts up) scanned in 7.97 seconds
```

So your Raspbbery Pi has address `192.168.0.3`. Connect to it via SSH:

```
$ ssh user@192.168.0.3
```

### eth1

`eth1` is configured by default to be the gateway and the DHCP server
for the IPv4 subnet `192.168.82.0/24` (netmask `255.255.255.0`,
[the internal network](#internal-network)) with static address `192.168.82.1`.
If your Raspberry Pi has two Ethernet ports, you can just plug your computer
to it, run DHCP client on the corresponding network interface and connect
to it via SSH.

Let's say your computer has network interface `eth42` which is plugged to
Raspberry Pi. Do the following to connect to Raspberry Pi via SSH:

```
$ printf "allow-hotplug eth42\niface eth42 inet dhcp\n" | sudo tee /etc/network/interfaces.d/eth42
$ sudo ifup eth42
$ ssh user@192.168.82.1
```



System configuration
--------------------

The following information can be helpful when you connect to BarnacleOS router
and configure it:

* Root login via SSH is disabled
* Root password is disabled
* User `user` has access via SSH with password `password`
* SSH host keys are generated at first startup,
  so fingerprint is different for each installation of the same image
* User has passwordless sudo



Internal network
----------------

BarnacleOS is the typical IPv4 router with it's own internal network. Multiple
devices can be connected to it. DHCP server assigns IPv4 addresses to devices.
As a gateway, it sends all traffic from internal network to the Internet through
[the Tor network](https://torproject.org). The local traffic is rejected. Kernel
IP forwarding is disabled. Here is the internal network configuration:

* Hostname:  `barnacleos`
* FQDN:      `barnacleos.local`
* Subnet:    `192.168.82.0/24` (netmask `255.255.255.0`)
* Gateway:   `192.168.82.1`
* Broadcast: `192.168.82.255`
* IP range:  `192.168.82.2` to `192.168.82.254`
