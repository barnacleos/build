#!/bin/bash -e

touch ${ROOTFS_DIR}/spindle_install

on_chroot << EOF
apt-get install -y raspi-copies-and-fills
EOF

rm -f ${ROOTFS_DIR}/spindle_install
