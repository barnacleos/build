#!/bin/false

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

rm -f "$IMG_FILE"

BOOT_SIZE=$(du --apparent-size -s "$ROOTFS_DIR/boot" --block-size=1 | cut -f 1)
TOTAL_SIZE=$(du --apparent-size -s "$ROOTFS_DIR" --block-size=1 | cut -f 1)

ROOT_SIZE=$((TOTAL_SIZE - BOOT_SIZE))

# Extend to reserve some free space.
BOOT_SIZE=$((BOOT_SIZE * 2))
ROOT_SIZE=$((ROOT_SIZE + 4 * 1024 * 1024 * 1024))

BLOCK_SIZE=512

echo "Requested boot partition size: $BOOT_SIZE"
echo "Requested root partition size: $ROOT_SIZE"

if [ $((BOOT_SIZE % BLOCK_SIZE)) -ne 0 ]; then
  BOOT_SIZE=$((BOOT_SIZE + BLOCK_SIZE - BOOT_SIZE % BLOCK_SIZE))
fi

if [ $((ROOT_SIZE % BLOCK_SIZE)) -ne 0 ]; then
  ROOT_SIZE=$((ROOT_SIZE + BLOCK_SIZE - ROOT_SIZE % BLOCK_SIZE))
fi

echo "Aligned boot partition size: $BOOT_SIZE"
echo "Aligned root partition size: $ROOT_SIZE"

BOOT_BLOCKS=$((BOOT_SIZE / BLOCK_SIZE))
ROOT_BLOCKS=$((ROOT_SIZE / BLOCK_SIZE))

echo "Boot partition blocks count: $BOOT_BLOCKS"
echo "Root partition blocks count: $ROOT_BLOCKS"

BOOT_START=8192

ROOT_START=$((BOOT_START + BOOT_BLOCKS + 1))

if [ $((ROOT_START % 4096)) -ne 0 ]; then
  ROOT_START=$((ROOT_START + 4096 - ROOT_START % 4096))
fi

echo "Boot partition start block: $BOOT_START"
echo "Root partition start block: $ROOT_START"

TOTAL_SIZE=$(((ROOT_START + ROOT_BLOCKS) * BLOCK_SIZE))

echo "Total size: $TOTAL_SIZE"

truncate -s $TOTAL_SIZE "$IMG_FILE"

fdisk -H 255 -S 63 "$IMG_FILE" > /dev/null <<EOF
o
n
p
1
$BOOT_START
+$((BOOT_BLOCKS - 1))
t
c
n
p
2
$ROOT_START
+$((ROOT_BLOCKS - 1))
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

MOUNT_DIR="$(mktemp --directory)"

mkdir -p           "$MOUNT_DIR"
mount -v $ROOT_DEV "$MOUNT_DIR" -t ext4

mkdir -p           "$MOUNT_DIR/boot/"
mount -v $BOOT_DEV "$MOUNT_DIR/boot/" -t vfat

function finalize {
  umount -v "$MOUNT_DIR/boot/"
  umount -v "$MOUNT_DIR"

  rmdir "$MOUNT_DIR"

  zerofree -v "$ROOT_DEV"

  losetup -d "$BOOT_DEV"
  losetup -d "$ROOT_DEV"
}

trap finalize EXIT

rsync -aHAXx "$ROOTFS_DIR/" "$MOUNT_DIR/"

IMGID="$(fdisk -l "$IMG_FILE" | sed -n 's/Disk identifier: 0x\([^ ]*\)/\1/p')"

sed -i "s/PARTUUID=00000000-01/PARTUUID=$IMGID-01/" "$MOUNT_DIR/etc/fstab"
sed -i "s/PARTUUID=00000000-02/PARTUUID=$IMGID-02/" "$MOUNT_DIR/etc/fstab"
sed -i "s/PARTUUID=00000000-02/PARTUUID=$IMGID-02/" "$MOUNT_DIR/boot/cmdline.txt"
