#!/bin/bash -e

if [ ! -d "$ROOTFS_DIR" ]; then
  ARCH="$(dpkg --print-architecture)"

  if [ "$ARCH" != 'armhf' ]; then
    BOOTSTRAP_CMD='qemu-debootstrap'
  else
    BOOTSTRAP_CMD='debootstrap'
  fi

  capsh --drop=cap_setfcap -- -c "$BOOTSTRAP_CMD \
    --components=main,contrib,non-free           \
    --arch armhf                                 \
    --keyring ./files/raspberrypi.gpg            \
    jessie                                       \
    $ROOTFS_DIR                                  \
    http://mirrordirector.raspbian.org/raspbian/" || rmdir "$ROOTFS_DIR/debootstrap"
fi

install -m 644 files/sources.list "$ROOTFS_DIR/etc/apt/"
install -m 644 files/raspi.list   "$ROOTFS_DIR/etc/apt/sources.list.d/"

on_chroot apt-key add - < files/raspberrypi.gpg.key

on_chroot << EOF
apt-get update
apt-get dist-upgrade -y
EOF

on_chroot << EOF
debconf-set-selections <<SELEOF
locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8
locales locales/default_environment_locale select en_US.UTF-8
SELEOF
EOF

on_chroot << EOF
apt-get install -y     \
locales                \
raspberrypi-bootloader \
ssh
EOF

install -m 644 files/cmdline.txt "$ROOTFS_DIR/boot"
install -m 644 files/config.txt  "$ROOTFS_DIR/boot"

apply_patches 'patches/01'

install -d                        "$ROOTFS_DIR/etc/systemd/system/getty@tty1.service.d"
install -m 644 files/noclear.conf "$ROOTFS_DIR/etc/systemd/system/getty@tty1.service.d/noclear.conf"
install -m 744 files/policy-rc.d  "$ROOTFS_DIR/usr/sbin/policy-rc.d" #TODO: Necessary in systemd?
install -m 644 files/fstab        "$ROOTFS_DIR/etc/fstab"
install -m 644 files/ipv6.conf    "$ROOTFS_DIR/etc/modprobe.d/ipv6.conf"
install -m 644 files/interfaces   "$ROOTFS_DIR/etc/network/interfaces"

echo $HOSTNAME > "$ROOTFS_DIR/etc/hostname"
chmod 644        "$ROOTFS_DIR/etc/hostname"

echo "127.0.1.1 $HOSTNAME" >>/etc/hosts

on_chroot << EOF
if ! id -u $USERNAME >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" $USERNAME
fi
echo "$USERNAME:$PASSWORD" | chpasswd
passwd -d root
EOF

on_chroot << EOF
dpkg-divert --add --local /lib/udev/rules.d/75-persistent-net-generator.rules
EOF

touch ${ROOTFS_DIR}/spindle_install

on_chroot << EOF
apt-get install -y raspi-copies-and-fills
EOF

rm -f ${ROOTFS_DIR}/spindle_install

on_chroot << EOF
debconf-set-selections <<SELEOF

console-setup console-setup/charmap47  select UTF-8
console-setup console-setup/codeset47  select Guess optimal character set
console-setup console-setup/fontface47 select Do not change the boot/kernel font

tzdata tzdata/Areas     select Etc
tzdata tzdata/Zones/Etc select UTC

keyboard-configuration keyboard-configuration/altgr         select The default for the keyboard layout
keyboard-configuration keyboard-configuration/model         select Generic 105-key (Intl) PC
keyboard-configuration keyboard-configuration/xkb-keymap    select gb
keyboard-configuration keyboard-configuration/compose       select No compose key
keyboard-configuration keyboard-configuration/ctrl_alt_bksp boolean true
keyboard-configuration keyboard-configuration/variant       select English (UK)

SELEOF
EOF

on_chroot << EOF
apt-get install -y     \
libraspberrypi-bin     \
libraspberrypi0        \
raspi-config           \
less                   \
fbset                  \
sudo                   \
psmisc                 \
strace                 \
module-init-tools      \
ed                     \
ncdu                   \
crda                   \
console-setup          \
keyboard-configuration \
debconf-utils          \
parted                 \
unzip                  \
manpages-dev           \
bash-completion        \
gdb                    \
pkg-config             \
v4l-utils              \
avahi-daemon           \
hardlink               \
ca-certificates        \
curl                   \
fake-hwclock           \
ntp                    \
usbutils               \
libraspberrypi-dev     \
libraspberrypi-doc     \
libfreetype6-dev       \
dosfstools             \
dphys-swapfile         \
raspberrypi-sys-mods   \
apt-listchanges        \
usb-modeswitch         \
apt-transport-https    \
libpam-chksshpwd
EOF

on_chroot << EOF
apt-get install --no-install-recommends -y cifs-utils
EOF
