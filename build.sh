#!/bin/bash -e

export IMG_NAME='BarnacleOS'
export HOSTNAME='barnacleos'
export USERNAME='user'
export PASSWORD='password'

export BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR="$BASE_DIR/scripts"
export FUNCTIONS_DIR="$BASE_DIR/functions"
export DEPLOY_DIR="$BASE_DIR/deploy"
export ROOTFS_DIR="$BASE_DIR/rootfs"
export MOUNT_DIR="$BASE_DIR/mnt"

export IMG_DATE="$(date +%Y-%m-%d)"

export IMG_FILE="$DEPLOY_DIR/$IMG_DATE-${IMG_NAME}.img"
export ZIP_FILE="$DEPLOY_DIR/$IMG_DATE-${IMG_NAME}.zip"

export QUILT_NO_DIFF_INDEX=1
export QUILT_NO_DIFF_TIMESTAMPS=1
export QUILT_REFRESH_ARGS='-p ab'

source "$FUNCTIONS_DIR/logging.sh"
source "$FUNCTIONS_DIR/dependencies_check.sh"

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

apply_patches() {
  if [ ! -d "$1" ]; then
    echo "Patches directory does not exist: $1"
    exit 1
  fi

  pushd "$ROOTFS_DIR" > /dev/null

  export QUILT_PATCHES="$1"

  rm -rf   .pc
  mkdir -p .pc

  quilt upgrade
  RC=0
  quilt push -a || RC=$?

  case "$RC" in
  0|2)
    ;;
  *)
    false
    ;;
  esac

  rm -rf .pc

  popd > /dev/null
}

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

if [ "$(id -u)" != '0' ]; then
  echo 'Please run as root' 1>&2
  exit 1
fi

dependencies_check "$BASE_DIR/depends"

mkdir -p "$DEPLOY_DIR"
mkdir -p "$MOUNT_DIR"

cd "$BASE_DIR"

if [ ! -d "$ROOTFS_DIR" ]; then
  ARCH="$(dpkg --print-architecture)"

  if [ "$ARCH" != 'armhf' ]; then
    BOOTSTRAP_CMD='qemu-debootstrap'
  else
    BOOTSTRAP_CMD='debootstrap'
  fi

  capsh --drop=cap_setfcap -- -c "$BOOTSTRAP_CMD \
    --components=main,contrib,non-free           \
    --arch armhf                                 \
    --keyring ./files/raspberrypi.gpg            \
    jessie                                       \
    $ROOTFS_DIR                                  \
    http://mirrordirector.raspbian.org/raspbian/" || rmdir "$ROOTFS_DIR/debootstrap"
fi

install -m 644 files/sources.list "$ROOTFS_DIR/etc/apt/"
install -m 644 files/raspi.list   "$ROOTFS_DIR/etc/apt/sources.list.d/"

on_chroot apt-key add - < files/raspberrypi.gpg.key

on_chroot << EOF
apt-get update
apt-get dist-upgrade -y
EOF

on_chroot << EOF
debconf-set-selections <<SELEOF
locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8
locales locales/default_environment_locale select en_US.UTF-8
SELEOF
EOF

on_chroot << EOF
apt-get install -y     \
locales                \
raspberrypi-bootloader \
ssh
EOF

install -m 644 files/cmdline.txt "$ROOTFS_DIR/boot"
install -m 644 files/config.txt  "$ROOTFS_DIR/boot"

apply_patches "$BASE_DIR/patches/01"

install -d                        "$ROOTFS_DIR/etc/systemd/system/getty@tty1.service.d"
install -m 644 files/noclear.conf "$ROOTFS_DIR/etc/systemd/system/getty@tty1.service.d/noclear.conf"
install -m 744 files/policy-rc.d  "$ROOTFS_DIR/usr/sbin/policy-rc.d" #TODO: Necessary in systemd?
install -m 644 files/fstab        "$ROOTFS_DIR/etc/fstab"
install -m 644 files/ipv6.conf    "$ROOTFS_DIR/etc/modprobe.d/ipv6.conf"
install -m 644 files/interfaces   "$ROOTFS_DIR/etc/network/interfaces"

echo $HOSTNAME > "$ROOTFS_DIR/etc/hostname"
chmod 644        "$ROOTFS_DIR/etc/hostname"

echo "127.0.1.1 $HOSTNAME" >>/etc/hosts

on_chroot << EOF
if ! id -u $USERNAME >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" $USERNAME
fi
echo "$USERNAME:$PASSWORD" | chpasswd
passwd -d root
EOF

on_chroot << EOF
dpkg-divert --add --local /lib/udev/rules.d/75-persistent-net-generator.rules
EOF

touch "$ROOTFS_DIR/spindle_install"

on_chroot << EOF
apt-get install -y raspi-copies-and-fills
EOF

rm -f "$ROOTFS_DIR/spindle_install"

on_chroot << EOF
debconf-set-selections <<SELEOF

console-setup console-setup/charmap47  select UTF-8
console-setup console-setup/codeset47  select Guess optimal character set
console-setup console-setup/fontface47 select Do not change the boot/kernel font

tzdata tzdata/Areas     select Etc
tzdata tzdata/Zones/Etc select UTC

keyboard-configuration keyboard-configuration/altgr         select The default for the keyboard layout
keyboard-configuration keyboard-configuration/model         select Generic 105-key (Intl) PC
keyboard-configuration keyboard-configuration/xkb-keymap    select gb
keyboard-configuration keyboard-configuration/compose       select No compose key
keyboard-configuration keyboard-configuration/ctrl_alt_bksp boolean true
keyboard-configuration keyboard-configuration/variant       select English (UK)

SELEOF
EOF

on_chroot << EOF
apt-get install -y     \
libraspberrypi-bin     \
libraspberrypi0        \
raspi-config           \
less                   \
fbset                  \
sudo                   \
psmisc                 \
strace                 \
module-init-tools      \
ed                     \
ncdu                   \
crda                   \
console-setup          \
keyboard-configuration \
debconf-utils          \
parted                 \
unzip                  \
manpages-dev           \
bash-completion        \
gdb                    \
pkg-config             \
v4l-utils              \
avahi-daemon           \
hardlink               \
ca-certificates        \
curl                   \
fake-hwclock           \
ntp                    \
usbutils               \
libraspberrypi-dev     \
libraspberrypi-doc     \
libfreetype6-dev       \
dosfstools             \
dphys-swapfile         \
raspberrypi-sys-mods   \
apt-listchanges        \
usb-modeswitch         \
apt-transport-https    \
libpam-chksshpwd
EOF

on_chroot << EOF
apt-get install --no-install-recommends -y cifs-utils
EOF

apply_patches "$BASE_DIR/patches/02"

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

BOOT_SIZE=$(du --apparent-size -s "$ROOTFS_DIR/boot" --block-size=1 | cut -f 1)
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

if [ -e "$MOUNT_DIR/etc/ld.so.preload" ]; then
  mv "$MOUNT_DIR/etc/ld.so.preload" "$MOUNT_DIR/etc/ld.so.preload.disabled"
fi

if [ ! -x "$MOUNT_DIR/usr/bin/qemu-arm-static" ]; then
  cp /usr/bin/qemu-arm-static "$MOUNT_DIR/usr/bin/"
fi

install -m 644 files/resolv.conf "$MOUNT_DIR/etc/"

IMGID="$(fdisk -l "$IMG_FILE" | sed -n 's/Disk identifier: 0x\([^ ]*\)/\1/p')"

BOOT_PARTUUID="$IMGID-01"
ROOT_PARTUUID="$IMGID-02"

sed -i "s/BOOTDEV/PARTUUID=$BOOT_PARTUUID/" "$MOUNT_DIR/etc/fstab"
sed -i "s/ROOTDEV/PARTUUID=$ROOT_PARTUUID/" "$MOUNT_DIR/etc/fstab"
sed -i "s/ROOTDEV/PARTUUID=$ROOT_PARTUUID/" "$MOUNT_DIR/boot/cmdline.txt"

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

pushd $(dirname "$IMG_FILE") > /dev/null
zip "$ZIP_FILE" $(basename "$IMG_FILE")
popd > /dev/null
