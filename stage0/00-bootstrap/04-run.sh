#!/bin/bash -e

install -m 644 files/ipv6.conf  "$ROOTFS_DIR/etc/modprobe.d/ipv6.conf"
install -m 644 files/interfaces "$ROOTFS_DIR/etc/network/interfaces"

echo $HOSTNAME > "$ROOTFS_DIR/etc/hostname"
chmod 644        "$ROOTFS_DIR/etc/hostname"

echo "127.0.1.1 $HOSTNAME" >>/etc/hosts

on_chroot << EOF
dpkg-divert --add --local /lib/udev/rules.d/75-persistent-net-generator.rules
EOF

on_chroot << EOF
apt-get install -y \
libraspberrypi-bin \
libraspberrypi0    \
raspi-config
EOF

touch ${ROOTFS_DIR}/spindle_install

on_chroot << EOF
apt-get install -y raspi-copies-and-fills
EOF

rm -f ${ROOTFS_DIR}/spindle_install
