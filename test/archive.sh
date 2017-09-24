#!/bin/false

test -f "$IMG_FILE"
test -f "$ZIP_FILE"

TMP="$(mktemp -d)"

unzip "$ZIP_FILE" -d "$TMP"

test 1 -eq $(ls "$TMP" | wc -l)

EXTRACTED_FILE="$TMP/$IMG_NAME-${IMG_DATE}.img"

test -f "$EXTRACTED_FILE"

cmp "$IMG_FILE" "$EXTRACTED_FILE"
