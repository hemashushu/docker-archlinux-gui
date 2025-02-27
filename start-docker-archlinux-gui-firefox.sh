#!/usr/bin/env bash

# Application data folders
# ------------------------
GUI_APP_DATA_FOLDER="${HOME}/docker-gui-app-data"
mkdir -p ${GUI_APP_DATA_FOLDER}/.mozilla

docker run \
  --rm \
  --mount type=bind,source="${HOME}/Downloads",target="/root/Downloads" \
  --mount type=bind,source="${GUI_APP_DATA_FOLDER}/.mozilla",target="/root/.mozilla" \
  --mount type=bind,source="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}",target="/tmp/${WAYLAND_DISPLAY}" \
  -e XDG_RUNTIME_DIR=/tmp \
  -e WAYLAND_DISPLAY=${WAYLAND_DISPLAY} \
  --mount type=bind,source="${XDG_RUNTIME_DIR}/pipewire-0",target="/tmp/pipewire-0" \
  --device /dev/dri \
  --device /dev/snd \
  -e GTK_IM_MODULE=fcitx \
  -e XMODIFIERS=@im=fcitx \
  -e QT_IM_MODULE=fcitx \
  archlinux-gui-firefox:1.0.0
