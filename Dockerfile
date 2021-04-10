ARG MERGERFS_VERSION="2.32.4"
ARG RCLONE_VERSION="v1.55.0"

###################
# MergerFS
###################
FROM alpine:latest as mergerfsbuilder
ARG MERGERFS_VERSION
WORKDIR /mergerfs

RUN apk add --no-cache \
        g++ \
        linux-headers \
        make

RUN wget "https://github.com/trapexit/mergerfs/releases/download/${MERGERFS_VERSION}/mergerfs-${MERGERFS_VERSION}.tar.gz" \
    && tar -xzf "mergerfs-${MERGERFS_VERSION}.tar.gz" \
    && cd "mergerfs-${MERGERFS_VERSION}" \
    && make STATIC=1 LTO=1 PREFIX="/install" DESTDIR="/mergerfs" install

###################
# Rclone
###################
FROM alpine:latest as rclonedownloader
ARG RCLONE_VERSION
WORKDIR /rclonedownloader

ENV RCLONE_URL="https://github.com/ncw/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip"

RUN wget --no-check-certificate -O rclone.zip \
        "https://github.com/ncw/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip" \
    && unzip rclone.zip \
    && mv rclone-*/rclone rclone \
    && chmod 755 rclone

###################
# S6 Overlay
###################
FROM alpine:latest as s6downloader
WORKDIR /s6downloader

RUN set -x \
    && wget -O /tmp/s6-overlay.tar.gz "https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64.tar.gz" \
    && mkdir -p /tmp/s6 \
    && tar zxvf /tmp/s6-overlay.tar.gz -C /tmp/s6 \
    && cp -r /tmp/s6/* .

###################
# Rootfs Converter
###################
FROM alpine:latest as rootfs-converter
WORKDIR /rootfs

RUN set -x \
    && apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community/ \
        dos2unix

COPY root .
RUN set -x \
    && find . -type f -print0 | xargs -0 -n 1 -P 4 dos2unix

# ====================Begin Image===========================

FROM alpine:latest

RUN apk add --no-cache \
        curl \
        fuse \
        shadow \
        tzdata

COPY --from=rclonedownloader /rclonedownloader/rclone /usr/bin
COPY --from=mergerfsbuilder /mergerfs/install/bin /bin
COPY --from=s6downloader /s6downloader /
COPY --from=rootfs-converter /rootfs /

RUN sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf

RUN chmod a+x /usr/bin/* \
    && groupmod -g 1000 users \
    && useradd -u 911 -U -d / -s /bin/false abc \
    && usermod -G users abc

RUN mkdir -p \
        /mounts/local-decrypt \
        /mounts/cloud-decrypt \
        /data/media \
        /config \
        /log \
        /tmp/rcloneconfig \
    && chmod 755 \
        /mounts \
        /data \
        /config \
        /log \
        /tmp/rcloneconfig \
    && chown abc:abc \
        /mounts \
        /data \
        /config \
        /tmp/rcloneconfig \
    && chown nobody:nobody \
        /log

# System Vars
ENV \
    S6_FIX_ATTRS_HIDDEN=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    MERGERFS_OPTIONS="splice_move,atomic_o_trunc,auto_cache,big_writes,default_permissions,direct_io,nonempty,allow_other,sync_read,category.create=ff,category.search=ff,minfreespace=0" \
    RCLONE_MASK="000" \
    MAX_LOG_SIZE_BYTES=1000000 \
    MAX_LOG_NUMBER=10 \
    RCLONE_MOUNT_LOCAL_DECRYPT=1

#############
# User Vars
#############
# Timezone
ENV \
    TZ="America/Chicago"

# Rclone mount config
ENV \
    RCLONE_VFS_READ_OPTIONS="--buffer-size=128M --dir-cache-time=72h --poll-interval=60s --rc --rc-addr=:5572 --timeout=1h --tpslimit=1750 -vv" \
    RCLONE_LOCAL_DECRYPT_REMOTE="local-decrypt" \
    RCLONE_LOCAL_DECRYPT_DIR="/mnt/local-decrypt" \
    RCLONE_CLOUD_DECRYPT_REMOTE="cloud" \
    RCLONE_CLOUD_DECRYPT_DIR="" \
    RCLONE_MIRROR_DECRYPT_REMOTE="mirror" \
    RCLONE_MIRROR_DECRYPT_DIR=""

# Precache Config
ENV \
    PRECACHE_ENABLED=1 \
    PRECACHE_VFS_DIR="" \
    PRECACHE_FIND_DIR="/mounts/cloud-decrypt" \
    PRECACHE_USE_RC=1

# Dedupe Config
ENV \
    DEDUPE_OPTIONS="--dedupe-mode largest --tpslimit 4 -v" \
    CRON_DEDUPE_TIME="0 6 * * *" \
    DEDUPE_CLOUD_DECRYPT="1" \
    DEDUPE_MIRROR_REMOTE="0"

# Rmlocal Config
ENV \
    RCLONE_SCRIPT_OPTIONS="--drive-chunk-size 32M --checkers 4 --transfers 4 -v" \
    CRON_RMDELETE_TIME="30 6 * * *" \
    RMLOCAL_MAX_SIZE_GB="100" \
    CLOUD_UPLOAD_AFTER_RMLOCAL=1

# Mirror from cloud -> mirror
ENV \
    MIRROR_OPTIONS="--transfers 4 --bwlimit 100M --tpslimit 8 --tpslimit-burst 8 --drive-server-side-across-configs -v" \
    CRON_MIRROR_TIME="0 6 * * *" \
    MIRROR_ENCRYPTED_ENDPOINT="mirror-raw" \
    CLOUD_ENCYPTED_ENDPOINT="cloud-raw" \
    MIRROR_SUBDIR="Sync" \
    MIRROR_VALIDATE_CONFIG=1

# Plex
ENV \
    CRON_EMPTY_TRASH_TIME="0 0 31 2 0" \
    PLEX_URL="" \
    PLEX_TOKEN=""

# Temporary Config
ENV \
    RCLONE_USE_MIRROR_AS_CLOUD_REMOTE="0" \
    CONTAINER_START_RCLONE_CONFIG=0

CMD ["/init"]
