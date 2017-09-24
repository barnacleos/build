#!/bin/false

TABLE="$(/sbin/fdisk -o Device,Start -l "$IMG_FILE" | grep "^$IMG_FILE")"

test 2 -eq $(echo "$TABLE" | wc -l)

STARTS="$(echo "$TABLE" | sed "s|^$IMG_FILE. ||")"

echo "$STARTS" | while read -r offset; do test 0 -eq $((offset % 4096)); done
