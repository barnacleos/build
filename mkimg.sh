#!/bin/false

unmount() {
  if [ -z "$1" ]; then
    local DIR=$PWD
  else
    local DIR=$1
  fi

  while mount | grep -q "$DIR"; do
    local LOCS=$(mount | grep "$DIR" | cut -f 3 -d ' ' | sort -r)

    for loc in $LOCS; do
      umount "$loc"
    done
  done
}

unmount_image() {
  sync
  sleep 1
  local LOOP_DEVICES=$(losetup -j "$1" | cut -f 1 -d ':')

  for LOOP_DEV in $LOOP_DEVICES; do
    if [ -n "$LOOP_DEV" ]; then
      local MOUNTED_DIR=$(mount | grep "$(basename "$LOOP_DEV")" | head -n 1 | cut -f 3 -d ' ')

      if [ -n "$MOUNTED_DIR" ] && [ "$MOUNTED_DIR" != "/" ]; then
        unmount "$(dirname "$MOUNTED_DIR")"
      fi

      sleep 1
      losetup -d "$LOOP_DEV"
    fi
  done
}

if [ "$(id -u)" != '0' ]; then
  echo 'Please run as root' 1>&2
  exit 1
fi

if [ ! -d "$ROOTFS_DIR" ]; then
  echo "$ROOTFS_DIR is not a directory"
  exit 1
fi

if [ ! -d "$ROOTFS_DIR/boot" ]; then
  echo "$ROOTFS_DIR/boot is not a directory"
  exit 1
fi

if [ ! -d "$(dirname "$IMG_FILE")" ]; then
  echo "$(dirname "$IMG_FILE") is not a directory"
  exit 1
fi

##
# Prepare image file systems.
#
rm -f "$IMG_FILE"

BOOT_SIZE=$(du --apparent-size -s "$ROOTFS_DIR/boot" --block-size=1 | cut -f 1)
TOTAL_SIZE=$(du --apparent-size -s "$ROOTFS_DIR" --block-size=1 | cut -f 1)

IMG_SIZE=$((BOOT_SIZE + TOTAL_SIZE + (800 * 1024 * 1024)))

truncate -s $IMG_SIZE "$IMG_FILE"

fdisk -H 255 -S 63 "$IMG_FILE" <<EOF
o
n


8192
+$((BOOT_SIZE * 2 / 512))
p
t
c
n


8192


p
w
EOF

PARTED_OUT=$(parted -s "$IMG_FILE" unit b print)

BOOT_OFFSET=$(echo "$PARTED_OUT" | grep -e '^ 1' | xargs echo -n | cut -d ' ' -f 2 | tr -d B)
BOOT_LENGTH=$(echo "$PARTED_OUT" | grep -e '^ 1' | xargs echo -n | cut -d ' ' -f 4 | tr -d B)
ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e '^ 2' | xargs echo -n | cut -d ' ' -f 2 | tr -d B)
ROOT_LENGTH=$(echo "$PARTED_OUT" | grep -e '^ 2' | xargs echo -n | cut -d ' ' -f 4 | tr -d B)

BOOT_DEV=$(losetup --show -f -o $BOOT_OFFSET --sizelimit $BOOT_LENGTH "$IMG_FILE")
ROOT_DEV=$(losetup --show -f -o $ROOT_OFFSET --sizelimit $ROOT_LENGTH "$IMG_FILE")

mkdosfs -n boot -F 32 -v $BOOT_DEV > /dev/null
mkfs.ext4 -O ^huge_file  $ROOT_DEV > /dev/null

##
# Mount image file systems.
#
mkdir -p           "$MOUNT_DIR"
mount -v $ROOT_DEV "$MOUNT_DIR" -t ext4

mkdir -p           "$MOUNT_DIR/boot/"
mount -v $BOOT_DEV "$MOUNT_DIR/boot/" -t vfat

##
# Copy root file system to image file systems.
#
rsync -aHAXx "$ROOTFS_DIR/" "$MOUNT_DIR/"

##
# Store file system UUIDs to configuration files.
#
IMGID="$(fdisk -l "$IMG_FILE" | sed -n 's/Disk identifier: 0x\([^ ]*\)/\1/p')"

BOOT_PARTUUID="$IMGID-01"
ROOT_PARTUUID="$IMGID-02"

sed -i "s/PARTUUID=BOOTUUID/PARTUUID=$BOOT_PARTUUID/" "$MOUNT_DIR/etc/fstab"
sed -i "s/PARTUUID=ROOTUUID/PARTUUID=$ROOT_PARTUUID/" "$MOUNT_DIR/etc/fstab"
sed -i "s/PARTUUID=ROOTUUID/PARTUUID=$ROOT_PARTUUID/" "$MOUNT_DIR/boot/cmdline.txt"

##
# Unmount all file systems and minimize image file for distribution.
#
ROOT_DEV=$(mount | grep "$MOUNT_DIR " | cut -f 1 -d ' ')
umount "$MOUNT_DIR/boot/"
umount "$MOUNT_DIR"
zerofree -v "$ROOT_DEV"
unmount_image "$IMG_FILE"
