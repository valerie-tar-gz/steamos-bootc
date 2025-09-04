build-containerfile:
    sudo podman build \
        -t steamos-bootc:latest .

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers \
        -v /dev:/dev \
        -v .:/data:Z \
        --security-opt label=type:unconfined_t \
        arch-bootc:latest bootc {{ARGS}}

generate-bootable-image:
    #!/usr/bin/env bash
    if [ ! -e ./bootable.img ] ; then
        fallocate -l 20G ./bootable.img
    fi
    just bootc install to-disk --composefs-native --via-loopback /data/bootable.img --filesystem btrfs --wipe

