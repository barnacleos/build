#!/bin/bash -e

on_chroot << EOF
/etc/init.d/fake-hwclock stop
hardlink -t /usr/share/doc
EOF

if [ -d ${ROOTFS_DIR}/home/$USERNAME/.config ]; then
  chmod 700 ${ROOTFS_DIR}/home/$USERNAME/.config
fi

rm -f ${ROOTFS_DIR}/etc/apt/apt.conf.d/51cache
rm -f ${ROOTFS_DIR}/usr/sbin/policy-rc.d
rm -f ${ROOTFS_DIR}/usr/bin/qemu-arm-static

if [ -e ${ROOTFS_DIR}/etc/ld.so.preload.disabled ]; then
  mv ${ROOTFS_DIR}/etc/ld.so.preload.disabled ${ROOTFS_DIR}/etc/ld.so.preload
fi

rm -f ${ROOTFS_DIR}/etc/apt/sources.list~
rm -f ${ROOTFS_DIR}/etc/apt/trusted.gpg~

rm -f ${ROOTFS_DIR}/etc/passwd-
rm -f ${ROOTFS_DIR}/etc/group-
rm -f ${ROOTFS_DIR}/etc/shadow-
rm -f ${ROOTFS_DIR}/etc/gshadow-

rm -f ${ROOTFS_DIR}/var/cache/debconf/*-old
rm -f ${ROOTFS_DIR}/var/lib/dpkg/*-old

rm -f ${ROOTFS_DIR}/usr/share/icons/*/icon-theme.cache

rm -f ${ROOTFS_DIR}/var/lib/dbus/machine-id

true > ${ROOTFS_DIR}/etc/machine-id

ln -nsf /proc/mounts ${ROOTFS_DIR}/etc/mtab

for _FILE in $(find ${ROOTFS_DIR}/var/log/ -type f); do
  true > ${_FILE}
done

rm -f "${ROOTFS_DIR}/root/.vnc/private.key"

ROOT_DEV=$(mount | grep "${ROOTFS_DIR} " | cut -f1 -d' ')

unmount ${ROOTFS_DIR}
zerofree -v ${ROOT_DEV}

unmount_image ${IMG_FILE}

rm -f "$ZIP_FILE"

echo zip "$ZIP_FILE" ${IMG_FILE}

pushd ${STAGE_WORK_DIR} > /dev/null
zip "$ZIP_FILE" $(basename ${IMG_FILE})
popd > /dev/null
