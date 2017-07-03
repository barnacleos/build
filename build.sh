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

if [ "$(id -u)" != '0' ]; then
  echo 'Please run as root' 1>&2
  exit 1
fi

dependencies_check "$BASE_DIR/depends"

mkdir -p "$DEPLOY_DIR"
mkdir -p "$MOUNT_DIR"

local SUB_STAGE_DIR="$BASE_DIR/stage0/00-substage"

pushd "$SUB_STAGE_DIR" > /dev/null

"$SUB_STAGE_DIR/00-run.sh"

popd > /dev/null
