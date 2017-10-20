#!/bin/false

export QUILT_PATCHES="$BASE_DIR/patches"
export QUILT_NO_DIFF_INDEX=1
export QUILT_NO_DIFF_TIMESTAMPS=1
export QUILT_REFRESH_ARGS='-p ab'

on_chroot() {
  capsh --drop=cap_setfcap --chroot="$ROOTFS_DIR" -- "$@"
}

apply_patch() {
  pushd "$ROOTFS_DIR" > /dev/null

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

apply_file() {
  local MODE="$1"
  local FILE="$2"

  local SRC="$FILES_DIR/$FILE"
  local DST="$ROOTFS_DIR/$FILE"

  if [ ! -f "$SRC" ]; then
    tput setaf 1 # Red color
    echo "Source file $FILE does not exist"
    tput sgr0 # No color

    exit 1
  fi

  install -m "$MODE" "$SRC" "$DST"
}

if [ "$(id -u)" != '0' ]; then
  echo 'Please run as root' 1>&2
  exit 1
fi

if [ -e "$ROOTFS_DIR" ]; then
  rm -rf "$ROOTFS_DIR"
fi

mkdir "$ROOTFS_DIR"

##
# Bootstrap a basic Debian system.
#
ARCH="$(dpkg --print-architecture)"

if [ "$ARCH" != 'armhf' ]; then
  BOOTSTRAP_CMD='qemu-debootstrap'
else
  BOOTSTRAP_CMD='debootstrap'
fi

capsh --drop=cap_setfcap -- -c "$BOOTSTRAP_CMD     \
  --components=main,contrib,non-free               \
  --arch armhf                                     \
  --keyring $KEYS_DIR/raspbian-archive-keyring.gpg \
  --include=ca-certificates                        \
  jessie                                           \
  $ROOTFS_DIR                                      \
  http://mirrordirector.raspbian.org/raspbian/" || rmdir "$ROOTFS_DIR/debootstrap/"

##
# Prepare for Quilt patching.
#
rm -rf "$ROOTFS_DIR/.pc/"
mkdir  "$ROOTFS_DIR/.pc/"

##
# Prevent services to start after package installation in chroot environment.
#
apply_file 744 '/usr/sbin/policy-rc.d'

##
# Mount virtual file systems.
#
mount --bind  /dev     "$ROOTFS_DIR/dev"
mount --bind  /dev/pts "$ROOTFS_DIR/dev/pts"
mount -t proc /proc    "$ROOTFS_DIR/proc"
mount --bind  /sys     "$ROOTFS_DIR/sys"

function finalize {
  umount "$ROOTFS_DIR/sys"
  umount "$ROOTFS_DIR/proc"
  umount "$ROOTFS_DIR/dev/pts"
  umount "$ROOTFS_DIR/dev"
}

trap finalize EXIT

##
# Add /etc/environment
#
apply_file 644 '/etc/environment'

##
# Add /etc/fstab and /etc/mtab
#
apply_file 644 '/etc/fstab'
ln -nsf /proc/mounts "$ROOTFS_DIR/etc/mtab"

##
# Prepare package manager.
#
apply_file 644 '/etc/apt/sources.list'

on_chroot apt-key add - < "$KEYS_DIR/raspberrypi-archive-keyring.gpg"

apply_file 644 '/etc/apt/apt.conf.d/02noinstall'
apply_file 644 '/etc/apt/apt.conf.d/50pdiffs'

on_chroot << EOF
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y --purge
EOF

##
# Install kernel and bootloader.
#
on_chroot << EOF
apt-get install -y raspberrypi-kernel raspberrypi-bootloader
EOF

##
# Prepare Raspberry Pi boot partition.
#
apply_file 644 '/boot/cmdline.txt'
apply_file 644 '/boot/config.txt'

##
# This script is executed at the end of each multiuser runlevel.
#
apply_file 755 '/etc/rc.local'

##
# Install SSH server
#
on_chroot << EOF
apt-get install -y ssh
EOF

rm -fv "$ROOTFS_DIR/etc/ssh/ssh_host_key"
rm -fv "$ROOTFS_DIR/etc/ssh/ssh_host_key.pub"

rm -fv "$ROOTFS_DIR/etc/ssh/ssh_host_dsa_key"
rm -fv "$ROOTFS_DIR/etc/ssh/ssh_host_dsa_key.pub"

rm -fv "$ROOTFS_DIR/etc/ssh/ssh_host_ecdsa_key"
rm -fv "$ROOTFS_DIR/etc/ssh/ssh_host_ecdsa_key.pub"

rm -fv "$ROOTFS_DIR/etc/ssh/ssh_host_ed25519_key"
rm -fv "$ROOTFS_DIR/etc/ssh/ssh_host_ed25519_key.pub"

rm -fv "$ROOTFS_DIR/etc/ssh/ssh_host_rsa_key"
rm -fv "$ROOTFS_DIR/etc/ssh/ssh_host_rsa_key.pub"

##
# Assign device names by part-UUID
#
apply_file 644 '/lib/udev/rules.d/61-partuuid.rules'

##
# Configure network.
#
apply_file 644 '/etc/hostname'

apply_patch '02-hosts.diff'

apply_file 644 '/etc/network/interfaces'
apply_file 644 '/etc/network/interfaces.d/wlan0'
apply_file 644 '/etc/network/interfaces.d/eth0'

##
# Configure Wi-Fi.
#
on_chroot << EOF
apt-get install -y wpasupplicant firmware-brcm80211
EOF

apply_file 600 '/etc/wpa_supplicant/wpa_supplicant.conf'

##
# Add user.
#
on_chroot << EOF
apt-get install -y sudo
EOF

apply_patch '03-passwordless-sudo.diff'
apply_patch '04-bashrc.diff'
apply_patch '05-useradd.diff'

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
# Configure environment.
#
apply_patch '07-path.diff'

##
# Make user-friendly environment.
#
on_chroot << EOF
apt-get install -y \
bash-completion    \
colordiff          \
curl               \
less               \
vim

update-alternatives --set editor /usr/bin/vim.basic
EOF

##
# Save fake hardware clock time for more realistic time after startup.
#
on_chroot << EOF
apt-get install -y fake-hwclock ntp
systemctl disable hwclock.sh
fake-hwclock save
EOF

##
# Install Tor.
#
on_chroot << EOF
apt-get install -y tor
EOF

apply_file 644 '/etc/tor/torrc'

##
# Configure firewall.
#
on_chroot << EOF
apt-get install -y iptables-persistent
EOF

apply_file 644 '/etc/iptables/rules.v4'
apply_file 644 '/etc/iptables/rules.v6'

##
# Remove unnecessary packages.
#
on_chroot << EOF
apt-get purge -y rpcbind exim4 exim4-base exim4-config exim4-daemon-light
apt-get autoremove -y --purge
EOF

##
# Cleanup after Quilt patching.
#
rm -rf "$ROOTFS_DIR/.pc/"

##
# Allow services to start.
#
rm -f "$ROOTFS_DIR/usr/sbin/policy-rc.d"

##
# Clean Apt cache.
#
rm -rf "$ROOTFS_DIR/var/cache/apt/archives/*"
