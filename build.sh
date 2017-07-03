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
export BOOTFS_DIR="$ROOTFS_DIR/boot"
export MOUNT_DIR="$BASE_DIR/mnt"
export WORK_DIR="$BASE_DIR/work"

export IMG_DATE="$(date +%Y-%m-%d)"

export IMG_FILE="$DEPLOY_DIR/$IMG_DATE-${IMG_NAME}.img"
export ZIP_FILE="$DEPLOY_DIR/$IMG_DATE-${IMG_NAME}.zip"

export QUILT_NO_DIFF_INDEX=1
export QUILT_NO_DIFF_TIMESTAMPS=1
export QUILT_REFRESH_ARGS='-p ab'

source "$FUNCTIONS_DIR/logging.sh"
source "$FUNCTIONS_DIR/dependencies_check.sh"

source "$SCRIPT_DIR/common.sh"

main() {
  if [ "$(id -u)" != '0' ]; then
    echo 'Please run as root' 1>&2
    exit 1
  fi

  dependencies_check "$BASE_DIR/depends"

  mkdir -p "$WORK_DIR"
  mkdir -p "$DEPLOY_DIR"
  mkdir -p "$MOUNT_DIR"

  tput setaf 2 # Green color
  echo "$IMG_DATE $(date +"%T")"
  echo
  echo "Work dir: $WORK_DIR"
  echo
  echo "Root FS dir: $ROOTFS_DIR"
  echo "Boot FS dir: $BOOTFS_DIR"
  echo
  echo "Image file: $IMG_FILE"
  echo "ZIP file:   $ZIP_FILE"
  echo
  tput sgr0 # No color

  local SUB_STAGE_DIR="$BASE_DIR/stage0/00-substage"

  pushd "$SUB_STAGE_DIR" > /dev/null

  for i in {00..99}; do
    task_patches "$SUB_STAGE_DIR/$i-patches"
    task_run     "$SUB_STAGE_DIR/$i-run.sh"
  done

  popd > /dev/null
}

task_patches() {
  if [ -d "$1" ]; then
    local SUB_STAGE_DIR=$(dirname "$1")
    local SUB_STAGE_NAME=$(basename "$SUB_STAGE_DIR")

    log_begin "$1"
    pushd "$WORK_DIR" > /dev/null

    rm -rf .pc
    rm -rf *-pc

    export QUILT_PATCHES="$1"

    SUB_STAGE_QUILT_PATCH_DIR="$SUB_STAGE_NAME-pc"
    mkdir -p "$SUB_STAGE_QUILT_PATCH_DIR"
    ln -snf "$SUB_STAGE_QUILT_PATCH_DIR" .pc

    if [ -e "$1/EDIT" ]; then
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

main
