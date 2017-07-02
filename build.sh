#!/bin/bash -e

export BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR="$BASE_DIR/scripts"
export FUNCTIONS_DIR="$BASE_DIR/functions"
export DEPLOY_DIR="$BASE_DIR/deploy"

export IMG_DATE
export WORK_DIR

export IMG_NAME
export HOSTNAME
export USERNAME
export PASSWORD

export STAGE
export STAGE_DIR
export STAGE_WORK_DIR
export ROOTFS_DIR

export IMG_FILE
export ZIP_FILE

export QUILT_PATCHES
export QUILT_NO_DIFF_INDEX=1
export QUILT_NO_DIFF_TIMESTAMPS=1
export QUILT_REFRESH_ARGS='-p ab'

source "$FUNCTIONS_DIR/logging.sh"
source "$SCRIPT_DIR/common.sh"
source "$FUNCTIONS_DIR/dependencies_check.sh"

main() {
  dependencies_check "$BASE_DIR/depends"

  source "$BASE_DIR/config"

  if [ "$(id -u)" != '0' ]; then
    echo 'Please run as root' 1>&2
    exit 1
  fi

  if [ -z "$IMG_NAME" ]; then
    echo 'IMG_NAME not set' 1>&2
    exit 1
  fi

  if [ -z "$HOSTNAME" ]; then
    echo 'HOSTNAME not set' 1>&2
    exit 1
  fi

  if [ -z "$USERNAME" ]; then
    echo 'USERNAME not set' 1>&2
    exit 1
  fi

  if [ -z "$PASSWORD" ]; then
    echo 'PASSWORD not set' 1>&2
    exit 1
  fi

  IMG_DATE="$(date +%Y-%m-%d)"
  WORK_DIR="$BASE_DIR/work/$IMG_DATE-$IMG_NAME"

  STAGE='stage0'
  STAGE_DIR="$BASE_DIR/$STAGE"
  STAGE_WORK_DIR="$WORK_DIR/$STAGE"
  ROOTFS_DIR="$STAGE_WORK_DIR/rootfs"

  IMG_FILE="$STAGE_WORK_DIR/$IMG_DATE-${IMG_NAME}.img"
  ZIP_FILE="$DEPLOY_DIR/image_$IMG_DATE-${IMG_NAME}.zip"

  mkdir -p "$WORK_DIR"
  mkdir -p "$DEPLOY_DIR"
  mkdir -p "$ROOTFS_DIR"
  mkdir -p "$ROOTFS_DIR/boot"

  pushd "$STAGE_DIR" > /dev/null

  unmount "$STAGE_WORK_DIR"

  for SUB_STAGE_DIR in $STAGE_DIR/*; do
    if [ -d "$SUB_STAGE_DIR" ]; then
      run_sub_stage
    fi
  done

  unmount "$STAGE_WORK_DIR"

  popd > /dev/null
}

run_sub_stage() {
	log_begin "$SUB_STAGE_DIR"
	pushd "$SUB_STAGE_DIR" > /dev/null

	for i in {00..99}; do
		task_debconf     "$SUB_STAGE_DIR/$i-debconf"
		task_packages_nr "$SUB_STAGE_DIR/$i-packages-nr"
		task_packages    "$SUB_STAGE_DIR/$i-packages"

		if [ -d ${i}-patches ]; then
			log_begin "$SUB_STAGE_DIR/$i-patches"
			pushd ${STAGE_WORK_DIR} > /dev/null
			rm -rf .pc
			rm -rf *-pc
			QUILT_PATCHES=${SUB_STAGE_DIR}/${i}-patches
			SUB_STAGE_QUILT_PATCH_DIR="$(basename $SUB_STAGE_DIR)-pc"
			mkdir -p $SUB_STAGE_QUILT_PATCH_DIR
			ln -snf $SUB_STAGE_QUILT_PATCH_DIR .pc
			if [ -e ${SUB_STAGE_DIR}/${i}-patches/EDIT ]; then
				tput setaf 3 # Yellow color
				echo 'Dropping into bash to edit patches...'
				echo 'Tutorial: https://raphaelhertzog.com/2012/08/08/how-to-use-quilt-to-manage-patches-in-debian-packages/'
				echo 'Example:'
				echo '  quilt new XX-name-of-the-patch.diff'
				echo '  quilt edit rootfs/path/to/file'
				echo '  quilt diff'
				echo '  quilt refresh'
				tput sgr0 # No color

				bash
			fi
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
			popd > /dev/null
			log_end "$SUB_STAGE_DIR/$i-patches"
		fi

		task_run        "$SUB_STAGE_DIR/$i-run.sh"
		task_run_chroot "$SUB_STAGE_DIR/$i-run-chroot.sh"
	done

	popd > /dev/null
	log_end "$SUB_STAGE_DIR"
}

task_debconf() {
  if [ -f "$1" ]; then
    log_begin "$1"

    on_chroot << EOF
debconf-set-selections <<SELEOF
`cat "$1"`
SELEOF
EOF

    log_end "$1"
  fi
}

task_packages_nr() {
  if [ -f "$1" ]; then
    log_begin "$1"

    PACKAGES="$(sed -f "$SCRIPT_DIR/remove-comments.sed" < "$1")"

    if [ -n "$PACKAGES" ]; then
      on_chroot <<EOF
apt-get install --no-install-recommends -y $PACKAGES
EOF
    fi

    log_end "$1"
  fi
}

task_packages() {
  if [ -f "$1" ]; then
    log_begin "$1"

    PACKAGES="$(sed -f "$SCRIPT_DIR/remove-comments.sed" < "$1")"

    if [ -n "$PACKAGES" ]; then
      on_chroot <<EOF
apt-get install -y $PACKAGES
EOF
    fi

    log_end "$1"
  fi
}

task_run() {
  if [ -x "$1" ]; then
    log_begin "$1"

    "$1"

    log_end "$1"
  fi
}

task_run_chroot() {
  if [ -f "$1" ]; then
    log_begin "$1"

    on_chroot < "$1"

    log_end "$1"
  fi
}

main
