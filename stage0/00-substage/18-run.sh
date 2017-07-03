#!/bin/bash -e

install -m 644 files/regenerate_ssh_host_keys.service "$ROOTFS_DIR/lib/systemd/system/"
install -m 755 files/resize2fs_once                   "$ROOTFS_DIR/etc/init.d/"

install -d                                            "$ROOTFS_DIR/etc/systemd/system/rc-local.service.d"
install -m 644 files/ttyoutput.conf                   "$ROOTFS_DIR/etc/systemd/system/rc-local.service.d/"

install -m 644 files/50raspi                          "$ROOTFS_DIR/etc/apt/apt.conf.d/"

install -m 644 files/console-setup                    "$ROOTFS_DIR/etc/default/"

on_chroot << EOF
systemctl disable hwclock.sh
systemctl disable rpcbind
systemctl enable regenerate_ssh_host_keys
systemctl enable resize2fs_once
EOF

on_chroot << \EOF
for GRP in input spi i2c gpio; do
  groupadd -f -r $GRP
done
for GRP in adm dialout cdrom audio users sudo video games plugdev input gpio spi i2c netdev; do
  adduser $USERNAME $GRP
done
EOF

on_chroot << EOF
setupcon --force --save-only -v
EOF

on_chroot << EOF
usermod --pass='*' root
EOF

rm -f "$ROOTFS_DIR/etc/ssh/ssh_host_*_key*"

on_chroot << EOF
apt-get install -y   \
wpasupplicant        \
wireless-tools       \
firmware-atheros     \
firmware-brcm80211   \
firmware-libertas    \
firmware-ralink      \
firmware-realtek     \
raspberrypi-net-mods \
dhcpcd5
EOF

install -v -d "$ROOTFS_DIR/etc/systemd/system/dhcpcd.service.d"

unmount_image "$IMG_FILE"

rm -f "$IMG_FILE"

BOOT_SIZE=$(du --apparent-size -s "$BOOTFS_DIR" --block-size=1 | cut -f 1)
TOTAL_SIZE=$(du --apparent-size -s "$ROOTFS_DIR" --exclude var/cache/apt/archives --block-size=1 | cut -f 1)

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

BOOT_OFFSET=$(echo "$PARTED_OUT" | grep -e '^ 1' | xargs echo -n \
| cut -d" " -f 2 | tr -d B)
BOOT_LENGTH=$(echo "$PARTED_OUT" | grep -e '^ 1' | xargs echo -n \
| cut -d" " -f 4 | tr -d B)
ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e '^ 2' | xargs echo -n \
| cut -d" " -f 2 | tr -d B)
ROOT_LENGTH=$(echo "$PARTED_OUT" | grep -e '^ 2' | xargs echo -n \
| cut -d" " -f 4 | tr -d B)

BOOT_DEV=$(losetup --show -f -o $BOOT_OFFSET --sizelimit $BOOT_LENGTH "$IMG_FILE")
ROOT_DEV=$(losetup --show -f -o $ROOT_OFFSET --sizelimit $ROOT_LENGTH "$IMG_FILE")

mkdosfs -n boot -F 32 -v $BOOT_DEV > /dev/null
mkfs.ext4 -O ^huge_file $ROOT_DEV > /dev/null

mkdir -p "$MOUNT_DIR"
mount -v $ROOT_DEV "$MOUNT_DIR" -t ext4

mkdir -p "$MOUNT_DIR/boot"
mount -v $BOOT_DEV "$MOUNT_DIR/boot" -t vfat

rsync -aHAXx --exclude var/cache/apt/archives "$ROOTFS_DIR/" "$MOUNT_DIR/"

if [ -e ${MOUNT_DIR}/etc/ld.so.preload ]; then
  mv ${MOUNT_DIR}/etc/ld.so.preload ${MOUNT_DIR}/etc/ld.so.preload.disabled
fi

if [ ! -x ${MOUNT_DIR}/usr/bin/qemu-arm-static ]; then
  cp /usr/bin/qemu-arm-static ${MOUNT_DIR}/usr/bin/
fi
