#!/bin/sh
set -eu

ROOTFS=$1

chroot "$ROOTFS" apt-get clean
rm -rf "$ROOTFS/var/lib/apt/lists/"*
