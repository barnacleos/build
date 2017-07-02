log() {
  tput setaf 2 # Green color
  date +"[%T] $@"
  tput sgr0 # No color

  date +"[%T] $@" >> "$LOG_FILE"
}
export -f log

bootstrap() {
	local ARCH
	ARCH=$(dpkg --print-architecture)

	export http_proxy=${APT_PROXY}

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
export -f bootstrap

copy_previous() {
	if [ ! -d "${PREV_ROOTFS_DIR}" ]; then
		echo "Previous stage rootfs not found"
		false
	fi
	mkdir -p "${ROOTFS_DIR}"
	rsync -aHAXx --exclude var/cache/apt/archives "${PREV_ROOTFS_DIR}/" "${ROOTFS_DIR}/"
}
export -f copy_previous

unmount() {
	if [ -z "$1" ]; then
		DIR=$PWD
	else
		DIR=$1
	fi

	while mount | grep -q "$DIR"; do
		local LOCS
		LOCS=$(mount | grep "$DIR" | cut -f 3 -d ' ' | sort -r)
		for loc in $LOCS; do
			umount "$loc"
		done
	done
}
export -f unmount

unmount_image() {
	sync
	sleep 1
	local LOOP_DEVICES
	LOOP_DEVICES=$(losetup -j "${1}" | cut -f1 -d':')
	for LOOP_DEV in ${LOOP_DEVICES}; do
		if [ -n "${LOOP_DEV}" ]; then
			local MOUNTED_DIR
			MOUNTED_DIR=$(mount | grep "$(basename "${LOOP_DEV}")" | head -n 1 | cut -f 3 -d ' ')
			if [ -n "${MOUNTED_DIR}" ] && [ "${MOUNTED_DIR}" != "/" ]; then
				unmount "$(dirname "${MOUNTED_DIR}")"
			fi
			sleep 1
			losetup -d "${LOOP_DEV}"
		fi
	done
}
export -f unmount_image

on_chroot() {
	if ! mount | grep -q "$(realpath "${ROOTFS_DIR}"/proc)"; then
		mount -t proc proc "${ROOTFS_DIR}/proc"
	fi

	if ! mount | grep -q "$(realpath "${ROOTFS_DIR}"/dev)"; then
		mount --bind /dev "${ROOTFS_DIR}/dev"
	fi
	
	if ! mount | grep -q "$(realpath "${ROOTFS_DIR}"/dev/pts)"; then
		mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts"
	fi

	if ! mount | grep -q "$(realpath "${ROOTFS_DIR}"/sys)"; then
		mount --bind /sys "${ROOTFS_DIR}/sys"
	fi

	capsh --drop=cap_setfcap "--chroot=${ROOTFS_DIR}/" -- "$@"
}
export -f on_chroot

