# 如何在容器里直接运行 GUI 应用程序

这个教程介绍一种无需安装额外软件即可以在容器里（Docker 和 Podman 等）直接运行 GUI 应用程序的方法。

什么情况下需要在容器里运行 GUI 应用程序?

- 目标 GUI 应用程序的来源不明，或者不确定是否安全。
- 想尝试目标 GUI 应用程序，但不希望安装它到现有的系统里，也不希望在应用程序卸载后留下任何文件或数据（即保持系统干净）。
- 在操作系统的包仓库（package repository）里没找到目标 GUI 应用程序，而应用程序官方提供的软件包又没有你当前 Linux 发行版的版本。比如应用程序只提供了 Ubuntu 和 Fedora 的软件包，但你的发行版是 Arch Linux 或者 NixOS。

## 前提条件（requirements）

- 你的平台运行着 Wayland 协议的 Display server。如果你正使用较新版本的 Gnome 或 KDE 桌面环境，则已经满足该条件。如果你的桌面环境运行在 Xorg server 之上，请跳到 “自定义启动脚本” 一节。
- 你的平台运行着 PipeWire multimedia framework。对于较新版本的 Linux 发行版，该条件大概率是满足的。如果你不确定也可以继续，因为没有 PipeWire 也不影响启动大部分 GUI 应用程序。
- 你的平台必须已安装 Docker 或者 Podman 容器管理器。在桌面机器里我推荐使用 Podman，相对 Docker 来说，Podman 比较简单和安全，比如：它不需要以 daemon 的形式运行、没有复杂的配置，可以直接使用当前登录的用户（即“非特权用户”）启动容器（在容器里的 root 用户会自动映射到宿主的当前登录用户而不是 root 用户）等等。

> 因为 Podman 同样可以使用 `docker` 命令访问，所以下面的代码统一使用 `docker` 命令。

## 快速开始

在介绍具体方法和原理之前，你可以先在机器上快速体验一下在容器里启动 GUI 应用程序。

1. 创建一个名为 `start-docker-archlinux-gui-firefox.sh` 的脚本:

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

2. 运行脚本：

```sh
sh start-docker-archlinux-gui-firefox.sh
```

这个脚本会从 "hub.docker.com" 拉取映像 "archlinux-gui-firefox" 并启动容器实例。

> 如果你的网络访问 "hub.docker.com" 的速度较慢的话，可以跳到 “构建映像（Building Image）” 一节，在本地生成映像后再返回这里。

3. 现在你应该能看到在容器里启动的 “全新的” Firefox，尝试访问一些视频网站，播放音乐和视频应该没问题。也可以试试保存网页到 "Downloads" 文件夹，该文件夹跟宿主的 "Downloads" 是一样的。

4. 关闭 Firefox，容器实例会退出并删除程序运行中产生的所有数据（除了保存在 "Downloads" 文件夹的数据）。

5. 可以尝试把上面脚本的 "archlinux-gui-firefox:1.0.0" 更改为 "archlinux-gui-mpv:1.0.0"，运行后你应该能看到一个名为 “Celluloid” 的媒体播放器（一款基于 mpv 的软件），可以尝试用它来播放一些视频，如无意外它能够很好地工作。

## 它是如何工作的？

在启动容器示例时，只需把宿主的 Wayland socket 和 PipeWire socket 文件映射进容器，然后在容器内设置相应的环境变量，这样就可以在容器里启动 GUI 应用程序了。

下面是细节：

Wayland socket 文件在 user's runtime directory （即环境变量 `${XDG_RUNTIME_DIR}` 指向的目录） 里面，文件名为 `${WAYLAND_DISPLAY}`，完整路径如 `/run/user/1000/wayland-0`，where "1000" represents the user ID (UID)。This socket serves as the communication channel between Wayland clients (applications) and the Wayland compositor (the display server).
Essentially, applications that want to display their graphical output on the screen connect to this socket to communicate with the Wayland compositor.

跟 Wayland socket 类似，PipeWire socket 文件同样位于 user's runtime directory，文件名为 `pipewire-0`，完整路径如 `/run/user/1000/pipewire-0`。It serves as a communication channel between applications and the PipeWire server. When an application wants to play or record audio or video, it connects to this socket to interact with the PipeWire server.

如果你好奇地查看 user's runtime directory，还会发现有一个叫 `bus` 的 socket 文件，它是 DBus 的 socket，通过它容器内的应用程序可以跟宿主传送消息，不过因为安全配置较麻烦所以这里就忽略了。

## 自定义启动脚本

启动脚本的主要内容是构建运行 podman（或者docker）程序的命令行参数，以将 Wayland socket 和 PipeWire socket 映射到容器内，并设置容器的相应的环境变量。下面是每行参数的说明，并补充一些额外的参数，你可以根据需要创建自己的启动脚本。

### 基本参数

```sh
docker run \
  --rm \
  archlinux-gui-firefox:1.0.0
```

这是启动容器实例的基本参数:

- `--rm` option tells Docker to automatically remove the container when it exits, this helps keep your system clean.
- `archlinux-gui-firefox:1.0.0` This is the name of the Docker image that will be used to create the container.Docker will first check if the image exists locally. If it doesn't, it will attempt to download it from Docker Hub (or another configured registry).

### 图像相关的参数

`--mount type=bind,source="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}",target="/tmp/${WAYLAND_DISPLAY}"`

通过 `mount` 参数将宿主的 Wayland socket 文件（如 `/run/user/1000/wayland-0`) 映射到容器里的 `/tmp/wayland-0`。

`-e WAYLAND_DISPLAY=${WAYLAND_DISPLAY}`

通过参数 `e` 设置容器内环境变量 `WAYLAND_DISPLAY` 让容器内的应用程序知道当前的显示号码。

`-e XDG_RUNTIME_DIR=/tmp`

同时设置容器内的环境变量 `XDG_RUNTIME_DIR`，让容器内的应用程序知道 user's runtime directory 在哪里。

`--device /dev/dri`

This option maps the host machine's `/dev/dri` directory into the Docker container. By doing this, applications running inside the container can use the host's GPU for hardware acceleration.

This is crucial for applications that require high-performance graphics, such as:

- 3D games
- Video playback and encoding
- Graphics-intensive applications
- Machine learning applications that utilize GPU's.

### 声音相关的参数

`--mount type=bind,source="${XDG_RUNTIME_DIR}/pipewire-0",target="/tmp/pipewire-0"`

映射宿主的 PipeWire socket 文件（如 `/run/user/1000/pipewire-0`）到容器内的 `/tmp/pipewire-0`。注意 PipeWire 没有类似 `WAYLAND_DISPLAY` 的环境变量用于指定当前的声音号码（number）。

`--device /dev/snd`

This options is granting the container direct access to the host's sound devices. 少数应用程序可能会访问该设备，不过一般都是通过诸如 PipeWire, PulseAudio 和 JACK 等框架播放声音。因此该参数不设置也是可以的。

> PipeWire 不仅仅用于播放和录制声音，它同样适用于视频的播放和录制，比如一个视频播放器它可能通过 Wayland 来显示程序的外观，用 `/dev/dri` 来解压视频和音频，再通过 PipeWire 输出画面和声音。当然具体如何实现并不是每个应用程序都一样的。

### 映射宿主的部分用户目录

容器的文件系统跟宿主是相互隔离的，也就是说默认情况下在容器里无法访问宿主的文件，包括用户目录。但有时我们希望容器跟宿主共享部分目录，比如这三个 `mount` 参数用于将宿主的 "Downloads", "Music" 和 "Videos" 映射到容器内：

```sh
docker run \
  ...
  --mount type=bind,source="${HOME}/Downloads",target="/root/Downloads" \
  --mount type=bind,source="${HOME}/Music",target="/root/Music" \
  --mount type=bind,source="${HOME}/Videos",target="/root/Videos" \
  ...
```

除此之外，有时我们可能还希望能保存容器内部分应用程序的设置，比如 Firefox 会把设置信息保存在 "~/.mozilla" 目录里，你可以通过 `mount` 参数把这个目录映射到宿主的某个位置：

`--mount type=bind,source="${HOME}/docker-gui-app-data/.mozilla",target="/root/.mozilla"`

这样容器内的 Firefox 就能够记住设置而不会每次都是从 “全新的状态” 开始运行。

### 映射 X11

如果你的桌面环境运行在 Xorg server 之上，则还需要映射 X11 到容器内。如果你的桌面环境运行在 Wayland 之上但目标 GUI 程序只支持 X11（宿主需要安装 `xwayland` 用于将 Xorg 的访问转到 Wayland），同样需要这个步骤。

映射 X11 会稍微复杂，因为它提供了多个跟 Wayland socket 类似的 socket，位于目录 `/tmp/.X11-unix` 之内，比如 `/tmp/.X11-unix/X0` 是显示编号（display number）为 `:0` 的 socket，你可以通过环境变量 $DISPLAY 查看当前的显示编号（The X Window System allows multiple displays to be active on a single machine. Each display is identified by a number.）因此你需要映射整个 `/tmp/.X11-unix` 而不是单个 socket 文件。

另外 X11 还有一个诸如 `~/.Xauthority` 的文件，This file stores "magic cookies" that are used for authentication, ensuring that only authorized applications can display windows on your screen. 这个文件的实际路径由环境变量 $XAUTHORITY 指定。但你不能直接将这个文件映射到容器之内，需要经过修改。下面的脚本是通过复制一份 XAuthority，然后修改，再将修改后的映射到容器内。

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

具体的原理这里就不赘述了，感兴趣的可以参考 [Short setups to provide X display to container](https://github.com/mviereck/x11docker/wiki/Short-setups-to-provide-X-display-to-container) 和 [X authentication with cookies and xhost](https://github.com/mviereck/x11docker/wiki/X-authentication-with-cookies-and-xhost-%28%22No-protocol-specified%22-error%29)

如果你同时映射 Wayland 和 X11 到容器，可以添加这些环境变量到容器让其中的应用程序优先选择 Wayland:

```sh
docker run \
  ...
  -e XDG_SESSION_TYPE=wayland \
  -e GDK_BACKEND=wayland \
  -e QT_QPA_PLATFORM=wayland \
  -e SDL_VIDEODRIVER=wayland \
  ...
```

### 输入法（IME）相关环境变量

如果你需要在容器内的 GUI 应用程序里使用输入法（IME），比如 `fcitx` 或者 `ibus`，需要设置这些环境变量：

```sh
docker run \
  ...
  -e GTK_IM_MODULE=fcitx \
  -e XMODIFIERS=@im=fcitx \
  -e QT_IM_MODULE=fcitx \
  ...
```

### 完整的启动脚本

这里有一个包含有以上所有参数的启动脚本 [start-docker-archlinux-gui-firefox-full.sh](https://github.com/hemashushu/docker-archlinux-gui/raw/refs/heads/main/start-docker-archlinux-gui-firefox-full.sh) 以供参考。

> 注意，从互联网下载的脚本不要立即运行！你应该先大致地查看一下脚本的内容，确保没有危害之后再运行。如果脚本很复杂以至于看不懂，除非是信任的来源，否则就不要运行。培养良好的习惯有助于避免系统受到伤害。

## 构建映像（Building Image）

现在你已经知道如何启动一个支持 GUI 应用程序的容器了，接下来只需把目标应用程序 “打包” 为 Docker 映像即可。

上面示例的映像 “archlinux-gui-firefox” 实际上构建在映像 “archlinux-gui” 之上的。映像 “archlinux-gui” 是一个 GUI 基础层，提供了 GUI 应用程序一些必要的软件包，比如音频和视频的解码插件、字体等。具体的应用程序，比如 Firefox, mpv 构建在这个映像基础之上可以减少映像的体积。

当然你可以在基础层和应用程序层之间插入更多的层，比如在 “archlinux-gui” 之上构建诸如 "GTK", "Qt" 等层，这样多个基于 GTK 或 Qt 的应用程序就可以共享同一个层，进一步减少应用程序映像的体积。

下面是用于构建映像 “archlinux-gui” 的 `Dockerfile`:

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

从 `Dockerfile` 内容可见，这个映像构建在映像 "archlinux:latest" 之上，当然你也可以选择 [Ubuntu](https://hub.docker.com/_/ubuntu), [Fedora](https://hub.docker.com/_/fedora), [Alpine](https://hub.docker.com/_/alpine) 等映像，视乎你的口味了。

下面是构建映像 "archlinux-gui-firefox" 的 `Dockerfile`:

```Dockerfile
FROM archlinux-gui:1.0.0

# Update repository and system.
RUN pacman -Syu --noconfirm

# Install web browser Firefox.
RUN pacman -S firefox --noconfirm

# Default command after starting this container.
CMD dbus-run-session firefox
```

这两个文件的内容比较简单，具体的含义请参考里面的注释。

值得一提的是映像 "archlinux-gui-firefox" 的默认命令是 `dbus-run-session firefox` 而不是 `firefox`，这是因为诸如 Firefox 等 GUI 应用程序大部分都依赖 DBus，启动这些应用程序需要以 `dbus-run-session <application>` 这样的方式启动。

这些文件可以从仓库 [docker-archlinux-gui](https://github.com/hemashushu/docker-archlinux-gui) 获取，下载回来之后使用命令：

`docker build -t <IMAGE_NAME>:<IMAGE_TAG> -f <DOCKERFILE_NAME> .`

比如：

`docker build -t archlinux-gui:1.0.0 -f Dockerfile .`
`docker build -t archlinux-gui-firefox:1.0.0 -f Dockerfile-firefox .`

即可在本地生成 Docker 映像。

## 了解更多

这篇教程介绍了在容器里直接运行 GUI 应用程序的原理，启动容器的脚本，以及构建 GUI 应用程序映像的方法。如果你想更进一步，比如构建 GUI 应用程序的开发环境，或者运行 VSCode 等开发工具，可以参考 [docker-archlinux-gui-devel](https://github.com/hemashushu/docker-archlinux-gui-devel).

## Images

- https://hub.docker.com/r/hemashushu/archlinux-gui
- https://hub.docker.com/r/hemashushu/archlinux-gui-firefox
- https://hub.docker.com/r/hemashushu/archlinux-gui-firefox
- https://hub.docker.com/r/hemashushu/archlinux-gui-mpv
- https://hub.docker.com/r/hemashushu/archlinux-gui-devel
- https://hub.docker.com/r/hemashushu/archlinux-gui-vscode

## Repositories

- https://github.com/hemashushu/docker-archlinux-gui
- https://github.com/hemashushu/docker-archlinux-gui-devel
