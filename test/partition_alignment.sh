#!/bin/false

TABLE="$(fdisk -l "$IMG_FILE" | grep "^$IMG_FILE")"

test 2 -eq $(echo "$TABLE" | wc -l)

TABLE="$(echo "$TABLE" | sed "s|^$IMG_FILE. ||")"

echo '--- table ---'
echo "$TABLE" | while read -r line; do echo $line; done

STARTS=$(echo "$TABLE" | while read -r line; do echo "$(echo $line | cut -d ' ' -f 1)"; done)

echo '--- starts ---'
echo "$STARTS" | while read -r line; do echo $line; done

REMS=$(echo "$STARTS" | while read -r line; do echo $(($line % 4096)); done)

echo '--- rems ---'
echo "$REMS" | while read -r line; do echo $line; done

echo "$REMS" | while read -r line; do test 0 -eq $line; done
