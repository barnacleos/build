#!/bin/bash -e

install -m 644 files/cmdline.txt "$BOOTFS_DIR"
install -m 644 files/config.txt  "$BOOTFS_DIR"
