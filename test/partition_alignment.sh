#!/bin/false

TABLE="$(fdisk -l "$IMG_FILE" | grep "^$IMG_FILE")"

test 2 -eq $(echo "$TABLE" | wc -l)

TABLE="$(echo "$TABLE" | sed "s|^$IMG_FILE. ||")"

echo "$TABLE" | while read -r line; do test 0 -eq $(($(echo $line | cut -d ' ' -f 1) % 4096)); done
