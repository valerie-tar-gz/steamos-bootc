FROM ghcr.io/steamdeckhomebrew/holo-base:latest AS steamosbuilder

RUN pacman -Sy --noconfirm sudo base-devel git fuse3 glib2-devel meson glibc pkgconfig coreutils && \
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
        --disable-gtk-doc \
        --with-curl \
        --with-openssl \
        --without-soup \
        --with-dracut=yesbutnoconf && \
    make && \
    make DESTDIR=/build-directory install

RUN --mount=type=tmpfs,dst=/tmp cd /tmp && \
    git clone https://github.com/containers/composefs.git composefs && \
    cd composefs && \
    git fetch --all && \
    meson setup build --prefix=/usr --default-library=shared -Dfuse=enabled && \
    ninja -C build && \
    DESTDIR=/build-dir ninja -C build install

FROM ghcr.io/valerie-tar-gz/holo-docker-complete:latest AS steamos

RUN pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman-key --populate holo

RUN pacman -Sy --noconfirm flatpak gcc glibc pkg-config sudo base-devel git fuse3 glib2-devel meson zstd openssl glib2 glib2-devel && \
     pacman -S --clean --clean && \
    rm -rf /var/cache/pacman/pkg/*

COPY --from=steamosbuilder /build-directory /tmp/build-directory
RUN cp -avf /tmp/build-directory/usr/lib/* /usr/lib && cp -avf /tmp/build-directory/usr/bin/* /usr/bin
RUN cp -avf /tmp/build-directory/usr/lib/* /usr/lib && cp -avf /tmp/build-directory/usr/bin/* /usr/bin
RUN cp -avf /tmp/build-directory/usr/lib/pkgconfig/ostree-1.pc /usr/lib/pkgconfig/ostree-1.pc

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

#TO MOVE UP ###############################################################################
RUN pacman -Sy --noconfirm libassuan libnghttp2 libnghttp3 libssh2 libpsl krb5 brotli libidn2 pcre2 sysprof libsysprof-capture haskell-gi-gobject libffi zlib util-linux util-linux-libs xz curl gpgme libgpg-error composefs systemd-libs libarchive && \
     pacman -S --clean --clean && \
    rm -rf /var/cache/pacman/pkg/*

ENV PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig
RUN pkg-config --cflags ostree-1
#TO MOVE UP ###############################################################################

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

COPY ./packages /packages

COPY files/37composefs/ /usr/lib/dracut/modules.d/37composefs/
COPY files/ostree/prepare-root.conf /usr/lib/ostree/prepare-root.conf

#  linux-firmware \
##If you would like a basic tty session, remove all packages below micro.
RUN pacman -Sy --noconfirm \
  dracut \
  linux \
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
  shadow \
  micro && \
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