#!/bin/false

STARTS=$(partx --show --noheadings --output START - "$IMG_FILE")

echo '--- starts ---'
echo "$STARTS" | while read -r line; do echo $line; done

test 2 -eq $(echo "$STARTS" | wc -l)

REMS=$(echo "$STARTS" | while read -r line; do echo $(($line % 4096)); done)

echo '--- rems ---'
echo "$REMS" | while read -r line; do echo $line; done

echo "$REMS" | while read -r line; do test 0 -eq $line; done
