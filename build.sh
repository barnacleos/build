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

source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/patching.sh"

main() {
  if [ "$(id -u)" != '0' ]; then
    echo 'Please run as root' 1>&2
    exit 1
  fi

  dependencies_check "$BASE_DIR/depends"

  mkdir -p "$DEPLOY_DIR"
  mkdir -p "$MOUNT_DIR"

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
    log_begin "$1"
    pushd "$ROOTFS_DIR" > /dev/null

    export QUILT_PATCHES="$1"

    rm -rf   .pc
    mkdir -p .pc

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

    rm -rf .pc

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
