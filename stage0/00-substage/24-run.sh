#!/bin/bash -e

on_chroot << EOF
apt-get update
apt-get -y dist-upgrade
apt-get clean
EOF

install -m 644 files/resolv.conf ${MOUNT_DIR}/etc/

IMGID="$(fdisk -l "$IMG_FILE" | sed -n 's/Disk identifier: 0x\([^ ]*\)/\1/p')"

BOOT_PARTUUID="$IMGID-01"
ROOT_PARTUUID="$IMGID-02"

sed -i "s/BOOTDEV/PARTUUID=$BOOT_PARTUUID/" "$MOUNT_DIR/etc/fstab"
sed -i "s/ROOTDEV/PARTUUID=$ROOT_PARTUUID/" "$MOUNT_DIR/etc/fstab"
sed -i "s/ROOTDEV/PARTUUID=$ROOT_PARTUUID/" "$MOUNT_DIR/boot/cmdline.txt"

on_chroot << EOF
/etc/init.d/fake-hwclock stop
hardlink -t /usr/share/doc
EOF

if [ -d "$MOUNT_DIR/home/$USERNAME/.config" ]; then
  chmod 700 "$MOUNT_DIR/home/$USERNAME/.config"
fi

rm -f "$MOUNT_DIR/etc/apt/apt.conf.d/51cache"
rm -f "$MOUNT_DIR/usr/sbin/policy-rc.d"
rm -f "$MOUNT_DIR/usr/bin/qemu-arm-static"

if [ -e "$MOUNT_DIR/etc/ld.so.preload.disabled" ]; then
  mv "$MOUNT_DIR/etc/ld.so.preload.disabled" "$MOUNT_DIR/etc/ld.so.preload"
fi

rm -f "$MOUNT_DIR/etc/apt/sources.list~"
rm -f "$MOUNT_DIR/etc/apt/trusted.gpg~"

rm -f "$MOUNT_DIR/etc/passwd-"
rm -f "$MOUNT_DIR/etc/group-"
rm -f "$MOUNT_DIR/etc/shadow-"
rm -f "$MOUNT_DIR/etc/gshadow-"

rm -f "$MOUNT_DIR/var/cache/debconf/*-old"
rm -f "$MOUNT_DIR/var/lib/dpkg/*-old"

rm -f "$MOUNT_DIR/usr/share/icons/*/icon-theme.cache"

rm -f "$MOUNT_DIR/var/lib/dbus/machine-id"

true > "$MOUNT_DIR/etc/machine-id"

ln -nsf /proc/mounts "$MOUNT_DIR/etc/mtab"

for _FILE in $(find "$MOUNT_DIR/var/log/" -type f); do
  true > "$_FILE"
done

rm -f "$MOUNT_DIR/root/.vnc/private.key"

ROOT_DEV=$(mount | grep "$MOUNT_DIR " | cut -f1 -d' ')

unmount "$MOUNT_DIR"
zerofree -v "$ROOT_DEV"

unmount_image "$IMG_FILE"

rm -f "$ZIP_FILE"

pushd "$STAGE_WORK_DIR" > /dev/null
zip "$ZIP_FILE" $(basename "$IMG_FILE")
popd > /dev/null
