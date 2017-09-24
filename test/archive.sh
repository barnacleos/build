#!/bin/bash -e

export BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export IMG_NAME='BarnacleOS'

export DEPLOY_DIR="$BASE_DIR/deploy"

export IMG_DATE="$(date +%Y-%m-%d)"

export IMG_FILE="$DEPLOY_DIR/$IMG_NAME-${IMG_DATE}.img"
export ZIP_FILE="$DEPLOY_DIR/$IMG_NAME-${IMG_DATE}.zip"

test -f "$IMG_FILE"
test -f "$ZIP_FILE"

TMP="$(mktemp -d)"

unzip "$ZIP_FILE" -d "$TMP"

test 1 -eq $(ls "$TMP" | wc -l)

EXTRACTED_FILE="$TMP/$IMG_NAME-${IMG_DATE}.img"

test -f "$EXTRACTED_FILE"

cmp "$IMG_FILE" "$EXTRACTED_FILE"
