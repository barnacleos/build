#!/bin/bash -e

export IMG_NAME='BarnacleOS'
export HOSTNAME='barnacleos'
export USERNAME='user'
export PASSWORD='password'

export BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEPLOY_DIR="$BASE_DIR/deploy"
export ROOTFS_DIR="$BASE_DIR/rootfs"
export MOUNT_DIR="$BASE_DIR/mnt"

export IMG_DATE="$(date +%Y-%m-%d)"

export IMG_FILE="$DEPLOY_DIR/$IMG_DATE-${IMG_NAME}.img"
export ZIP_FILE="$DEPLOY_DIR/$IMG_DATE-${IMG_NAME}.zip"

export QUILT_NO_DIFF_INDEX=1
export QUILT_NO_DIFF_TIMESTAMPS=1
export QUILT_REFRESH_ARGS='-p ab'

# dependencies_check
# $@ Dependnecy files to check
#
# Each dependency is in the form of a tool to test for, optionally followed by
# a : and the name of a package if the package on a Debian-ish system is not
# named for the tool (i.e., qemu-user-static).
dependencies_check() {
  local missing

  if [[ -f "$1" ]]; then
    for dep in $(cat "$1"); do
      if ! hash ${dep%:*} 2>/dev/null; then
        missing="${missing:+$missing }${dep#*:}"
      fi
    done
  fi

  if [[ "$missing" ]]; then
    tput setaf 1 # Red color
    echo 'Reqired dependencies not installed.'
    echo 'This can be resolved on Debian/Raspbian systems by installing the following packages:'
    for package_name in $missing; do
      echo "  * $package_name"
    done
    tput sgr0 # No color

    false
  fi
}

on_chroot() {
  capsh --drop=cap_setfcap "--chroot=$ROOTFS_DIR/" -- "$@"
}

apply_patches() {
  pushd "$ROOTFS_DIR" > /dev/null

  export QUILT_PATCHES="$BASE_DIR/patches"

  quilt upgrade
  RC=0
  quilt push "$1" || RC=$?

  case "$RC" in
  0|2)
    ;;
  *)
    false
    ;;
  esac

  popd > /dev/null
}

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
  local LOOP_DEVICES=$(losetup -j "$1" | cut -f1 -d ':')

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

##
# Prepare environment.
#
if [ "$(id -u)" != '0' ]; then
  echo 'Please run as root' 1>&2
  exit 1
fi

dependencies_check "$BASE_DIR/depends"

mkdir -p "$DEPLOY_DIR"
mkdir -p "$MOUNT_DIR"

cd "$BASE_DIR"

##
# Bootstrap a basic Debian system.
#
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

##
# Prepare for Quilt patching.
#
rm -rf "$ROOTFS_DIR/.pc"
mkdir  "$ROOTFS_DIR/.pc"

##
# Prevent services to start after package installation in chroot environment.
#
install -m 744 files/policy-rc.d "$ROOTFS_DIR/usr/sbin/policy-rc.d"

##
# Mount virtual file systems.
#
mount --bind  /dev     "$ROOTFS_DIR/dev"
mount --bind  /dev/pts "$ROOTFS_DIR/dev/pts"
mount -t proc /proc    "$ROOTFS_DIR/proc"
mount --bind  /sys     "$ROOTFS_DIR/sys"

##
# Add /etc/fstab and /etc/mtab
#
install -m 644 files/fstab "$ROOTFS_DIR/etc/fstab"
ln -nsf /proc/mounts       "$ROOTFS_DIR/etc/mtab"

##
# Prepare package manager.
#
install -m 644 files/sources.list "$ROOTFS_DIR/etc/apt/"

on_chroot apt-key add - < files/raspberrypi.gpg.key

install -m 644 files/raspberrypi-kernel-and-bootloader "$ROOTFS_DIR/etc/apt/preferences.d/"

install -m 644 files/50raspi "$ROOTFS_DIR/etc/apt/apt.conf.d/"

on_chroot << EOF
apt-get update
apt-get dist-upgrade -y
EOF

##
# Prepare Raspberry Pi boot partition.
#
mkdir -p "$ROOTFS_DIR/boot/"

install -m 644 files/cmdline.txt "$ROOTFS_DIR/boot/"
install -m 644 files/config.txt  "$ROOTFS_DIR/boot/"

##
# This script is executed at the end of each multiuser runlevel.
#
install -m 755 files/rc.local "$ROOTFS_DIR/etc/rc.local"

##
# Install SSH server
#
on_chroot << EOF
apt-get install -y ssh
EOF

apply_patches '01-no-root-login.diff'

##
# Common system configuration.
#
on_chroot << EOF
apt-get install -y raspberrypi-bootloader
EOF

##
# Configure network.
#
apply_patches '02-persistant-net.diff'

on_chroot << EOF
dpkg-divert --add --local /lib/udev/rules.d/75-persistent-net-generator.rules
EOF

install -m 644 files/resolv.conf "$ROOTFS_DIR/etc/"
install -m 644 files/interfaces  "$ROOTFS_DIR/etc/network/interfaces"
install -m 644 files/ipv6.conf   "$ROOTFS_DIR/etc/modprobe.d/ipv6.conf"

echo $HOSTNAME > "$ROOTFS_DIR/etc/hostname"
chmod 644        "$ROOTFS_DIR/etc/hostname"

echo "127.0.1.1 $HOSTNAME" >>"$ROOTFS_DIR/etc/hosts"

##
# Add user.
#
apply_patches '03-bashrc.diff'
apply_patches '04-useradd.diff'

on_chroot << EOF
if ! id -u $USERNAME >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" $USERNAME
fi
echo "$USERNAME:$PASSWORD" | chpasswd
passwd -d root
adduser $USERNAME sudo
EOF

##
# Configure time zone.
#
on_chroot << EOF
debconf-set-selections <<SELEOF
tzdata tzdata/Areas     select Etc
tzdata tzdata/Zones/Etc select UTC
SELEOF

apt-get install -y tzdata
EOF

##
# Install additional packages which maybe can be removed safely.
#
on_chroot << EOF
apt-get install -y     \
libraspberrypi-bin     \
libraspberrypi0        \
less                   \
sudo                   \
psmisc                 \
module-init-tools      \
ed                     \
ncdu                   \
crda                   \
debconf-utils          \
parted                 \
unzip                  \
bash-completion        \
ca-certificates        \
curl                   \
ntp                    \
usbutils               \
libraspberrypi-dev     \
libraspberrypi-doc     \
libfreetype6-dev       \
dosfstools             \
dphys-swapfile         \
raspberrypi-sys-mods   \
usb-modeswitch         \
raspi-copies-and-fills
EOF

##
# Enable swap.
#
on_chroot << EOF
apt-get install -y dphys-swapfile
EOF

apply_patches '05-swap.diff'

##
# Configure environment.
#
apply_patches '06-path.diff'

##
# Wi-Fi firmware and tools.
#
on_chroot << EOF
apt-get install -y wpasupplicant wireless-tools
EOF

##
# DHCP client.
#
on_chroot << EOF
apt-get install -y dhcpcd5
EOF

##
# Save fake hardware clock time for more realistic time after startup.
#
on_chroot << EOF
apt-get install -y fake-hwclock
systemctl disable hwclock.sh
fake-hwclock save
EOF

##
# Unmount virtual file systems.
#
umount "$ROOTFS_DIR/sys"
umount "$ROOTFS_DIR/proc"
umount "$ROOTFS_DIR/dev/pts"
umount "$ROOTFS_DIR/dev"

##
# Cleanup after Quilt patching.
#
rm -rf "$ROOTFS_DIR/.pc"

##
# Allow services to start.
#
rm -f "$ROOTFS_DIR/usr/sbin/policy-rc.d"

##
# Prepare image file systems.
#
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
mkfs.ext4 -O ^huge_file  $ROOT_DEV > /dev/null

##
# Mount image file systems.
#
mkdir -p           "$MOUNT_DIR"
mount -v $ROOT_DEV "$MOUNT_DIR" -t ext4

mkdir -p           "$MOUNT_DIR/boot"
mount -v $BOOT_DEV "$MOUNT_DIR/boot" -t vfat

##
# Copy root file system to image file systems.
#
rsync -aHAXx --exclude var/cache/apt/archives "$ROOTFS_DIR/" "$MOUNT_DIR/"

##
# Store file system UUIDs to configuration files.
#
IMGID="$(fdisk -l "$IMG_FILE" | sed -n 's/Disk identifier: 0x\([^ ]*\)/\1/p')"

BOOT_PARTUUID="$IMGID-01"
ROOT_PARTUUID="$IMGID-02"

sed -i "s/BOOTDEV/PARTUUID=$BOOT_PARTUUID/" "$MOUNT_DIR/etc/fstab"
sed -i "s/ROOTDEV/PARTUUID=$ROOT_PARTUUID/" "$MOUNT_DIR/etc/fstab"
sed -i "s/ROOTDEV/PARTUUID=$ROOT_PARTUUID/" "$MOUNT_DIR/boot/cmdline.txt"

##
# Unmount all file systems and minimize image file for distribution.
#
ROOT_DEV=$(mount | grep "$MOUNT_DIR " | cut -f1 -d ' ')
umount "$MOUNT_DIR/boot"
umount "$MOUNT_DIR"
zerofree -v "$ROOT_DEV"
unmount_image "$IMG_FILE"

##
# Create zip archive with image file for distribution.
#
rm -f "$ZIP_FILE"
pushd $(dirname "$IMG_FILE") > /dev/null
zip "$ZIP_FILE" $(basename "$IMG_FILE")
popd > /dev/null
