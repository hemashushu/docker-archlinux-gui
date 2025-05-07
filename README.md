# How to Run GUI Applications Directly in Containers

This tutorial introduces a method for running GUI applications directly in containers (such as Docker and Podman) without installing any additional software.

**Why Run GUI Applications Inside Containers?**

- The source of the GUI application is untrusted, or its safety is uncertain.
- You want to try a GUI application without installing it on your existing system and ensure no files or data remain after you finish using it (i.e., keep your system clean).
- The GUI application is not available in your OS's package repository, and the official software package does not have a version compatible with your current distribution. For example, the application only provides an Ubuntu package, but your distribution is Arch Linux or NixOS.

_Table of content_

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=4 orderedList=false} -->

<!-- code_chunk_output -->

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [How does it work?](#how-does-it-work)
- [Custom launch script](#custom-launch-script)
  - [Basic parameters](#basic-parameters)
- [Graphical related parameters](#graphical-related-parameters)
  - [Sound related parameters](#sound-related-parameters)
  - [Map host's directories](#map-hosts-directories)
  - [Map X11](#map-x11)
  - [Input method (IME) related environment variables](#input-method-ime-related-environment-variables)
  - [The complete launch script](#the-complete-launch-script)
- [Build images](#build-images)
- [Learn more](#learn-more)
- [Images](#images)
- [Repositories](#repositories)

<!-- /code_chunk_output -->

## Requirements

- Your platform runs a display server using the [Wayland protocol](https://en.wikipedia.org/wiki/Wayland_(protocol)). If you are using a newer version of GNOME or KDE desktop environments, this requirement is likely already met. If your desktop environment is running on the Xorg server, skip to the "Custom Launch Script" section.

- Your platform runs the [PipeWire](https://en.wikipedia.org/wiki/PipeWire) multimedia framework. For newer versions of Linux distros, this is most likely already the case. If you are unsure, you can continue, as the absence of PipeWire does not affect the startup of most GUI applications.

- Your platform must have the Docker or Podman container manager installed. I recommend using Podman on desktop systems. Compared to Docker, Podman is simpler and more secure. For example, it does not require running as a daemon, avoids complex configurations, and can directly use the currently logged-in user (i.e. unprivileged user) to start the container (the root user in the container is mapped to the current user instead of the host's root user), among other benefits.

> Since Podman can also use the `docker` command for access, the following code examples uniformly use the `docker` command.

## Quick start

Before introducing the specific methods and principles, you can quickly experience starting a GUI application in a container on your machine.

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

This script will pull the image "archlinux-gui-firefox" from "hub.docker.com" and start a container instance.

> If your network access to "hub.docker.com" is slow, you can skip to the "Build Image" section, generate the image locally, and then return here.

3. Now you should be able to see a "flash new" Firefox running in the container. Try visiting some video websites, playing music and videos should work fine. You can also try saving web pages to the "Downloads" folder, which is shared with the host's "Downloads" folder.

4. Close Firefox, the container will exit and delete all data generated during its runtime (except for the data saved in the "Downloads" folder).

5. You can try changing "archlinux-gui-firefox:1.0.0" in the above script to "archlinux-gui-mpv:1.0.0". After running it, you should see a media player called "Celluloid" (a software based on mpv). You can try playing some videos with it. If everything goes correctly, it should work fine.

## How does it work?

When you start a container instance, all you need to do is map the host's Wayland socket and PipeWire socket files into the container, and then set the appropriate environment variables within the container to enable running GUI applications.

Here are the details:

The Wayland socket file is located in the user's runtime directory (i.e., the directory pointed to by the environment variable `XDG_RUNTIME_DIR`), and the filename is `${WAYLAND_DISPLAY}`, the full path is similar to `/run/user/1000/wayland-0`, where "1000" is the user ID. This socket serves as a communication channel between Wayland clients (applications) and the Wayland compositor (the display server). Essentially, applications that want to display their graphical output on the screen connect to this socket to communicate with the Wayland compositor.

Similar to the Wayland socket, the PipeWire socket file is also located in the user's runtime directory, and the file name is `pipewire-0`. When an application wants to play or record audio or video, it connects to this socket to interact with the PipeWire server.

If you are curious to examine the user's runtime directory, you will also find a socket file called `bus`, which is the [D-Bus](https://en.wikipedia.org/wiki/D-Bus) socket. Applications in the container can send messages to the host through it, but because security configuration is more complex, it is omitted here.

## Custom launch script

The main purpose of the launch script is to construct the command-line parameters for running the Podman (or Docker) program to map the Wayland socket and PipeWire socket into the container, and to set the corresponding environment variables within the container. Below is a description of each line of parameters, and some additional parameters are added. Feel free to create your own launch script as needed.

### Basic parameters

```sh
docker run \
  --rm \
  archlinux-gui-firefox:1.0.0
```

These are the basic parameters for starting a container instance:

- `--rm`: This option tells Docker to automatically remove the container when it exits, which helps keep your system clean.

- `archlinux-gui-firefox:1.0.0`: This is the name of the Docker image used to create the container. Docker will first check if the image exists locally. If it doesn't, it will attempt to download it from Docker Hub (or another configured registry).

## Graphical related parameters

`--mount type=bind,source="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}",target="/tmp/${WAYLAND_DISPLAY}"`

Map the host's Wayland socket file (e.g. `/run/user/1000/wayland-0`) to `/tmp/wayland-0` in the container using the `mount` parameter.

`-e WAYLAND_DISPLAY=${WAYLAND_DISPLAY}`

Set the environment variable `WAYLAND_DISPLAY` in the container using the `e` parameter to tell the application the current display number.

`-e XDG_RUNTIME_DIR=/tmp`

Set the `XDG_RUNTIME_DIR` in the container to inform the application of the user's runtime directory location.

`--device /dev/dri`

This option maps the host machine's `/dev/dri` directory into the Docker container. This allows applications running inside the container to use the host's GPU for hardware acceleration.

This is crucial for applications that require high-performance graphics, such as:

- 3D gaming
- Video playback and encoding
- Graphics-intensive applications
- Machine learning applications that use GPUs.

### Sound related parameters

`--mount type=bind,source="${XDG_RUNTIME_DIR}/pipewire-0",target="/tmp/pipewire-0"`

Map the host's PipeWire socket file (e.g. `/run/user/1000/pipewire-0`) to `/tmp/pipewire-0` in the container. Note that PipeWire does not have an environment variable similar to the `WAYLAND_DISPLAY` to specify the current "sound number".

`--device /dev/snd`

This options grants the container direct access to the host's sound devices. While some applications may access this device, most applications play sound through frameworks such as PipeWire, PulseAudio, and JACK. Therefore this parameter can also be left unset.

> PipeWire is not only used to play and record sound, it is also suitable for video streaming and recording.

### Map host's directories

The container's file system is isolated from the host, meaning that, by default the host's directories and files are not accessible within the container. In some cases, however, you might want to share directories between the host and the container. For example, you might want to share the "Downloads" directory so that files downloaded within the container can be saved to the host.

These three `mount` parameters are used to map the host's "Downloads", "Music" and "Videos" directories into the container:

```sh
docker run \
  ...
  --mount type=bind,source="${HOME}/Downloads",target="/root/Downloads" \
  --mount type=bind,source="${HOME}/Music",target="/root/Music" \
  --mount type=bind,source="${HOME}/Videos",target="/root/Videos" \
  ...
```

In addition, you might want to store the settings of applications within the container. For example, Firefox saves its settings in the `~/.mozilla` directory. You can map this directory to a location on the host:

`--mount type=bind,source="${HOME}/docker-gui-app-data/.mozilla",target="/root/.mozilla"`

This allows Firefox within the container to retain its settings and avoid starting from a "flash new" state every time.

### Map X11

If your desktop environment runs on top of the Xorg server, you need to map X11 into the container. If you are running on top of Wayland but the target GUI application only supports X11, this step is also necessary (the host also needs to have `xwayland` installed to translate Xorg access to Wayland).

Mapping X11 is a bit more complex because it provides multiple sockets similar to the Wayland socket, which are located in the `/tmp/.X11-unix` directory. For example, `/tmp/.X11-unix/X0` is the socket for display number `:0`. You can check the current display number using the `DISPLAY` environment variable (the X window system allows multiple displays to be active on a single machine, each display is identified by a number). Therefore, you need to map the entire `/tmp/.X11-unix` directory instead of a single socket file.

In addition, X11 has a file called `~/.Xauthority`, this file stores "magic cookies" that are used for authentication to ensure that only authorized applications can display windows on your screen. The actual path to this file is set by `${XAUTHORITY}`. However, you cannot map this file directly into the container, it needs to be modified. The following script shows how to copy and modify the Xauthority file and then map the modified version into the container:

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

# Change to allow any host to connect to this X server
# it's slightly easier to use XAuthority file then
# command `xhost +SI:localuser:$(id -un)`
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

The specific principles are not detailed here. If you are interested, you can refer to [Short setups to provide X display to container](https://github.com/mviereck/x11docker/wiki/Short-setups-to-provide-X-display-to-container) and [X authentication with cookies and xhost](https://github.com/mviereck/x11docker/wiki/X-authentication-with-cookies-and-xhost-%28%22No-protocol-specified%22-error%29).

If you map both Wayland and X11 into the container, you can add these environment variables to the container to make applications inside it prioritize Wayland:

```sh
docker run \
  ...
  -e XDG_SESSION_TYPE=wayland \
  -e GDK_BACKEND=wayland \
  -e QT_QPA_PLATFORM=wayland \
  -e SDL_VIDEODRIVER=wayland \
  ...
```

### Input method (IME) related environment variables

If you need to use an input method (IME), such as fcitx or ibus within GUI applications in the container, you need to set these environment variables:

```sh
docker run \
  ...
  -e GTK_IM_MODULE=fcitx \
  -e XMODIFIERS=@im=fcitx \
  -e QT_IM_MODULE=fcitx \
  ...
```

### The complete launch script

Here is a launch script with all the above parameters for reference: [start-docker-archlinux-gui-firefox-full.sh](https://github.com/hemashushu/docker-archlinux-gui/raw/refs/heads/main/start-docker-archlinux-gui-firefox-full.sh)

> Note: Do not run scripts downloaded from the internet immediately! You should first review the contents of the script to ensure it is safe before running it. If the script is too complex to understand, do not run it unless it is from a trusted source. Of course you can also use an AI to check it for you.

## Build images

Now that you know how to launch a container with GUI application support, the next step is to "package" the target application as a Docker image.

The example image "archlinux-gui-firefox" above is actually built on top of the "archlinux-gui" image. The "archlinux-gui" image serves as a basic GUI layer, providing essential packages for GUI applications, such as audio and video decoding plugins and fonts. Specific applications, such as Firefox and mpv, built on this base image can reduce the overall image size.

Of course you can add layers between the base layer and the application layer. For example, you can build layers such as "GTK" and "Qt" on top of the base layer, so that multiple GTK-based or Qt-based applications can share the same layer, further reducing the size of the applications images.

Below is the `Dockerfile` for building the "archlinux-gui" image:

```Dockerfile
FROM archlinux:latest

# (Optional) Add your nearest mirror here, e.g.
RUN echo 'Server = https://mirrors.aliyun.com/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist.new && \
    echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist.new && \
    cat /etc/pacman.d/mirrorlist >> /etc/pacman.d/mirrorlist.new && \
    mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak && \
    mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist

# Update repository and system.
RUN pacman -Syu --noconfirm

# Install audio userspace framework.
RUN pacman -S pipewire pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack --noconfirm

# Install decoding plugins.
RUN pacman -S gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly --noconfirm

# Install extra fonts, e.g. CJK fonts.
RUN pacman -S ttf-dejavu noto-fonts-cjk --noconfirm

# Change the permission of XDG_RUNTIME_DIR.
RUN chmod 700 /tmp

# Change the work directory.
WORKDIR /root

# Default command after starting this container.
CMD /usr/bin/bash
```

As you can see, this image is built on top of "archlinux:latest", Of course you can also choose images such as [Ubuntu](https://hub.docker.com/_/ubuntu), [Fedora](https://hub.docker.com/_/fedora), [Alpine](https://hub.docker.com/_/alpine), depending on your preference.

Below is the `Dockerfile` for building the "archlinux-gui-firefox" image:

```Dockerfile
FROM archlinux-gui:1.0.0

# Update repository and system.
RUN pacman -Syu --noconfirm

# Install web browser Firefox.
RUN pacman -S firefox --noconfirm

# Default command after starting this container.
CMD dbus-run-session firefox
```

The contents of these two files are quite straightforward. Please refer to the comments inside for specific meanings.

It's worth mentioning that the default command for the "archlinux-gui-firefox" image is `dbus-run-session firefox` instead of `firefox`. This is because most GUI applications rely on the D-Bus and need to be launched with `dbus-run-session`.

These files can be obtained from the [docker-archlinux-gui](https://github.com/hemashushu/docker-archlinux-gui) repository. Once downloaded, use the following command to generate the Docker images locally:

`docker build -t <IMAGE_NAME>:<IMAGE_TAG> -f <DOCKERFILE_NAME> .`

e.g.

`docker build -t archlinux-gui:1.0.0 -f Dockerfile .`
`docker build -t archlinux-gui-firefox:1.0.0 -f Dockerfile-firefox .`

## Learn more

This tutorial explains the principles of running GUI applications directly in containers, the script to start the container, and how to build images for GUI applications. If you want to go further, such as building a development environment for GUI applications or running development tools like VSCode, you can refer to [docker-archlinux-gui-devel](https://github.com/hemashushu/docker-archlinux-gui-devel).

## Images

- [archlinux-gui](https://hub.docker.com/r/hemashushu/archlinux-gui)
- [archlinux-gui-firefox](https://hub.docker.com/r/hemashushu/archlinux-gui-firefox)
- [archlinux-gui-mpv](https://hub.docker.com/r/hemashushu/archlinux-gui-mpv)
- [archlinux-gui-devel](https://hub.docker.com/r/hemashushu/archlinux-gui-devel)
- [archlinux-gui-vscode-oss](https://hub.docker.com/r/hemashushu/archlinux-gui-vscode-oss)

## Repositories

- [docker-archlinux-gui](https://github.com/hemashushu/docker-archlinux-gui)
- [docker-archlinux-gui-devel](https://github.com/hemashushu/docker-archlinux-gui-devel)
- [docker-ubuntu-gui](https://github.com/hemashushu/docker-ubuntu-gui)
