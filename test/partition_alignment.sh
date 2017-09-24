#!/bin/bash -e

export BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export IMG_NAME='BarnacleOS'

export DEPLOY_DIR="$BASE_DIR/deploy"

export IMG_DATE="$(date +%Y-%m-%d)"

export IMG_FILE="$DEPLOY_DIR/$IMG_NAME-${IMG_DATE}.img"

TABLE="$(/sbin/fdisk -o Device,Start -l "$IMG_FILE" | grep "^$IMG_FILE")"

test 2 -eq $(echo "$TABLE" | wc -l)

STARTS="$(echo "$TABLE" | sed "s|^$IMG_FILE. ||")"

echo "$STARTS" | while read -r offset; do test 0 -eq $((offset % 4096)); done
