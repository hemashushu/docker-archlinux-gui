#!/usr/bin/env bash

docker run \
  -it \
  --rm \
  --mount type=bind,source="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}",target="/tmp/${WAYLAND_DISPLAY}" \
  -e XDG_RUNTIME_DIR=/tmp \
  -e WAYLAND_DISPLAY=${WAYLAND_DISPLAY} \
  --mount type=bind,source="${XDG_RUNTIME_DIR}/pipewire-0",target="/tmp/pipewire-0" \
  --device /dev/dri \
  --device /dev/snd \
  archlinux-gui:1.2.0
