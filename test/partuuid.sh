#!/bin/false

PARTED_OUT=$(parted -s "$IMG_FILE" unit b print)

BOOT_OFFSET=$(echo "$PARTED_OUT" | grep -e '^ 1' | xargs echo -n | cut -d ' ' -f 2 | tr -d B)
BOOT_LENGTH=$(echo "$PARTED_OUT" | grep -e '^ 1' | xargs echo -n | cut -d ' ' -f 4 | tr -d B)
ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e '^ 2' | xargs echo -n | cut -d ' ' -f 2 | tr -d B)
ROOT_LENGTH=$(echo "$PARTED_OUT" | grep -e '^ 2' | xargs echo -n | cut -d ' ' -f 4 | tr -d B)

BOOT_DEV=$(losetup --show -f -o $BOOT_OFFSET --sizelimit $BOOT_LENGTH "$IMG_FILE")
ROOT_DEV=$(losetup --show -f -o $ROOT_OFFSET --sizelimit $ROOT_LENGTH "$IMG_FILE")

MOUNT_DIR="$(mktemp --directory)"

mkdir -p           "$MOUNT_DIR"
mount -v $ROOT_DEV "$MOUNT_DIR" -t ext4

mkdir -p           "$MOUNT_DIR/boot/"
mount -v $BOOT_DEV "$MOUNT_DIR/boot/" -t vfat

echo

function finalize {
  echo

  umount -v "$MOUNT_DIR/boot/"
  umount -v "$MOUNT_DIR"

  rmdir "$MOUNT_DIR"

  losetup -d "$BOOT_DEV"
  losetup -d "$ROOT_DEV"
}

trap finalize EXIT

IMGID="$(fdisk -l "$IMG_FILE" | sed -n 's/Disk identifier: 0x\([^ ]*\)/\1/p')"

BOOT_PARTUUID="$IMGID-01"
ROOT_PARTUUID="$IMGID-02"

grep --color "PARTUUID=$BOOT_PARTUUID" "$MOUNT_DIR/etc/fstab"
grep --color "PARTUUID=$ROOT_PARTUUID" "$MOUNT_DIR/etc/fstab"
grep --color "PARTUUID=$ROOT_PARTUUID" "$MOUNT_DIR/boot/cmdline.txt"
