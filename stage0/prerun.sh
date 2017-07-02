#!/bin/bash -e

bootstrap() {
	local ARCH
	ARCH=$(dpkg --print-architecture)

	if [ "$ARCH" !=  "armhf" ]; then
		local BOOTSTRAP_CMD=qemu-debootstrap
	else
		local BOOTSTRAP_CMD=debootstrap
	fi

	capsh --drop=cap_setfcap -- -c "${BOOTSTRAP_CMD} --components=main,contrib,non-free \
		--arch armhf \
		--keyring "${STAGE_DIR}/files/raspberrypi.gpg" \
		$1 $2 $3" || rmdir "$2/debootstrap"
}

if [ ! -d ${ROOTFS_DIR} ]; then
	bootstrap jessie ${ROOTFS_DIR} http://mirrordirector.raspbian.org/raspbian/
fi
