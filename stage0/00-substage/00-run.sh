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
raspberrypi-bootloader
EOF

install -m 644 files/cmdline.txt "$BOOTFS_DIR"
install -m 644 files/config.txt  "$BOOTFS_DIR"
