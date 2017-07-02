#!/bin/bash -e

if [ ! -d "$ROOTFS_DIR" ]; then
  ARCH="$(dpkg --print-architecture)"

  if [ "$ARCH" != 'armhf' ]; then
    BOOTSTRAP_CMD='qemu-debootstrap'
  else
    BOOTSTRAP_CMD='debootstrap'
  fi

  capsh --drop=cap_setfcap -- -c "$BOOTSTRAP_CMD   \
    --components=main,contrib,non-free             \
    --arch armhf                                   \
    --keyring ./files/raspberrypi.gpg              \
    jessie                                         \
    $ROOTFS_DIR                                    \
    http://mirrordirector.raspbian.org/raspbian/" || rmdir "$ROOTFS_DIR/debootstrap"
fi
