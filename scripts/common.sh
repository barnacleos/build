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

on_chroot() {
  local proc_fs="$ROOTFS_DIR/proc"
  local dev_fs="$ROOTFS_DIR/dev"
  local devpts_fs="$ROOTFS_DIR/dev/pts"
  local sys_fs="$ROOTFS_DIR/sys"

  mount --bind /dev     "$dev_fs"
  mount --bind /dev/pts "$devpts_fs"
  mount -t proc proc    "$proc_fs"
  mount --bind /sys     "$sys_fs"

  capsh --drop=cap_setfcap "--chroot=$ROOTFS_DIR/" -- "$@"

  umount "$sys_fs"
  umount "$proc_fs"
  umount "$devpts_fs"
  umount "$dev_fs"
}

export -f unmount
export -f unmount_image
export -f on_chroot
