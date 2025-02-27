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
