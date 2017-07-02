#!/bin/bash -e

install -m 644 files/sources.list ${ROOTFS_DIR}/etc/apt/
install -m 644 files/raspi.list ${ROOTFS_DIR}/etc/apt/sources.list.d/

on_chroot apt-key add - < files/raspberrypi.gpg.key
on_chroot << EOF
apt-get update
apt-get dist-upgrade -y
EOF
