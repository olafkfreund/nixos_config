#! /usr/bin/env nix-shell
#! nix-shell -p nixos-generators
#! nix-shell -i bash
set -xe

CONFIGURATION_FILE=$1
IMAGE_NAME=$2

IMAGE_METADATA=$(nixos-generate -f lxc-metadata)
IMAGE_FILE=$(nixos-generate -c $CONFIGURATION_FILE -f lxc)

lxc image delete $IMAGE_NAME || echo true
lxc image import --alias $IMAGE_NAME ${IMAGE_METADATA} ${IMAGE_FILE}
