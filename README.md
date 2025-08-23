# How to Run GUI Applications Directly in Containers

This tutorial explains how to run GUI applications inside containers (such as Docker or Podman) without installing extra software on your host system.

**Why Run GUI Applications Inside Containers?**

- Try a GUI application without installing it on your system, ensuring no files or data remain after use (keeping your system clean).
- The GUI application is not available in your OS's package repository, or the official package is incompatible with your current distribution.
- No prebuilt packages for your OS, and source compilation is required, but you want to avoid the hassle of building and installing it.
- The source of the GUI application is untrusted, or its safety is uncertain.

> Note: Containers are not designed to be security sandboxes. Do not run untrusted applications in critical environments using this method.

**Table of Contents**

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=4 orderedList=false} -->

<!-- code_chunk_output -->

- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [How Does It Work?](#how-does-it-work)
- [Custom Launch Script](#custom-launch-script)
  - [Basic Parameters](#basic-parameters)
- [Graphical Related Parameters](#graphical-related-parameters)
  - [Sound Related Parameters](#sound-related-parameters)
  - [Mapping Host's Directories](#mapping-hosts-directories)
  - [Mapping X11](#mapping-x11)
  - [Input Method (IME) Related Environment Variables](#input-method-ime-related-environment-variables)
  - [The Complete Launch Script](#the-complete-launch-script)
- [Building Images](#building-images)
- [Further Reading](#further-reading)
- [Repositories](#repositories)
- [Images](#images)

<!-- /code_chunk_output -->

## Requirements

- A system runs a display server using the [Wayland protocol](https://en.wikipedia.org/wiki/Wayland_(protocol)). If you use a recent version of GNOME or KDE, this is likely already the case. If your desktop environment uses the Xorg server, skip to the "Custom Launch Script" section.

- System should runs the [PipeWire](https://en.wikipedia.org/wiki/PipeWire) multimedia framework. Most modern Linux distributions include this by default. If you are unsure, you can proceed—most GUI applications will still start even if PipeWire is missing.

- Docker or Podman is installed. Podman is recommended for desktop systems because it is simpler and more secure: it does not require a daemon, avoids complex configuration, and can run containers as the current (unprivileged) user, mapping the container's root user to your user account.

> Since Podman can also use the `docker` command, all code examples below use `docker` for consistency.

## Quick Start

Before diving into the details, you can quickly try running a GUI application in a container:

1. Create a script named `start-docker-archlinux-gui-firefox.sh`:

```sh
docker run \
  --rm \
  --mount type=bind,source="${HOME}/Downloads",target="/root/Downloads" \
  --mount type=bind,source="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}",target="/tmp/${WAYLAND_DISPLAY}" \
  -e XDG_RUNTIME_DIR=/tmp \
  -e WAYLAND_DISPLAY=${WAYLAND_DISPLAY} \
  --mount type=bind,source="${XDG_RUNTIME_DIR}/pipewire-0",target="/tmp/pipewire-0" \
  --device /dev/dri \
  --device /dev/snd \
  archlinux-gui-firefox:1.0.0
```

2. Run the script:

```sh
sh start-docker-archlinux-gui-firefox.sh
```

This script will pull the `archlinux-gui-firefox` image from Docker Hub and start a container instance.

> If your connection to Docker Hub is slow, see the "Build Images" section to build the image locally, then return here.

3. You will see a fresh Firefox running in the container. Try visiting video websites—audio and video playback should work. You can also save web pages to the "Downloads" folder, which is shared with your host.

4. When you close Firefox, the container will exit and delete all data generated during its runtime (except for files saved in the "Downloads" folder).

5. Try to change `archlinux-gui-firefox:1.0.0` in the script to `archlinux-gui-mpv:1.0.0`. After running it, you will see the _Celluloid_ media player (based on mpv). Try playing some videos to confirm everything works.

## How Does It Work?

In short:

Graphic and audio are passthrough from the container to the host by the host's Wayland and PipeWire socket files (only two files).

Details:

To run GUI applications in a container, you need to map the host's Wayland and PipeWire socket files into the container and set the appropriate environment variables in the container to tell applications where to find these sockets.

- The Wayland socket file is in your runtime directory (pointed to by `XDG_RUNTIME_DIR`), with the filename `${WAYLAND_DISPLAY}`. The full path is typically `/run/user/1000/wayland-0`, where `1000` is your user ID. This socket allows applications to communicate with the Wayland compositor (display server).

- The PipeWire socket file is also in your runtime directory, named `pipewire-0`. Applications connect to this socket for audio and video playback or recording.

- You may also see a `bus` socket (for [D-Bus](https://en.wikipedia.org/wiki/D-Bus)), but configuring this securely is complex, so it is omitted here.

Mapping these socket files into the container by the Docker `--mount` option.

## Custom Launch Script

The launch script constructs the command-line parameters for Podman (or Docker) to map the Wayland and PipeWire sockets into the container and set the necessary environment variables. Below is an explanation of each parameter, along with some optional additions. Feel free to adapt the script to your needs.

### Basic Parameters

```sh
docker run \
  --rm \
  archlinux-gui-firefox:1.0.0
```

- `--rm`: Automatically removes the container when it exits, keeping your system clean.
- `archlinux-gui-firefox:1.0.0`: The Docker image to use. Docker will use a local image if available, or pull it from Docker Hub (or another registry) if not.

## Graphical Related Parameters

`--mount type=bind,source="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}",target="/tmp/${WAYLAND_DISPLAY}"`

Maps the host's Wayland socket file (e.g., `/run/user/1000/wayland-0`) to `/tmp/wayland-0` in the container.

`-e WAYLAND_DISPLAY=${WAYLAND_DISPLAY}`

Sets the `WAYLAND_DISPLAY` environment variable in the container to specify the display number.

`-e XDG_RUNTIME_DIR=/tmp`

Sets `XDG_RUNTIME_DIR` in the container to inform applications of the runtime directory location.

`--device /dev/dri`

Maps the host's `/dev/dri` directory into the container, allowing applications to use the host GPU for hardware acceleration. This is important for:

- 3D gaming
- Video playback and encoding
- Graphics-intensive applications
- Machine learning applications using GPUs

### Sound Related Parameters

`--mount type=bind,source="${XDG_RUNTIME_DIR}/pipewire-0",target="/tmp/pipewire-0"`

Maps the host's PipeWire socket file (e.g., `/run/user/1000/pipewire-0`) to `/tmp/pipewire-0` in the container. PipeWire does not use an environment variable like `WAYLAND_DISPLAY` for sound.

`--device /dev/snd`

Grants the container direct access to the host's sound devices. Most applications use frameworks like PipeWire, PulseAudio, or JACK, so this parameter is often optional.

> PipeWire is used for both audio and video streaming/recording.

### Mapping Host's Directories

By default, the container's filesystem is isolated from the host. To share files, you can map host directories into the container. For example, to share your "Downloads", "Music", and "Videos" folders:

```sh
docker run \
  ...
  --mount type=bind,source="${HOME}/Downloads",target="/root/Downloads" \
  --mount type=bind,source="${HOME}/Music",target="/root/Music" \
  --mount type=bind,source="${HOME}/Videos",target="/root/Videos" \
  ...
```

To persist application settings (e.g., Firefox's `~/.mozilla`), map the relevant directory:

`--mount type=bind,source="${HOME}/docker-gui-app-data/.mozilla",target="/root/.mozilla"`

This allows Firefox in the container to retain its settings between runs.

### Mapping X11

If your desktop uses Xorg, or if the application only supports X11, you need to map X11 into the container. (If using Wayland, but the app only supports X11, you also need `xwayland` on the host.)

X11 uses multiple sockets in `/tmp/.X11-unix` (e.g., `/tmp/.X11-unix/X0` for display `:0`). Map the entire directory, not just a single socket. X11 also uses an `~/.Xauthority` file for authentication, which must be copied and modified for the container. Example script:

```sh
export X11SOCKET_FOLDER=/tmp/.X11-unix

# Create XAuthority file for container
export X11AUTHORITY_FILE=/tmp/.docker.xauth
touch ${X11AUTHORITY_FILE}

DISPLAY_CANONICAL=$(echo $DISPLAY | sed s/localhost//)
if [ $DISPLAY_CANONICAL != $DISPLAY ]
then
    export DISPLAY=$DISPLAY_CANONICAL
fi

# Allow any host to connect to this X server
xauth nlist ${DISPLAY} | sed -e 's/^..../ffff/' | uniq | xauth -f ${X11AUTHORITY_FILE} nmerge -

docker run \
  ...
  --mount type=bind,source="${X11SOCKET_FOLDER}",target="${X11SOCKET_FOLDER}" \
  --mount type=bind,source="${X11AUTHORITY_FILE}",target="${X11AUTHORITY_FILE}" \
  -e XAUTHORITY=${X11AUTHORITY_FILE} \
  -e DISPLAY=${DISPLAY} \
  --network host \
  --cap-add=NET_RAW \
  ...
```

For more details, see [Short setups to provide X display to container](https://github.com/mviereck/x11docker/wiki/Short-setups-to-provide-X-display-to-container) and [X authentication with cookies and xhost](https://github.com/mviereck/x11docker/wiki/X-authentication-with-cookies-and-xhost-%28%22No-protocol-specified%22-error%29).

If you map both Wayland and X11, you can set these environment variables to make applications prefer Wayland:

```sh
docker run \
  ...
  -e XDG_SESSION_TYPE=wayland \
  -e GDK_BACKEND=wayland \
  -e QT_QPA_PLATFORM=wayland \
  -e SDL_VIDEODRIVER=wayland \
  ...
```

### Input Method (IME) Related Environment Variables

To use input methods (e.g., fcitx or ibus) in GUI applications inside the container, set these variables:

```sh
docker run \
  ...
  -e GTK_IM_MODULE=fcitx \
  -e XMODIFIERS=@im=fcitx \
  -e QT_IM_MODULE=fcitx \
  ...
```

### The Complete Launch Script

A full launch script with all parameters is available here: [start-docker-archlinux-gui-firefox-full.sh](https://github.com/hemashushu/docker-archlinux-gui/raw/refs/heads/main/start-docker-archlinux-gui-firefox-full.sh)

> Note: Never run scripts from the internet without reviewing them first. If a script is too complex to understand, only run it if it comes from a trusted source. You can also use AI tools to help review scripts.

## Building Images

Once you know how to launch a container with GUI support, you can "package" the target application as a Docker image.

The `archlinux-gui-firefox` image is built on top of the `archlinux-gui` base image, which provides essential packages for GUI applications (audio/video plugins, fonts, etc.). Application-specific images (like Firefox or mpv) built on this base image are smaller and more efficient.

You can also add intermediate layers (e.g., GTK or Qt) so that multiple applications can share them, further reducing image size.

Example `Dockerfile` for `archlinux-gui`:

```Dockerfile
FROM archlinux:latest

# (Optional) Add your nearest mirror here
RUN echo 'Server = https://mirrors.aliyun.com/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist.new && \
    echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist.new && \
    cat /etc/pacman.d/mirrorlist >> /etc/pacman.d/mirrorlist.new && \
    mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak && \
    mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist

# Update repository and system
RUN pacman -Syu --noconfirm

# Install audio userspace framework
RUN pacman -S pipewire pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack --noconfirm

# Install decoding plugins
RUN pacman -S gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly --noconfirm

# Install extra fonts, e.g., CJK fonts
RUN pacman -S ttf-dejavu noto-fonts-cjk --noconfirm

# (Optional) Change the permission of XDG_RUNTIME_DIR
# RUN chmod 700 /tmp

# Set working directory
WORKDIR /root

# Default command
CMD /usr/bin/bash
```

You can also use other base images, such as [Ubuntu](https://hub.docker.com/_/ubuntu), [Fedora](https://hub.docker.com/_/fedora), or [Alpine](https://hub.docker.com/_/alpine), depending on your needs.

Example `Dockerfile` for `archlinux-gui-firefox`:

```Dockerfile
FROM archlinux-gui:1.0.0

# Update repository and system
RUN pacman -Syu --noconfirm

# Install Firefox
RUN pacman -S firefox --noconfirm

# Default command
CMD dbus-run-session firefox
```

The default command uses `dbus-run-session firefox` instead of just `firefox` because most GUI applications rely on D-Bus and need to be launched this way.

You can find these files in the [docker-archlinux-gui](https://github.com/hemashushu/docker-archlinux-gui) repository. To build the images locally, use:

`docker build -t <IMAGE_NAME>:<IMAGE_TAG> -f <DOCKERFILE_NAME> .`

For example:

`docker build -t archlinux-gui:1.0.0 -f Dockerfile .`
`docker build -t archlinux-gui-firefox:1.0.0 -f Dockerfile-firefox .`

## Further Reading

This tutorial covers the basics of running GUI applications in containers, creating launch scripts, and building images. For more advanced topics, such as setting up a development environment or running tools like VSCode and JetBrains IDEs in containers, see [docker-archlinux-gui-devel](https://github.com/hemashushu/docker-archlinux-gui-devel).

## Repositories

Related repositories for further exploration:

- [docker-archlinux-gui](https://github.com/hemashushu/docker-archlinux-gui)
- [docker-archlinux-gui-devel](https://github.com/hemashushu/docker-archlinux-gui-devel)
- [docker-ubuntu-gui-devel](https://github.com/hemashushu/docker-ubuntu-gui-devel)

## Images

While building images locally is recommended (since they are large), you can also pull prebuilt images from Docker Hub for convenience:

- [archlinux-gui](https://hub.docker.com/r/hemashushu/archlinux-gui)
- [archlinux-gui-firefox](https://hub.docker.com/r/hemashushu/archlinux-gui-firefox)
- [archlinux-gui-mpv](https://hub.docker.com/r/hemashushu/archlinux-gui-mpv)
- [archlinux-gui-devel](https://hub.docker.com/r/hemashushu/archlinux-gui-devel)
- [archlinux-gui-vscode-oss](https://hub.docker.com/r/hemashushu/archlinux-gui-vscode-oss)
