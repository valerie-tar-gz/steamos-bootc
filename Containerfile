FROM ghcr.io/steamdeckhomebrew/holo-base:latest

COPY ./packages /packages

COPY files/37composefs/ /usr/lib/dracut/modules.d/37composefs/
COPY files/ostree/prepare-root.conf /usr/lib/ostree/prepare-root.conf

RUN pacman -Sy --noconfirm sudo base-devel git fuse3 glib2-devel meson && \
  pacman -S --clean --clean && \
  rm -rf /var/cache/pacman/pkg/*


#RUN sudo pacman-key --init && sudo pacman-key --populate archlinux && cat /etc/pacman.conf && echo hi

#RUN rm /etc/pacman.conf && cp /packages/pacman.conf /etc/pacman.conf

#RUN sudo pacman-key --init && sudo pacman-key --populate archlinux

#RUN pacman  /usr/lib/libgpgme.so.11 && pacman -Sy --noconfirm sudo base-devel extra/ostree core/gpgme && \
#  pacman -S --clean --clean && \
#  rm -rf /var/cache/pacman/pkg/*

RUN pacman -Sy --noconfirm flatpak && \
  pacman -S --clean --clean && \
  rm -rf /var/cache/pacman/pkg/*

RUN --mount=type=tmpfs,dst=/tmp cd /tmp && \
    git clone https://github.com/ostreedev/ostree.git ostree && \
    cd ostree && \
    git submodule update --init --recursive && \
    env NOCONFIGURE=1 ./autogen.sh && \
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --libdir=/usr/lib \
        --mandir=/usr/share/man \
        --infodir=/usr/share/info \
        --localstatedir=/var \
        --disable-silent-rules \
        --enable-gtk-doc \
        --with-curl \
        --with-openssl \
        --without-soup \
        --with-dracut=yesbutnoconf && \
    make && \
    make install

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN --mount=type=tmpfs,dst=/tmp cd /tmp && \
    git clone https://github.com/bootc-dev/bootc.git bootc && \
    cd bootc && \
    git fetch --all && \
    git switch origin/composefs-backend -d && \
    /root/.cargo/bin/cargo build --release --bins && \
    install -Dpm0755 -t /usr/bin ./target/release/bootc && \
    install -Dpm0755 -t /usr/bin ./target/release/system-reinstall-bootc && \
    install -Dpm0755 -t /usr/bin ./target/release/bootc-initramfs-setup

RUN --mount=type=tmpfs,dst=/tmp cd /tmp && \
    git clone https://github.com/p5/coreos-bootupd.git bootupd && \
    cd bootupd && \
    git fetch --all && \
    git switch origin/sdboot-support -d && \
    /root/.cargo/bin/cargo build --release --bins --features systemd-boot && \
    install -Dpm0755 -t /usr/bin ./target/release/bootupd && \
    ln -s ./bootupd /usr/bin/bootupctl

RUN --mount=type=tmpfs,dst=/tmp cd /tmp && \
    git clone https://github.com/containers/composefs.git composefs && \
    cd composefs && \
    git fetch --all && \
    meson setup build --prefix=/usr --default-library=shared -Dfuse=enabled && \
    ninja -C build && \
    ninja -C build install

RUN pacman -Sy --noconfirm \
  dracut \
  linux \
  linux-firmware \
  systemd \
  btrfs-progs \
  e2fsprogs \
  xfsprogs \
  udev \
  cpio \
  zstd \
  binutils \
  dosfstools \
  conmon \
  crun \
  netavark \
  skopeo \
  dbus \
  dbus-glib \
  glib2 \
  fastfetch \
  networkmanager \
  sddm \
  sddm-kcm \
  steamdeck-kde-presets \
  micro \
  plasma-activities \
  plasma-activities-stats \
  plasma-browser-integration \
  plasma-desktop \
  plasma-disks \
  plasma-firewall \
  plasma-integration \
  plasma-meta \
  plasma-nm \
  plasma-pa \
  plasma-remotecontrollers \
  plasma-systemmonitor \
  plasma-thunderbolt \
  plasma-vault \
  plasma-wayland-protocols \
  plasma-welcome \
  plasma-workspace \
  plasma-workspace-wallpapers \
  plasma5support \
  konsole \
  dolphin \
  firefox \
  shadow && \
  pacman -S --clean --clean && \
  rm -rf /var/cache/pacman/pkg/*
  
RUN cp /usr/bin/bootc-initramfs-setup /usr/lib/dracut/modules.d/37composefs

RUN mkdir /var/tmp/

RUN echo "$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" > kernel_version.txt && \
    dracut --debug --force --no-hostonly --reproducible --zstd --verbose --kver "$(cat kernel_version.txt)" --add ostree "/usr/lib/modules/$(cat kernel_version.txt)/initramfs.img" && \
    rm kernel_version.txt

# Alter root file structure a bit for ostree
RUN mkdir -p /boot /sysroot /var/home && \
    rm -rf /var/log /home /root /usr/local /srv && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/usrlocal /usr/local && \
    ln -s /var/srv /srv

# Update useradd default to /var/home instead of /home for User Creation
RUN sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd

# Setup a temporary root passwd (changeme) for dev purposes
# TODO: Replace this for a more robust option when in prod
RUN usermod -p '$6$AJv9RHlhEXO6Gpul$5fvVTZXeM0vC03xckTIjY8rdCofnkKSzvF5vEzXDKAby5p3qaOGTHDypVVxKsCE3CbZz7C3NXnbpITrEUvN/Y/' root && \
    rm -rf /packages

COPY files/ostree/prepare-root.conf /usr/lib/ostree/prepare-root.conf

# Necessary labels
LABEL containers.bootc 1

RUN systemd-machine-id-setup
